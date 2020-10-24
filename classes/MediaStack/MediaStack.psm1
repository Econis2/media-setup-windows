using module "..\Logger\Logger.psm1"
using module "..\Logger\LogType\LogType.psm1"
using module "..\DownloadManager\DownloadManager.psm1"
using module "..\DownloadManager\DownloadConfig\DownloadConfig.psm1"
using module "..\Utilities\Utilities.psm1"

$env:WARN = [LogType]::WARN
$env:ERROR = [LogType]::ERROR
$env:INFO = [LogType]::INFO

enum Stage {
    INIT
    DEP_DOWNLOAD
    DEP_INSTALL
    APP_DOWNLOAD
    APP_INSTALL
    APP_SETUP # Could expand to each app
    CLEAN_UP
    COMPLETED
}

class MediaStack {
    # Public Properties
    $Paths = @{
        config = @{
            user = $null
            system = $null
        }
    }
    $Config = @{
        user = @{}
        system = @{}
    }
    
    # Private Properties
    hidden [Utilities]$_Util = [Utilities]::new()
    hidden [bool]$_Reload = $false
    hidden [int]$_Task = 0
    hidden [Stage]$_Stage = [Stage]::INIT
    hidden [Logger]$_Logger
    hidden [System.Collections.ArrayList]$_toDownload = @()

    MediaStack([string]$SystemConfig, [string]$UserConfig){
        $this.Paths.config.system = $SystemConfig
        $this.Paths.config.user = $UserConfig
    }

    [void]SetTask([int]$task){ $this._Task = $task }
    [void]SetStage([Stage]$stage){ $this._Stage = $stage }
    [void]Reload(){ $this._Reload = $true }
    
    [void]Setup(){

        if($this._Reload){ $this._Load() }

        while($this._Stage -ne [Stage]::COMPLETED){
            switch($this._Stage){
                [Stage]::INIT {
                    # Run Init - Possibly Reboot to User
                    $this._Init()
                    # No Reboot, set to next stage and Continue
                    $this.SetStage([Stage]::DEP_DOWNLOAD)
                    break
                }

                [Stage]::DEP_DOWNLOAD {
                    $this._Logger.WriteLog($env:INFO, "Entering Stage DEP_DOWNLOAD")
                    # Continue setup - Downloads
                    # downloads .NET (other dep - none atm)
                    
                    $this._GetMediaStackDependencies()
                    $this.SetStage([Stage]::DEP_INSTALL)
                    break # Move to Next Stage
                }


                [Stage]::DEP_INSTALL {
                    $this._Logger.WriteLog($env:INFO, "Entering Stage DEP_INSTALL")
                    # Continue setup - Install
                    # installs .Net - requires restart
                    $this._InstallApps('DEPENDENCIES')
                    $this.SetStage([Stage]::APP_DOWNLOAD)
                    break # Move to Next Stage
                }

                [Stage]::APP_DOWNLOAD {
                    $this._Logger.WriteLog($env:INFO, "Entering Stage APP_DOWNLOAD")
                    # Continue setup -  Downloads
                    # downloads Sonarr, Radarr, Jackett, Deluge, nzbget, Plex Server
                    $this._GetMediaStackApps()
                    $this.SetStage([Stage]::APP_INSTALL)
                    break # Move to Next Stage

                }

                [Stage]::APP_INSTALL {
                    $this._Logger.WriteLog($env:INFO, "Entering Stage APP_INSTALL")
                    # Continue setup - Install
                    # $this._InstallMediaStackApps()
                    # installs Sonarr, Radarr, Jackett, Deluge, nzbget, Plex Server
                    
                    #$this._InstallMediaStackApps()
                    $this.SetStage([Stage]::CLEAN_UP)
                    break # End For now
                }

                [Stage]::CLEAN_UP {
                    $this._Logger.WriteLog($env:INFO, "Installation and Configuration completed, performing clean up")
                    $this.SetStage([Stage]::COMPLETED)
                    break # End For now
                }
            }
        }
    }
#### CONFIGURATION ####

