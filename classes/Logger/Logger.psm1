using module ".\LogType\LogType.psm1"
using module ".\LoggerConfig\LoggerConfig.psm1"

class Logger {
    [string]$LogPath = "C:\log"
    [bool]$OutputConsole = $false
    [bool]$OutputFile = $false

    Logger([bool]$File){
        if($File){
            try{
                if( !$(Get-Item -Path $env:LOG_PATH -ErrorAction SilentlyContinue)){
                    New-Item -Path "C:\" -Name "log" -ItemType File -ErrorAction Stop | out-null
                }                
                Write-Host "Setting Log to File: $($env:LOG_PATH)" -ForegroundColor cyan
                $this.LogPath = $env:LOG_PATH
            }
            catch{
                try{
                    Write-Host "Unable to create File: $($env:LOG_PATH)" -ForegroundColor yellow
                    if( !$(Get-Item -Path "C:\log" -ErrorAction SilentlyContinue)){
                        New-Item -Path "C:\" -Name "log" -ItemType File -ErrorAction Stop | out-null
                    }
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
                if( !$(Get-Item -Path $env:LOG_PATH -ErrorAction SilentlyContinue)){
                    New-Item -Path "C:\" -Name "log" -ItemType File -ErrorAction Stop | out-null
                }  
                Write-Host "Setting Log to File: $($env:LOG_PATH)" -ForegroundColor cyan
                $this.LogPath = $env:LOG_PATH
            }
            catch{
                try{
                    Write-Host "Unable to create File: $($env:LOG_PATH)" -ForegroundColor yellow
                    if( !$(Get-Item -Path "C:\log" -ErrorAction SilentlyContinue)){
                        New-Item -Path "C:\" -Name "log" -ItemType File -ErrorAction Stop | out-null
                    }                    Write-Host "Setting Log to File: C:\log" -ForegroundColor cyan
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
        [string]$timeStamp = "[$($date.Year)-$($date.Month)-$($date.Day):$($date.Hour):$($date.Minute)"
        [string]$logMessage = $TimeStamp + "[$_messageType]" + $_message

        if($this.OutputConsole){
            [string]$color = "cyan"
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