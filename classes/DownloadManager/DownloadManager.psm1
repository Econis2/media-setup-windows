using module ".\DownloadConfig\DownloadConfig.psm1"
using module "..\Logger\Logger.psm1"
using module "..\Logger\LogType\LogType.psm1"

class DownloadManager {
    [DownloadConfig[]]$Configs
    [DownloadConfig]$Config

    hidden [int]$_retires = 5
    hidden [Logger]$_Logger

    # Wihtout Logger
    DownloadManager(){
        $this._Logger = [Logger]::new($true,$true)
    }

    DownloadManager([DownloadConfig[]]$_configs){
        $this.Configs = $_configs
        $this._Logger = [Logger]::new($true,$true)
    }

    DownloadManager([DownloadConfig]$_config){
        $this._Logger = [Logger]::new($true,$true)
        $this.Config = $_config
    }

    # With Logger
    DownloadManager([Logger]$Logger){
        $this._Logger = $Logger
    }
    
    DownloadManager([DownloadConfig[]]$_configs,[Logger]$Logger){
        $this.Configs = $_configs
        $this._Logger = $Logger
    }

    DownloadManager([DownloadConfig]$_config,[Logger]$Logger){
        $this.Config = $_config
        $this._Logger = $Logger
    }

    [void]SetLogger([Logger]$Logger){
        $this._Logger = $Logger
    }

    hidden [System.Net.WebHeaderCollection]_GetMeta([string]$url){
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        [Net.ServicePointManager]::DefaultConnectionLimit = 100
        $this._Logger.WriteLog([LogType]::INFO,"Getting file stats")
        $completed = $false
        $retries = $this._retires
        $count = 0
        $responseHeaders = [System.Net.WebHeaderCollection]::new()
        while($retries -ne $count){
            $WebClient = [System.Net.WebRequest]::Create($url)
            $WebClient.Timeout = 5000 # 5 Second Timeout
            $WebClient.AllowAutoRedirect = $true
            try{
                $response = $WebClient.GetResponse()
                $responseHeaders = $response.Headers
                $count = $retries
                $WebClient.Abort() # Stop Client
            }
            catch [System.Net.WebException] {
                $WebClient.Abort() # Stop Client
                if($_.Exception.Message.contains("The operation has timed out")){ # Catch a Timeout and Try again
                    $this._Logger.WriteLog([LogType]::ERROR, "Connection TimeOut, will retry $($retries - $count) times")
                    $count ++
                }
                else{ # Other Exception
                    $this._Logger.WriteLog([LogType]::ERROR, "Another Web Error")
                    $this._Logger.WriteLog([LogType]::ERROR, "$($_.Exception.Message)")
                    throw $_.Exception.Message
                }
                
            }
        }
        return $responseHeaders
    }

    hidden [void]_Download([DownloadConfig]$Config){ 
        $cmd =
@"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::DefaultConnectionLimit = 100
[System.Net.WebClient]::new().DownloadFile("$($Config.Url)", "$($Config.Path)").Dispose()
"@ 
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
        $args = @(
            "-encodedCommand $encoded",
            "-ExecutionPolicy Bypass"
            "-WindowStyle Hidden"
        )
        $this._Logger.WriteLog([LogType]::INFO,"Starting Download")
        $this._Logger.WriteLog([LogType]::INFO,"From: $($Config.Url)")
        $this._Logger.WriteLog([LogType]::INFO,"To: $($Config.Path)")
        $proc = Start-Process "C:\windows\system32\WindowsPowershell\v1.0\powershell.exe" -ArgumentList $args -PassThru -WindowStyle Hidden
        $this._Logger.WriteLog([LogType]::INFO,"Process[$($proc.id)] started")
    }

    [bool]DownloadFile([DownloadConfig]$Config){
        # Get File Statistics
        try{
            [System.Net.WebHeaderCollection]$Headers = $this._GetMeta($Config.Url)
            $Length = $Headers['Content-Length'] # File Size
            $this._Logger.WriteLog([LogType]::INFO,"File Size: $Length")
        }
        catch {
            $Length = "unknown"
        }
    
        $this._Download($Config) # Download the File
        
        $this._Logger.WriteLog([LogType]::INFO,"Waiting for download to finish")
        
        $completed = $false
        $unknown_progress = 0
        while(!$completed){
                $c_length = (Get-Item $Config.Path).Length
                if($Length -ne "unknown"){
                    if($Length -eq $c_length){
                        $completed = $true
                        break
                    }
                    $percent = ( $c_length / $Length) * 100
                    Write-Progress -Id 1 -Activity "Downloading $($Config.Path.split('\')[-1])" -Status "$c_length of $($Length)" -PercentComplete $percent
                }
                else{ # Unkown File Size
                    if($Config.currentSize -eq $c_length){ #Download complete
                        Write-Progress -Id 1 -Activity "$($Config.Path.split('\')[-1])" -Status "$c_length of $c_length" -PercentComplete 100
                    }
                    else{
                        $prog = 0
                        switch ($unknown_progress) {
                            0 { $prog = 0}
                            1 { $prog = 25}
                            2 { $prog = 50}
                            3 { $prog = 75}
                            4 { $prog = 100}
                            Default {}
                        }
                        Write-Progress -Id 1 -Activity "$($Config.Path.split('\')[-1])" -Status "$c_length of UNKNOWN" -PercentComplete $prog
                    }

                }
            
            Start-Sleep -Milliseconds 150
        }

        return $true
    }

