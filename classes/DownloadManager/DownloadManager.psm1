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

    [bool]DownloadFile([DownloadConfig]$Config){
        $this.Logger.WriteLog([LogType]::INFO, "Starting Download FROM: $($Config.Url) TO: $($Config.Path)")
        try{
            $this.CurrentJobs.add( $(Start-BitsTransfer -Source $Config.Url -Destination $Config.Path -Asynchronous -ErrorAction Stop) )
        }
        catch{
            $this.Logger.WriteLog([LogType]::ERROR, "Unable to Download FROM: $($Config.Url) TO: $($Config.Path)")
            $this.Logger.WriteLog([LogType]::ERROR, $_.Exception.Message)
            return $false
        }
        return $true
    }

    [bool]DownloadFile(){
        $this.Logger.WriteLog([LogType]::INFO, "Starting Download FROM: $($this.Config.Url) TO: $($this.Config.Path)")
        try{
            $this.CurrentJobs.add( $(Start-BitsTransfer -Source $this.Config.Url -Destination $this.Config.Path -Asynchronous -ErrorAction Stop) )
        }
        catch{
            $this.Logger.WriteLog([LogType]::ERROR, "Unable to Download FROM: $($this.Config.Url) TO: $($this.Config.Path)")
            $this.Logger.WriteLog([LogType]::ERROR, $_.Exception.Message)
            return $false
        }
        return $true
    }


    [bool]DownloadFiles(){
        $return = $true
        $this.Configs.forEach({ # Loop through the Configs
            if( !$this.DownloadFile($_) ){ $ErrorJobs.add($_) | Out-Null; $return = $false }
        }) 
        return $return
    }

    [bool]WatchDownloads([bool]$Display){
        [bool]$Finished = $false
        while(!$Finished){ # While Jobs are Running
            $this.CurrentJobs.forEach({ # Loop through Active jobs
                if($_.JobState -eq "Transferred"){ # Job Has Completed
                    $FinishedJobs.add($_) | Out-Null # Add to Completed Jobs
                    $CurrentJobs.remove($_) | Out-Null# Remove from Active Jobs
                }
                else{
                    if($Display){ # If Display is active
                        # Show Progress Bar of Download
                        Write-Progress -Id $_.JobId -PercentComplete $this.getJobPercent($_) -Status "$($_.BytesTransferred) of $($_.BytesTotal)" -Activity "Downloading..." 
                    }
                }
                if($this.CurrentJobs.length -eq 0){ $Finished = $true }
            })
            Start-Sleep -Milliseconds 500 # Wait .5 Sec to refresh Status Bars
        }
        return $Finished
    }
    [int]getJobPercent($Job){ return [Math]::Round( ($Job.BytesTransferred / $Job.BytesTotal) * 100 ) }
}