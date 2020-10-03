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

        $proc = Start-Process "C:\windows\system32\WindowsPowershell\v1.0\powershell.exe" -ArgumentList $args -PassThru -WindowStyle Hidden
    }

    [bool]DownloadFile([DownloadConfig]$Config){
        # Get File Statistics
        $Headers = ([System.Net.WebRequest]::Create($Config.Url).GetResponse().Headers)
        $Length = $Headers['Content-Length']
        $this._Download($Config)
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

    [bool]DownloadFiles(){
        $this.Configs.forEach({
            $this.DownloadFile($_)
        })
        return $true
    }

    [void]DownloadFiles([DownloadConfig[]]$Configs){
        [System.Collections.ArrayList]$ActiveDownloads = @()
        $TotalDownloads = $Configs.Count
        $CompletedDownloads = 0
        $Configs.forEach({
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

        while(!$ActiveDownloads.Count -ne 0){
            Write-Progress -Id 9999 -Activity "Downloading Files" -Status "$CompletedDownloads of $TotalDownloads" -PercentComplete (($CompletedDownloads / $TotalDownloads) *100)
            for($x = 0; $x -lt $ActiveDownloads.Count; $x++){
                while(!(Test-Path $ActiveDownloads[$x].Path)){} #do Nothing until file is there
                
                $c_length = (Get-Item $ActiveDownloads[$x].Path).Length
                
                if($ActiveDownloads[$x].Size -eq $c_length){
                    Write-Progress -Id $x -Activity "$($ActiveDownloads[$x].Path.split('\')[-1])" -Status "$c_length of $c_length" -PercentComplete 100 -Completed
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

}