    [bool]DownloadFile(){ return $this.DownloadFile($this.Config) }

    [void]DownloadFiles([DownloadConfig[]]$Configs){
        [System.Net.ServicePointManager]::DefaultConnectionLimit = 100
        [System.Collections.ArrayList]$id_pool = @()
        [System.Collections.ArrayList]$ActiveDownloads = @()
        [System.Collections.ArrayList]$Completed = @()
        [int]$TotalDownloads = $Configs.Count
        $total_percent = 0
        
        $Configs.forEach({
            # Get File Statistics
            try{
                [System.Net.WebHeaderCollection]$Headers = $this._GetMeta($_.Url)
                
                $id = 0
                while($id -eq 0){ #Generate Random ID - this is used for the progress bars
                    $temp_id = Get-Random -Maximum 1000 -Minimum 100
                    if(!$id_pool.Contains($temp_id)){ $id = $temp_id; $id_pool.Add($temp_id) | Out-Null }
                }
                    
                $ActiveDownloads.Add(@{
                    id = $id
                    Path = $_.Path
                    Url = $_.Url
                    totalSize = $Headers['Content-Length']
                    currentSize = 0
                }) | Out-Null
            }
            catch{
                $this._Logger.WriteLog([LogType]::ERROR,"Unable to get Meta-Data for File")
                $ActiveDownloads.Add(@{
                    id = $id
                    Path = $_.Path
                    Url = $_.Url
                    totalSize = "unknown"
                    currentSize = 0
                }) | Out-Null
            }
        })

        $Configs.forEach({ # Download all the Files
            $this._Download($_)
        })

        $this._Logger.WriteLog([LogType]::INFO,"Waiting for downloads to finish")

        $unknown_progress = 0
        while($ActiveDownloads.Count -ne $Completed.Count){ # Wait for Downloads to Complete

            Write-Progress -Id 1 -Activity "Downloading Files" -Status "$($Completed.Count) / $TotalDownloads" -PercentComplete ($total_percent / $TotalDownloads)
            $total_percent = 0

            for($x = 0; $x -lt $ActiveDownloads.Count; $x++){ # Loop through each Job and Update Status
                $_Activity = "$($ActiveDownloads[$x].Path.split('\')[-1])"
                $_Percent = $null
                $_Status = $null

                while(!(Test-Path $ActiveDownloads[$x].Path)){} #do Nothing until file is there
                
                $c_length = (Get-Item $ActiveDownloads[$x].Path).Length # Current File Size
                if($ActiveDownloads[$x].totalSize -ne "unknown"){ # If Total File Size is Known
                    if($ActiveDownloads[$x].totalSize -eq $c_length){ # Check Current vs Total Size
                        $t_size = $([Math]::Round(($c_length / 1024)/1024))
                        $_Status = "$t_size of $t_size (MB)"
                        $_Percent = 100

                        if(!$Completed.Contains($ActiveDownloads[$x].id)){
                            $this._Logger.WriteLog([LogType]::INFO, "$_Activity Completed")
                            $Completed.Add($ActiveDownloads[$x].id) | Out-Null
                        }
                    }
                    else{
                        $_Status = "$([Math]::Round(($c_length / 1024)/1024)) of $([Math]::Round(($ActiveDownloads[$x].totalSize / 1024)/1024)) (MB)"
                        $_Percent = ( $c_length / $ActiveDownloads[$x].totalSize) * 100
                    }
    
                }
            
                Write-Progress -Id $ActiveDownloads[$x].id -Activity $_Activity -Status $_Status -PercentComplete $_Percent -ErrorAction SilentlyContinue

                $total_percent = $total_percent + $_Percent
            }

            Start-Sleep -Milliseconds 150
        }
        $this._Logger.WriteLog([LogType]::INFO,"Active Downloads Completed")
    }

    [void]DownloadFiles(){ $this.DownloadFiles($this.Configs) }


}