using module ".\DownloadConfig\DownloadConfig.psm1"
using module "..\Logger\Logger.psm1"
using module "..\Logger\LogType\LogType.psm1"

class DownloadManager {
    [DownloadConfig[]]$Configs
    [DownloadConfig]$Config
    [System.Collections.ArrayList]$CurrentJobs = @()# In Progress BitsTransferJobs
    [System.Collections.ArrayList]$FinishedJobs = @()# Completed BitsTransferJobs
    [System.Collections.ArrayList]$ErrorJobs = @()# Jobs That Errored
    hidden [Logger]$Logger = [Logger]::new($true, $true)

    DownloadManager([DownloadConfig[]]$_configs){ $this.Configs = $_configs }
    DownloadManager([DownloadConfig]$_config){ $this.Config = $_config }

    hidden [void]_Download([DownloadConfig]$Config){ [System.Net.WebClient]::new().DownloadDataAsync($Config.Path,$Config.Url) }

    [bool]DownloadFile([DownloadConfig]$Config){
        # Get File Statistics
        $Length = ([System.Net.WebRequest]::Create($_.Url).GetResponse().Headers['Content-Length'])

        $this._Download($Config)

        $this.CurrentJobs.Add(@{
            Path = $Config.Path
            Url = $Config.Url
            Size = $Length
        }) | Out-Null

        return $true
    }

    [bool]DownloadFile(){ return $this.DownloadFile($this.Config) }

    [bool]DownloadFiles(){
        [System.Collections.Arraylist]$Jobs = @()
        # Get File Stats
        $this.Configs.forEach({
            $Jobs.Add(@{
                Url = $_.Url
                Path = $_.Path
                Size = ([System.Net.WebRequest]::Create($_.Url).GetResponse().Headers['Content-Length'])
            }) | Out-Null
        })
        # Start File Downloads
        $this.Configs.forEach({
            $this._Download($_)
        })

        return $true

    }

    [void]WatchDownloads(){

        while($this.CurrentJobs.Count -ne 0){
            for($x = 0; $x -lt $this.CurrentJobs.Count; $x++){
                $c_length = (Get-Item $this.CurrentJobs[$x].Path).Length

                if($this.CurrentJobs[$x].size -eq $c_length){
                    $this.FinishedJobs.Add($this.CurrentJobs[$x]) | Out-Null
                    $this.CurrentJobs.RemoveAt($x) | Out-Null
                }
                $percent = ( $c_length / $this.CurrentJobs[$x].size) * 100

                Write-Progress -Id $x -Activity "Downloading" -Status "$c_length of $($this.CurrentJobs[$x].size)" -PercentComplete $percent

            }

            Start-Sleep -Milliseconds 150
        }

    }
    [int]getJobPercent($Job){ return [Math]::Round( ($Job.BytesTransferred / $Job.BytesTotal) * 100 ) }
}