    hidden [void]_LoadConfig([string]$Name){
        try{
            Write-Host "Getting $Name config from: $($this.Paths.config.$Name)" -ForegroundColor cyan
            $_config = ConvertFrom-Json -InputObject $(Get-Content -Path $this.Paths.config.$Name -Raw -ErrorAction Stop) -ErrorAction Stop
            $this.Config.$Name = $_config

            Write-Host "Removing File: $($this.Paths.config.$Name)" -ForegroundColor cyan
            $null = Remove-Item -Path $this.Paths.config.$Name -ErrorAction Stop | Out-Null
        }
        catch { Throw $_.Exception.Message }
    }

    hidden [void]_Load(){
        try{
            Write-host "Atttempting to load User Config" -ForegroundColor Cyan
            $this._LoadConfig('user') # Load User from File to Memory
            # Decrypt User Credentials
            $this.Config.user.DEFAULT_PASSWORD = [System.Management.Automation.PSCredential]::new("any", $this.Config.user.DEFAULT_PASSWORD).GetNetworkCredential().Password
            
            $env:LOG_PATH = $this.Config.user.LOG_PATH # Set Log Path
            $this._Logger = [Logger]::new($true, $true, $env:LOG_PATH) # Set Logger to Config Path
            $env:APP_TEMP = $this.Config.user.TEMP_PATH # Set Temp Directory
            $this._LoadConfig('system') # Load System Config

            $this._Reload = $false
        }
        catch{ Throw $_.Exception.Message }
    }

