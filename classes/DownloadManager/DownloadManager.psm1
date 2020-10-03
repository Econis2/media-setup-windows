using module ".\DownloadConfig\DownloadConfig.psm1"
using module "..\Logger\Logger.psm1"
using module "..\Logger\LogType\LogType.psm1"

class DownloadManager {
    [DownloadConfig[]]$Configs
    [DownloadConfig]$Config

    hidden [Logger]$Logger = [Logger]::new($true, $true)

    DownloadManager(){}
    DownloadManager([DownloadConfig[]]$_configs){ $this.Configs = $_configs }
    DownloadManager([DownloadConfig]$_config){ $this.Config = $_config }

    hidden [void]_Download([DownloadConfig]$Config){ 
        $cmd =
@"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebClient]::new().DownloadFile("$($Config.Url)", "$($Config.Path)").Dispose()
"@ 
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
        $args = @(
            "-encodedCommand $encoded",
            "-ExecutionPolicy Bypass"
            "-WindowStyle Hidden"
        )
        $this.Logger.WriteLog([LogType]::INFO,"Starting Download")
        $this.Logger.WriteLog([LogType]::INFO,"From: $($Config.Url)")
        $this.Logger.WriteLog([LogType]::INFO,"To: $($Config.Path)")
        $proc = Start-Process "C:\windows\system32\WindowsPowershell\v1.0\powershell.exe" -ArgumentList $args -PassThru -WindowStyle Hidden
        $this.Logger.WriteLog([LogType]::INFO,"Process[$($proc.id)] started")
    }

    [bool]DownloadFile([DownloadConfig]$Config){
        # Get File Statistics
        $this.Logger.WriteLog([LogType]::INFO,"Getting file stats")

        $Headers = ([System.Net.WebRequest]::Create($Config.Url).GetResponse().Headers)
        
        $Length = $Headers['Content-Length'] # File Size
        
        $this.Logger.WriteLog([LogType]::INFO,"File Size: $Length")
        
        $this._Download($Config) # Download the File
        
        $this.Logger.WriteLog([LogType]::INFO,"Waiting for download to finish")
        
        $completed = $false
        
        while(!$completed){
                $c_length = (Get-Item $Config.Path).Length

                if($Length -eq $c_length){
                    $completed = $true
                    break
                }
                $percent = ( $c_length / $Length) * 100
                Write-Progress -Id 1 -Activity "Downloading $($Config.Path.split('\')[-1])" -Status "$c_length of $($Length)" -PercentComplete $percent

            
            Start-Sleep -Milliseconds 150
        }

        return $true
    }

    [bool]DownloadFile(){ return $this.DownloadFile($this.Config) }

    [void]DownloadFiles([DownloadConfig[]]$Configs){
        [System.Collections.ArrayList]$ActiveDownloads = @()
        [int]$TotalDownloads = $Configs.Count
        [int]$CompletedDownloads = 0
        
        $Configs.forEach({
            
            $this.Logger.WriteLog([LogType]::INFO,"Getting Stats: $($_.Url)")
            
            $Headers = ([System.Net.WebRequest]::Create($_.Url).GetResponse().Headers)
            
            $ActiveDownloads.Add(@{
                Path = $_.Path
                Url = $_.Url
                Size = $Headers['Content-Length']
            }) | Out-Null
        })

        $Configs.forEach({
            $this._Download($_)
        })

        $this.Logger.WriteLog([LogType]::INFO,"Waiting for downloads to finish")

        while($ActiveDownloads.Count -ne 0){
            Write-Progress -Id 9999 -Activity "Downloading Files" -Status "$CompletedDownloads of $TotalDownloads" -PercentComplete (($CompletedDownloads / $TotalDownloads) *100)
            for($x = 0; $x -lt $ActiveDownloads.Count; $x++){
                while(!(Test-Path $ActiveDownloads[$x].Path)){} #do Nothing until file is there
                
                $c_length = (Get-Item $ActiveDownloads[$x].Path).Length
                
                if($ActiveDownloads[$x].Size -eq $c_length){
                    Write-Progress -Id $x -Activity "$($ActiveDownloads[$x].Path.split('\')[-1])" -Status "$c_length of $c_length" -PercentComplete 100
                    $ActiveDownloads.RemoveAt($x)
                    $CompletedDownloads ++
                    break
                }
                $percent = ( $c_length / $ActiveDownloads[$x].Size) * 100
                Write-Progress -Id $x -Activity "$($ActiveDownloads[$x].Path.split('\')[-1])" -Status "$c_length of $($ActiveDownloads[$x].Size))" -PercentComplete $percent

            
            Start-Sleep -Milliseconds 150
            }
        }
    }

    [void]DownloadFiles(){ $this.DownloadFiles($this.Configs) }
}