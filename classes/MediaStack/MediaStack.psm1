using module "..\Logger\Logger.psm1"
using module "..\Logger\LogType\LogType.psm1"
using module "..\DownloadManager\DownloadManager.psm1"
using module "..\DownloadManager\DownloadConfig\DownloadConfig.psm1"
using module "..\Utilities\Utilities.psm1"


$env:WARN = [LogType]::WARN
$env:ERROR = [LogType]::ERROR
$env:INFO = [LogType]::INFO

enum Stage {
    LOAD
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
    hidden [int]$_Task = 0
    hidden [Stage]$_Stage = [Stage]::LOAD
    hidden [Logger]$_Logger = [Logger]::new($true, $true)
    hidden [System.Collections.ArrayList]$_toDownload = @()

    MediaStack([string]$SystemConfig, [string]$UserConfig){
        #$this._FormatConsole()
        $this.Paths.config.system = $SystemConfig
        $this.Paths.config.user = $UserConfig
    }

    [void]SetTask([int]$task){ $this._Task = $task }
    [void]SetStage([Stage]$stage){ $this._Stage = $stage }
    
    [void]Setup(){
        while($this._Stage -ne [Stage]::COMPLETED){
            switch($this._Stage){

                [Stage]::LOAD {
                    $this._Logger.WriteLog($env:INFO, "Entering Stage LOAD")
                    # Run $this._Load()
                    # Gets Configs, Creates User (if Needed)
                    $this._Load()
                    # Restarts as User
                    # Stage increases
                    break # incase restart fails - this task will repeat
                }
    
                [Stage]::DEP_DOWNLOAD {
                    $this._Logger.WriteLog($env:INFO, "Entering Stage DEP_DOWNLOAD")
                    # Continue setup - Downloads
                    # $this._GetMediaStackDepedencies()
                    # downloads .NET (other dep - none atm)
                    $this._GetMediaStackDependencies()
                    $this.SetStage([Stage]::DEP_INSTALL)
                    break # Move to Next Stage
                }

                [Stage]::DEP_INSTALL {
                    $this._Logger.WriteLog($env:INFO, "Entering Stage DEP_INSTALL")
                    # Continue setup - Install
                    # $this._InstallMediaStackDependencies()
                    # installs .Net - requires restart
                    $this._InstallMediaStackDependencies()
                    $this.SetStage([Stage]::APP_DOWNLOAD)
                    break # Move to Next Stage
                }

                [Stage]::APP_DOWNLOAD {
                    $this._Logger.WriteLog($env:INFO, "Entering Stage APP_DOWNLOAD")
                    # Continue setup -  Downloads
                    # $this._GetMediaStackApps()
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
                    $this._InstallMediaStackApps()
                    $this.SetStage([Stage]::COMPLETED)
                    break # End For now
                }
            }
        }
    }
#### CONFIGURATION ####

    hidden [bool]_LoadConfig([string]$Name){
        try{
            $this._Logger.WriteLog($env:INFO,"Getting $Name config from: $($this.Paths.config.$Name)")
            $_config = ConvertFrom-Json -InputObject $(Get-Content -Path $this.Paths.config.$Name -Raw -ErrorAction Stop) -ErrorAction Stop
            $this.Config.$Name = $_config
        }
        catch {
            $this._Logger.WriteLog($env:ERROR,"Error Getting $Name config from: $($this.Paths.config.$Name)")
            $this._Logger.WriteLog($env:ERROR,"$($_.Exception.Message)")
            return $false
        }
        return $true   
    }

    hidden [bool]_LoadSystemConfig(){
        if(!$this._LoadConfig("system")){ return $false}
        return $true
    }

    hidden [bool]_LoadUserConfig(){
        if(!$this._LoadConfig("user")){ return $false}
        return $true
    }