    hidden [void]_Init(){
        
        try{ # Load User Configuration
            # Load from File to Memory
            $this._LoadConfig('user')
            
            #### Log Path ####
            if( (Test-Path -Path $this.Config.user.LOG_PATH.trim() -IsValid ) ){
                $env:LOG_PATH = $this.Config.user.LOG_PATH.trim()
                $this._Logger = [Logger]::new($true, $true, $env:LOG_PATH) # Set Logger to Config Path
            }
            else{
                # Using Default Log Path
                $env:LOG_PATH = $this.Config.user.LOG_PATH.trim()
                $this._Logger = [Logger]::new($true, $true, "$env:APPDATA\MediaStack\install.log") # Set Logger to created Log Path
                $this.Config.user.LOG_PATH = "$env:APPDATA\MediaStack\install.log" # Set the Log Path in Memory to New Location
            }

            #### Temp Directory ####
            if( (Test-Path -Path $this.Config.user.TEMP_PATH.trim() -IsValid ) ){ $env:APP_TEMP = $this.Config.user.TEMP_PATH.trim() }
            else{
                # Using Default Log Path
                $this.Config.user.TEMP_PATH = "$env:APPDATA\MediaStack"
                $env:APP_TEMP = "$env:APPDATA\MediaStack"
            }

        }
        catch{ Throw $_.Exception.Message }

        try{ $this._LoadConfig('system') } # Load System Config
        catch{
            $this._Logger.WriteLog($env:ERROR,"Unable to Load System Config File")
            $this._Logger.WriteLog($env:ERROR,$_.Exception.Message)
            Throw "Unable to Load System Config File"
        }

        if( ![string]::IsNullOrWhiteSpace($this.Config.user.SETUP.DEFAULT_USER) ){ # No Default User Specified
            $this._Logger.WriteLog($env:WARN,"No DEFAULT_USER specified in the user-config.json")
            $this._Logger.WriteLog($env:INFO,"Attempting to create new user: MediaStack")
            
            try{ # Create Media Stack User
                $this.Config.user.SETUP.DEFAULT_USER = "MediaStack"
                $this.Config.user.SETUP.DEFAULT_PASSWORD = $this._Util.RandomPassword(16,$false)
                New-LocalUser `
                    -AccountNeverExpires `
                    -Description "User Created to Run for MediaStack" `
                    -Name "MediaStack"
                    -Password (ConvertTo-SecureString -String $this.Config.user.SETUP.DEFAULT_PASSWORD -AsPlainText -Force -ErrorAction Stop)
                    -ErrorAction Stop
                
                $this._Logger.WriteLog($env:INFO,"User: MediaStack created")
                $this._Logger.WriteLog($env:INFO,"Pass: $($this.Config.user.SETUP.DEFAULT_PASSWORD)")
            }
            catch{
                $this._Logger.WriteLog($env:ERROR,"Unable to create MediaStack install user")
                $this._Logger.WriteLog($env:ERROR, $_.Exception.Message)
                Throw "Unable to create MediaStack install user"
            }
        }

        try{ # Create AutoLogon for DEFAULT_USER
            $this._Logger.WriteLog($env:INFO,"Setting Up AutoLogin")
            $this._SetAutoLogin()
        }
        catch{
            $this._Logger.WriteLog($env:ERROR,"Unable to setup Autologon")
            $this._Logger.WriteLog($env:ERROR, $_.Exception.Message)
            Throw "Unable to setup Autologon"
        }

        if($env:username -ne $this.Config.user.SETUP.DEFAULT_USER){ # Reboot to Required User, if Needed
            try{ # Set To Run After Reboot
                $this._SetRunOnce([Stage]::DEP_DOWNLOAD,0)
                Restart-Computer -Force
            }
            catch{
                $this._Logger.WriteLog($env:ERROR,"Unable to Write RunOnce, Installation cannot continue")
                $this._Logger.WriteLog($env:ERROR,$_.Exception.Message)
                Throw "Unable to Write RunOnce, Installation cannot continue"
            }
        }
    }

#### DOWNLOADING ####
    hidden [void]_DownloadReady(){

        if($this._toDownload.Count -gt 0){
            $this._Logger.WriteLog($env:INFO,"Collection Download Details")
            [System.Collections.ArrayList]$Apps = $this._toDownload.forEach({
                $full_name = "$($_.name)-$($_.version).$($_.type)"
                $this._Logger.WriteLog($env:INFO,"Getting config for app: $full_name")
                $url = "$($this.Config.system.'BASE_URL')/$($this.Config.system.'RELEASE')/$full_name"
                $path = "$env:APP_TEMP\$full_name"
                return [DownloadConfig]::new($url, $path)
            })

            $this._Logger.WriteLog($env:INFO,"Downloading Applications")
            while($Apps.Count -ne 0){
                [DownloadManager]::new($this._Logger).DownloadFiles($Apps)

                $this._Logger.WriteLog($env:INFO,"Verifying Apps have successfully downloaded")
                for($x=0; $x -lt $Apps.Count; $x++){
                    $this._Logger.WriteLog($env:INFO,"Checking $($Apps[$x].Path)")
                    if(Test-Path $Apps[$x].Path){
                        $this._Logger.WriteLog($env:INFO,"App Found")
                        $Apps.RemoveAt($x)
                        $x = $x -1
                    }
                }
            }
            $this._toDownload = [System.Collections.ArrayList]@()
        }
        else{ $this._Logger.WriteLog($env:INFO, "Nothing to Download") }
    }

    hidden [void]_GetMediaStackDependencies(){
        $this._Logger.WriteLog($env:INFO, "Checking for MediaStack Depedencies")
        $this.Config.system.'DEPENDENCIES'.forEach({
            $NAME = $_.name
            if($NAME -eq "dotNet"){ # dotNet
                $download = $false
                $val = $(Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Net Framwork Setup\NDP\v4\Full' -ErrorAction SilentlyContinue)
                
                if($val){ # .Net Installed
                    if(!$val.GetValue('release') -gt $_.check){ # Checking Version
                        $this._Logger.WriteLog($env:WARN, "App $($NAME) not installed")
                        if(!(Test-Path "$env:APP_TEMP/$NAME-$($_.version).$($_.type)")){ $download = $true } # Checking Installer Path
                    }
                }
                else{ $download = $true }

                if($download){
                    $this._toDownload.Add($_) | Out-Null 
                    ($this.Config.system.'DEPENDENCIES' | Where-Object {$_.name -eq $NAME}).path = "$env:APP_TEMP/$NAME-$($_.version).$($_.type)"         
                }
            }           
        })
        $this._DownloadReady() # Download Dependencies
    }

    hidden [void]_GetMediaStackApps(){
        $this._Logger.WriteLog($env:INFO, "Checking for MediaStack Apps")
        $this.Config.system.APPS.forEach({
            $NAME = $_.name
            if(!($this._isInstalled($NAME))){
                $this._Logger.WriteLog($env:WARN, "App $NAME not installed")
                $this._toDownload.Add($_) | Out-Null
                ($this.Config.system.'APPS' | Where-Object {$_.name -eq $NAME}).path = "$env:APP_TEMP/$NAME-$($_.version).$($_.type)" 
            }
        })

        $this._DownloadReady() # Download Required Files
    }

#### INSTALLATION ####

    hidden [void]_SetupAppConfig($_App){ # Creates Install File if Needed

        if(!$_App.containsKey("file")){ return } # No File To configure
        
        try{
            if($_App.file.contains('{path}')){
                $path = "$env:APP_TEMP\$($_App.name).ini"
                $_App.args = $_App.args + " " + $_App.file.replace('{path}',$path)
                $_App.file = $_App.file.replace('{path}',$path)
    
                $INI = "[Setup]`n"
                $_App.config.Keys.forEach({
                    $INI += "$_=$($_App.config[$_])`n"
                })

                $null = $INI | Out-File $path -ErrorAction Stop
            }
        }
        catch{
            $this._Logger.WriteLog($env:ERROR,"Unable to create setup file for App $($_App.name)")
            $this._Logger.WriteLog($env:ERROR, $_.Exception.Message)
            Throw "Unable to create setup file for App $($_App.name)"
        }

    }

