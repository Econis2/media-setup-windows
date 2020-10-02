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

    hidden [void]_Download([DownloadConfig]$Config){ [System.Net.WebClient]::new().DownloadDataAsync($Config.Url, $Config.Path) }

    [bool]DownloadFile([DownloadConfig]$Config){
        # Get File Statistics
        $Length = ([System.Net.WebRequest]::Create($_.Url).GetResponse().Headers['Content-Length'])

        $this._Download($Config)
        $completed = $false
        while(!$completed){
            for($x = 0; $x -lt $this.CurrentJobs.Count; $x++){
                $c_length = (Get-Item $this.CurrentJobs[$x].Path).Length

                if($Length -eq $c_length){
                    $completed = $true
                    break
                }
                $percent = ( $c_length / $this.CurrentJobs[$x].size) * 100
                Write-Progress -Id $x -Activity "Downloading" -Status "$c_length of $($this.CurrentJobs[$x].size)" -PercentComplete $percent

            }
            Start-Sleep -Milliseconds 50
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

    [bool]DownloadFiles([DownloadConfig[]]$Configs){
        $Configs.forEach({
            $this.DownloadFile($_)
        })
        return $true
    }

    [int]getJobPercent($Job){ return [Math]::Round( ($Job.BytesTransferred / $Job.BytesTotal) * 100 ) }
}