    hidden [void]Load(){
        
        if(!$this._LoadSystemConfig){ # Load System Config File
            $this._Logger.WriteLog($env:ERROR,"Unable to Load System Config File")
            Throw "Unable to Load System Config File"
        }
        if(!$this._LoadUserConfig){ # Load User Conig File
            $this._Logger.WriteLog($env:ERROR,"Unable to Load User Config File")
            Throw "Unable to Load User Config File"
        }

        if(!$this.Config.user.SETUP.DEFAULT_USER -or $this.Config.user.SETUP.DEFAULT_USER.trim() -eq ""){
            $this._Logger.WriteLog($env:WARN,"No DEFAULT_USER specified in the user-config.json")
            $this._Logger.WriteLog($env:INFO,"Attempting to create new user: MediaStack")
            
            try{ # Create Media Stack User
                $this.Config.user.SETUP.DEFAULT_USER = "MediaStack"
                $this.Config.user.SETUP.DEFAULT_PASSWORD = $this._Util.RandomPassword(16,$false)
                New-LocalUser `
                    -AccountNeverExpires `
                    -Description "User Created to Run for MediaStack" `
                    -Name "MediaStack"
                    -Password (ConvertTo-SecureString -String $this.Config.user.SETUP.DEFAULT_PASSWORD -AsPlainText -Force)
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

        if($env:username -ne $this.Config.user.SETUP.DEFAULT_USER){
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

####---------------####
#### DOWNLOADING ####

    <#hidden [void]_DownloadReady(){

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
        $this.Config.system.'PRE-REQ'.forEach({
            $NAME = $_.name
            if($NAME -eq "dotNet"){ # dotNet
                $val = $(Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Net Framwork Setup\NDP\v4\Full' -ErrorAction SilentlyContinue)
                if($val){
                    if(!$val.GetValue('release') -gt $_.check){
                        $this._Logger.WriteLog($env:WARN, "App $($NAME) not installed")

                        if(!(Test-Path "$env:APP_TEMP/$NAME-$($_.version).$($_.type)")){
                            $this._toDownload.Add($_) | Out-Null
                            ($this.Config.system.'DEPENDENCIES' | ?{$_.name -eq $NAME}).path = "$env:APP_TEMP/$NAME-$($_.version).$($_.type)"     
                        }
                    }
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
                ($this.Config.system.'APPS' | ?{$_.name -eq $NAME}).path = "$env:APP_TEMP/$NAME-$($_.version).$($_.type)" 
            }
        })

        $this._DownloadReady() # Download Required Files
    }#>

####-------------####
#### INSTALLATION ####

    <#hidden [void]_InstallApps([string]$Type){
        for($x=$this._Task; $x -lt $($this.Config.system.$Type.Count); $x++){
            try{
                $dep = $this.Config.system.$Type[$x]

                $this._Logger.WriteLog($env:INFO,"Installing App: $($_.name)")
                Start-Process $_.path `
                    -ArgumentList $_.args.split(' ') `
                    -Wait `
                    -ErrorAction Stop
    
                if($dep.restart){
                    # Set RunOnce - Should restart to this task, on the next app
                    $Stage = $null
                    switch($Type){
                        "DEPENDENCIES" { $Stage = [Stage]::DEP_INSTALL }
                        "APPS" { $Stage = [Stage]::APP_INSTALL }
                    }
                    $this._SetRunOnce($Stage ,$x++)
    
                    Restart-Computer -ErrorAction Stop
                }
            }
            catch{
                $this._Logger.WriteLog($env:ERROR,"Unable To install Application $($_.name)")
                $this._Logger.WriteLog($env:ERROR,$_.Exception.Message)
                Throw "Unable To install Application $($_.name)"
            }
        }
        $this._Task = 0
    }

    hidden [void]_InstallMediaStackDependencies(){
        Try{
            $this._InstallApps("DEPENDENCIES")
        }
        catch{
            Throw $_.Exception.Message
        }
    }

    hidden [void]_InstallMediaStackApps(){
        Try{
            $this._InstallApps("APPS")
        }
        catch{
            Throw $_.Exception.Message
        }
    }#>

####--------------####
#### UTILTIES ####

hidden [void]_SetAutoLogin(){
    try{
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

hidden [void]_SetRunOnce([Stage]$Stage,[int]$Task){
    try{
        $command = @"
using module "$PSScriptRoot\classes\MediaStack\MediaStack.psm1"
        
`$MediaStack = [MediaStack]::new("$($this.Paths.config.user)","$($this.Paths.config.system)")
`$MediaStack.SetStage($Stage)
`$MediaStack.SetTask($Task)
`$MediaStack.Setup()
        
"@
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
        $this._SetRunOnce($encoded)
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

    try{
        $this._Logger.WriteLog($env:INFO,"Backing Up Configuration for reboot")
        (ConvertTo-Json $this.Config.system -ErrorAction Stop) | Out-File $this.Paths.config.system -ErrorAction Stop
    }
    catch{
        $this._Logger.WriteLog($env:ERROR,"Unable to create backup, setup cannot continue")
        $this._Logger.WriteLog($env:INFO,$_.Exception.Message)
        Throw "Unable to create backup, setup cannot continue"
    }
}

####----------####


}