    hidden [void]_SetupAppService($_App){

        New-Service -Name "MediaStack-$($_App.name)" -DisplayName "MediaStack $($_App.name)" -Description "Used in the Automated MediaStack" -StartupType Automatic -BinaryPathName 
    }
    
    hidden [void]_InstallApps([string]$Type){
        if($this._Task -le $this.Config.system.$Type.Count){ # Tasks Not Finished
            for($x=$this._Task; $x -lt $($this.Config.system.$Type.Count); $x++){ # Loop Install Tasks
                try{
                    $App_Task = $this.Config.system.$Type[$x] # Current Install Task

                    $this._ParseAppInstallConfig($App_Task) # Create Setup file if required
                    
                    $this._Logger.WriteLog($env:INFO,"Installing App: $($_.name)")
                    # Start the Installer
                    Start-Process $_.path `
                        -ArgumentList $_.args.split(' ') `
                        -Wait `
                        -ErrorAction Stop
        
                    # Set as Service
                    if($App_Task.config.service){

                    }

                    if($App_Task.restart){ # Needs Restart
                        $Stage = $null
                        switch($Type){ # Set To Current Stage
                            "DEPENDENCIES" { $Stage = [Stage]::DEP_INSTALL }
                            "APPS" { $Stage = [Stage]::APP_INSTALL }
                        }
                        $this._SetRunOnce($Stage ,$x++) # Set to run Next Task in Current Stage
                        Restart-Computer -Delay 5 -ErrorAction Stop # Restart after 5 Seconds
                    }
                }
                catch{
                    $this._Logger.WriteLog($env:ERROR,"Unable To install Application $($_.name)")
                    $this._Logger.WriteLog($env:ERROR,$_.Exception.Message)
                    Throw "Unable To install Application $($_.name)"
                }
            }
        }
        else{ # All Task has Finished Exit
            $this._Logger.WriteLog($env:INFO,"All $Type Tasks have completed")
            $this._Task = 0 # Reset Task Number
        } 
    }

    hidden [void]_InstallMediaStackDependencies(){ # wrapper
        Try{
            $this._InstallApps("DEPENDENCIES") # Will Restart If Needed, this is just a wrapper
        }
        catch{ Throw $_.Exception.Message } # Surface Previous Errors, This is just a wrapper
    }

    <#hidden [void]_InstallMediaStackApps(){
        Try{
            $this._InstallApps("APPS")
        }
        catch{
            Throw $_.Exception.Message
        }
    }#>

#### UTILTIES ####
hidden [bool]_isInstalled([string]$_name){
    if( ((Get-ChildItem HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall) | Where-Object { $_.GetValue("DisplayName") -like "*$_name*"}).count -ge 1){ return $true }
    return $false
}

hidden [void]_SaveConfig([string]$config){
    try{
        switch($config){
            "user" { $this.Config.user.SETUP.DEFAULT_PASSWORD = ConvertFrom-SecureString (ConvertTo-SecureString -String $this.Config.user.SETUP.DEFAULT_PASSWORD -AsPlainText -Force) }
            default { break }
        }

        $this._Logger.WriteLog($env:INFO, "Saving Config: $config")       
        (ConvertTo-Json $this.Config.$config -ErrorAction Stop) | Out-File "$env:APP_TEMP\$config-config.json" -ErrorAction Stop 
    }
    catch{
        $this._Logger.WriteLog($env:ERROR, "Unable to Save Config: $config")
        $this._Logger.WriteLog($env:ERROR, $_.Exception.Message)
        Throw "Unable to save Config: $config"
    }
}

hidden [void]_SetAutoLogin(){
    try{
        $this._Logger.WriteLog($env:INFO, "Creating Auto Login Keys")
        $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon'
        Set-ItemProperty $regPath -Name "AutoAdminLogon" -Value "1" -ErrorAction Stop
        Set-ItemProperty $regPath -Name "DefaultUsername" -Value $this.Config.user.SETUP.DEFAULT_USER -ErrorAction Stop
        Set-ItemProperty $regPath -Name "DefaultPassword" -Value $this.Config.user.SETUP.DEFAULT_PASSWORD -ErrorAction Stop
    }
    catch{
        $this._Logger.WriteLog($env:ERROR, "Unable to set up Automatic Login")
        $this._Logger.WriteLog($env:ERROR, $_.Exception.Message)
        Throw "Unable to set up Automatic Login"
    }
}

hidden [void]_RemoveAutoLogin(){
        $this._Logger.WriteLog($env:INFO, "Removing Auto Login Keys")
        $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon'
        Remove-ItemProperty $regPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
        Remove-ItemProperty $regPath -Name "DefaultUsername" -ErrorAction SilentlyContinue
        Remove-ItemProperty $regPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
}

hidden [void]_SetRunOnce([Stage]$Stage,[int]$Task){
    try{ # Backup Configs - To Temp Directory
        $this._SaveConfig("system")
        $this._SaveConfig("user")
    }
    catch{ Throw $_.Exception.Message }
    
    try{ # Create Command, and RunOnce Key
        $command = @"
using module "$PSScriptRoot\classes\MediaStack\MediaStack.psm1"
        
`$MediaStack = [MediaStack]::new("$env:APP_TEMP\system-config.json","$env:APP_TEMP\user-config.json")
`$MediaStack.Reload()
`$MediaStack.SetStage($Stage)
`$MediaStack.SetTask($Task)
`$MediaStack.Setup()
        
"@
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command)) # Convert to bas64 so strings do not get corrupted
        $this._Logger.WriteLog($env:INFO,"Setting RunOnce Key for User: $env:username")
        Set-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' `
            -Name "ContinueMediaStackSetup" `
            -value "$env:SystemRoot\system32\WindowsPowershell\v1.0\powershell.exe\system32\WindowsPowershell\v1.0\powershell.exe -ExecutionPolicy Bypass -encodedCommand $encoded -WindowStyle Normal" `
            -ErrorAction Stop
        
        $this._Logger.WriteLog($env:INFO,"Success Setting RunOnce Key for User: $env:username")

    }
    catch{
        $this._Logger.WriteLog($env:ERROR,"Error Setting RunOnce Key for User: $env:username")
        $this._Logger.WriteLog($env:ERROR,$_.Exception.Message)
        Throw "Error Setting RunOnce Key for User: $env:username"
    }
}

####----------####


}