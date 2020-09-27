enum LogType {
    INFO
    WARN
    ERROR
}

class LoggerConfig {
    [bool]$Console
    [bool]$File
}

class Logger {
    [string]$LogPath = "C:\log"
    [bool]$OutputConsole = $false
    [bool]$OutputFile = $false

    Logger([bool]$File){
        if($File){
            try{
                New-Item $env:LOG_PATH -ItemType File -ErrorAction Stop
                Write-Host "Setting Log to File: $($env:LOG_PATH)" -ForegroundColor cyan
                $this.LogPath = $env:LOG_PATH
            }
            catch{
                try{
                    Write-Host "Unable to create File: $($env:LOG_PATH)" -ForegroundColor yellow
                    New-Item -Path "C:\" -Name "log" -ItemType File -ErrorAction Stop | out-null
                    Write-Host "Setting Log to File: C:\log" -ForegroundColor cyan
                }
                catch{
                    throw "Unable to Create Log File"
                }
            }
        }
        $this.OutputFile = $true
    }

    Logger([bool]$File, [bool]$Console){
        if($File){
            try{
                New-Item $env:LOG_PATH -ItemType File -ErrorAction Stop
                Write-Host "Setting Log to File: $($env:LOG_PATH)" -ForegroundColor cyan
                $this.LogPath = $env:LOG_PATH
            }
            catch{
                try{
                    Write-Host "Unable to create File: $($env:LOG_PATH)" -ForegroundColor yellow
                    New-Item -Path "C:\" -Name "log" -ItemType File -ErrorAction Stop | out-null
                    Write-Host "Setting Log to File: C:\log" -ForegroundColor cyan
                }
                catch{
                    throw "Unable to Create Log File"
                }
            }
        }
        $this.OutputFile = $true
        if($Console){ $this.OutputConsole = $true }
    }

    Logger([string]$File, [string]$_logPath){
        if($File){
            try{ 
                Get-Item -Path $_logPath -ErrorAction Stop
                Write-Host "Setting Log to File: $($_logPath)" -ForegroundColor cyan
                $this.LogPath = $_logPath 
            }
            catch{
                try{
                    Write-Host "Unable to create File: $($_logPath)" -ForegroundColor yellow
                    New-Item $env:LOG_PATH -ItemType File -ErrorAction Stop
                    Write-Host "Setting Log to File: $($env:LOG_PATH)" -ForegroundColor cyan
                    $this.LogPath = $env:LOG_PATH
                }
                catch{
                    try{
                        Write-Host "Unable to create File: $($env:LOG_PATH)" -ForegroundColor yellow
                        New-Item -Path "C:\" -Name "log" -ItemType File -ErrorAction Stop | out-null
                        Write-Host "Setting Log to File: C:\log" -ForegroundColor cyan
                    }
                    catch{
                        throw "Unable to Create Log File"
                    }
                }
            }
        }
        $this.OutputFile = $true
    }

    Logger([bool]$File, [bool]$Console, [string]$_logPath){
        if($File){
            try{ 
                Get-Item -Path $_logPath -ErrorAction Stop
                Write-Host "Setting Log to File: $($_logPath)" -ForegroundColor cyan
                $this.LogPath = $_logPath 
            }
            catch{
                try{
                    Write-Host "Unable to create File: $($_logPath)" -ForegroundColor yellow
                    New-Item $env:LOG_PATH -ItemType File -ErrorAction Stop
                    Write-Host "Setting Log to File: $($env:LOG_PATH)" -ForegroundColor cyan
                    $this.LogPath = $env:LOG_PATH
                }
                catch{
                    try{
                        Write-Host "Unable to create File: $($env:LOG_PATH)" -ForegroundColor yellow
                        New-Item -Path "C:\" -Name "log" -ItemType File -ErrorAction Stop | out-null
                        Write-Host "Setting Log to File: C:\log" -ForegroundColor cyan
                    }
                    catch{
                        throw "Unable to Create Log File"
                    }
                }
            }
        }
        $this.OutputFile = $true
        if($Console){ $this.OutputConsole = $true }
    }

    [void]WriteLog([LogType]$_messageType, [string]$_message){
        # Get TimeStamp
        $date = Get-Date
        [string]$timeStamp = "[$($date.Year)-$($date.Month)-$($date.Day):$($date.Hour):$($date.Minute):$($date.Second)]"
        [string]$logMessage = $TimeStamp + "[$_messageType]" + $_message

        if($this.OutputConsole){
            [string]$color = "white"
            [string]$type =
            switch($_messageType){
                [LogType]::INFO { $color = "cyan" }
                [LogType]::WARN { $color = "yellow" }
                [LogType]::ERROR { $color = "red" }
            }
            Write-Host $logMessage -ForegroundColor $color
        }
        if($this.OutputFile){
            try{
                Add-Content -Path $this.LogPath -Value $logMessage -ErrorAction Stop
            }
            catch{
                Write-Error "Unable to  write to file:$($this.LogPath)"
                Write-Error $_.Exception.Message
            }
        }
    }
}

class DownloadConfig {
    [string]$Url
    [string]$Path

    DownloadConfig([string]$_url,[string]$_path){
        $this.Url = $_url
        $this.Path = $_path
    }
}

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


class BaseWrapper {


    BaseWrapper(){}


}