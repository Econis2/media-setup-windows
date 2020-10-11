using module "..\Logger\Logger.psm1"
using module "..\Logger\LogType\LogType.psm1"

$env:WARN = [LogType]::WARN
$env:ERROR = [LogType]::ERROR
$env:INFO = [LogType]::INFO

class InstallManager {

    hidden [Logger]$_Logger
    
    InstallManager([Logger]$Logger){
        $this._Logger = $Logger
    }

    [bool]isInstalled([string]$name){
        try{
            $app_key = Get-ItemPropertyValue (Get-ChildItem "HKLM:\\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | ?{$_.name -like "*$name*"}).Name.replace("HEKY_LOCAL_MACHINE",'HKLM:\') -Name DisplayName
            if(!$app_key.contains($name)){ return $false }
            else{ return $true }
        }
        catch {
            return $false
        }
    }

    [void]SetupService($App){
        if($App.service -and $App.service.trim() -ne ""){ # Service Parameter
            try{
                $this._Logger.WriteLog($env:INFO,"Setting Up Service for $()")
                $Name = "MediaStack-$($App.name)"
                $DisplayName = "MediaStack $($App.name)"
                #Set as a service
                $null = New-Service -Name $Name `
                    -DisplayName $DisplayName `
                    -Description "Supports the opperation of running MediaStack" `
                    -StartupType Automatic `
                    -BinaryPathName "$env:ProgramData\$($App.service)"
                    -ErrorAction Stop

                $null = Start-Service -Name $Name -ErrorAction Stop
            }
            catch{ 
                $this._Logger.WriteLog($env:WARN,"App: $($App.name) Service Parameter incorrect, will run as user") 
                $this._Logger.WriteLog($env:WARN,$_.Exception.Message)
            }
        }
        else{ $this._Logger.WriteLog($env:WARN,"App: $($App.name) Service Parameter not set, will run as user") }
    }

    [bool]CreateAppConfig([string]$PATH, $config){
        $this._Logger.WriteLog()
        $ini = "[Setup]`n"
        $config.Keys.forEach({
            $ini += "$_=$($config.$_)`n"
        })

        try{
            $ini | Out-File $PATH -ErrorAction Stop
        }
        catch{

            return $false
        }

        return $true
    }

    [void]InstallApp([bool]$SERVICE, $App){
        try{
            if($App.containsKey("config")){ # Create install config file
                if($SERVICE){ 
                    $App.config.Tasks = "windowsservice" 
                    $SERVICE = $false # Stops lower Service from Triggering
                }

                $this._Logger.WriteLog($env:INFO,"Creating setup confid for App: $($App.name)")
                $this.CreateAppConfig("$(Split-Path $App.path)\$($App.name).ini",$App.config)
            }

            if($App.args.contains("{path}")){ # Update Path Template Property
                $App.args = $App.args.replace('{path}',"$(Split-Path $App.path)")
            }

            $this._Logger.WriteLog($env:INFO,"Installing App: $($App.name)")
            Start-Process $App.path `
                -ArgumentList $App.args.split(' ') `
                -Wait `
                -ErrorAction Stop

            if($SERVICE){ $this.SetupService($SERVICE, $_) }
        }
        catch{
            $this._Logger.WriteLog($env:ERROR,"App: $($App.name) installation failure")
            $this._Logger.WriteLog($env:ERROR,$App.Exception.Message)
            throw "App: $($App.name) installation failure"
        }
    }
}