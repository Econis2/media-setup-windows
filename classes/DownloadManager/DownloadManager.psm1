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

            $ID = (New-Guid).Guid
            $WC = [System.Net.WebClient]::new()
            
            Register-ObjectEvent -InputObject $WC -EventName DownloadProgressChanged -Action {
                [int]$Percent = [Math]::Round( 100 * ($eventargs.BytesTransferred / $eventargs.BytesTotal))
                New-Event -SourceIdentifier "FileDownloadUpdate-$ID" -MessageData @($Percent, $eventargs.BytesReceived, $eventargs.TotalBytesToReceive) | Out-Null
            }

            Register-ObjectEven -InputObject $WC -EventName DownloadFileCompleted -Action {
                New-Event -SourceIdentifier "FileDownloadCompleted-$ID" | out-null
            }

            $WC.DownloadFileAsync($Config.Url, $Config.Path)
            
            $this.CurrentJobs.add($ID) | Out-Null
                
                #$(Start-Process -File )
                #$(Start-BitsTransfer -Source $Config.Url -Destination $Config.Path -Asynchronous -ErrorAction Stop) 
            #)
        }
        catch{
            $this.Logger.WriteLog([LogType]::ERROR, "Unable to Download FROM: $($Config.Url) TO: $($Config.Path)")
            $this.Logger.WriteLog([LogType]::ERROR, $_.Exception.Message)
            return $false
        }
        return $true
    }

    [bool]DownloadFile(){ return $this.DownloadFile($this.Config) }


    [bool]DownloadFiles(){
        $return = $true
        $this.Configs.forEach({ # Loop through the Configs
            if( !$this.DownloadFile($_) ){ $ErrorJobs.add($_) | Out-Null; $return = $false }
        }) 
        return $return
    }

    [void]WatchDownload(){
        [hashtable]$Jobs = @()

        $this.CurrentJobs.ForEach({
            [hashtable]$Job = @{
                id = $_
                completed = $false
                percent = 0
                total = 0
                current = 0
            }
            $event = Register-EngineEvent -SourceIdentifier "FileDownloadUpdate-$_" -Action {
                $Job.percent = $event.MessageData[0]
                $Job.current = $event.MessageData[1]
                $Job.total = $event.MessageData[2]
            }

            Register-EngineEvent -SourceIdentifier "FileDownloadCompleted-$_" -Action {
                $Job.completed = $true
            }
        })

        While( ($Jobs | ?{$_.completed -eq $false}).length -eq 0 ){
            $index = 0
            $Jobs.forEach({
                Write-Progress -Id $index -Activity "Downloading" -Status "$($_.current) of $($_.total)" -PercentComplete $_.percent
                $x++
            })
            Start-Sleep -Milliseconds 250
        }

    }
    # [bool]WatchDownloads([bool]$Display){
    #     [bool]$Finished = $false
    #     while(!$Finished){ # While Jobs are Running
    #         $this.CurrentJobs.forEach({ # Loop through Active jobs
    #             $Id = $this.CurrentJobs.IndexOf($_)
    #             if($_.JobState -eq "Transferred"){ # Job Has Completed
    #                 $FinishedJobs.add($_) | Out-Null # Add to Completed Jobs
    #                 $CurrentJobs.remove($_) | Out-Null# Remove from Active Jobs
    #             }
    #             else{
    #                 if($Display){ # If Display is active
    #                     # Show Progress Bar of Download
    #                     Write-Progress -Id $Id -PercentComplete $this.getJobPercent($_) -Status "$($_.BytesTransferred) of $($_.BytesTotal)" -Activity "Downloading..." 
    #                 }
    #             }
    #             if($this.CurrentJobs.length -eq 0){ $Finished = $true }
    #         })
    #         Start-Sleep -Milliseconds 500 # Wait .5 Sec to refresh Status Bars
    #     }
    #     return $Finished
    # }
    #[int]getJobPercent($Job){ return [Math]::Round( ($Job.BytesTransferred / $Job.BytesTotal) * 100 ) }
}