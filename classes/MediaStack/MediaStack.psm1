##
# -- Import Wrappers -- #

##
using module "..\Logger\Logger.psm1"
using module "..\Logger\LogType\LogType.psm1"
using module "..\DownloadManager\DownloadManager.psm1"
using module "..\DownloadManager\DownloadConfig\DownloadConfig.psm1"


$env:WARN = [LogType]::WARN
$env:ERROR = [LogType]::ERROR
$env:INFO = [LogType]::INFO

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
    hidden [int]$_Stage = 0
    hidden [Logger]$_Logger = [Logger]::new($true, $true)
    hidden [System.Collections.ArrayList]$_toInstall = @()

    MediaStack([string]$SystemConfig, [string]$UserConfig){
        $this._FormatConsole()
        $this.Paths.config.system = $SystemConfig
        $this.Paths.config.user = $UserConfig
    }

    # [void] TEST(){
    #     $this._FormatConsole()
    #     $this._LoadSystemConfig()
    #     $this._CheckDependencies()
    # }

    # hidden 
    [bool]_isInstalled([string]$name){
        try{
            $app_key = Get-ItemPropertyValue (Get-ChildItem "HKLM:\\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | ?{$_.name -like "*$name*"}).Name.replace("HEKY_LOCAL_MACHINE",'HKLM:\') -Name DisplayName
            if(!$app_key.contains($name)){ return $false }
            else{ return $true }
        }
        catch {
            return $false
        }

    }

    hidden [void]_FormatConsole(){
        $psHost = Get-Host
        $Window = $psHost.UI.RawUI

        $bufferSize = $Window.BufferSize
        $bufferSize.Height = 3000
        $bufferSize.Width = 200
        $Window.BufferSize = $bufferSize

        $windowSize = $Window.WindowSize
        $windowSize.Height = 50
        $windowSize.Width = 175
        $Window.WindowSize = $windowSize
    }

    # hidden 
    [void]_GetMediaStackDependencies(){
        $this._Logger.WriteLog($env:INFO, "Checking for MediaStack Depedencies")
        $this.Config.system.'PRE-REQ'.forEach({
            $NAME = $_.name
            if($NAME -eq "dotNet"){ # dotNet
                $val = $(Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Net Framwork Setup\NDP\v4\Full' -ErrorAction SilentlyContinue)
                if($val){
                    if(!$val.GetValue('release') -gt $_.check){
                        $this._Logger.WriteLog($env:WARN, "App $($NAME) not installed")
                        $this._toInstall.Add($_) | Out-Null
                        ($this.Config.system.'DEPENDENCIES' | ?{$_.name -eq $NAME}).path = "$env:APP_TEMP/$NAME-$($_.version).$($_.type)" 
                    }
                }
            }           
        })

        $this._DownloadReady() # Download Dependencies
    }

    [void]_GetMediaStackApps(){
        $this._Logger.WriteLog($env:INFO, "Checking for MediaStack Apps")
        $this.Config.system.APPS.forEach({
            $NAME = $_.name
            if(!($this._isInstalled($NAME))){
                $this._Logger.WriteLog($env:WARN, "App $NAME not installed")
                $this._toInstall.Add($_) | Out-Null
                ($this.Config.system.'APPS' | ?{$_.name -eq $NAME}).path = "$env:APP_TEMP/$NAME-$($_.version).$($_.type)" 

            }
        })

        $this._DownloadReady() # Download Required Files
    }


    # hidden 
    [void]_DownloadReady(){

        $this._Logger.WriteLog($env:INFO,"Collection Download Details")

        [System.Collections.ArrayList]$Apps = $this._toInstall.forEach({
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

        $this._toInstall = [System.Collections.ArrayList]@()
    }

    # hidden 
    [bool]_LoadSystemConfig(){
        if(!$this._LoadConfig("system")){ return $false}
        return $true
    }

    # hidden 
    [bool]_LoadUserConfig(){
        if(!$this._LoadConfig("user")){ return $false}
        return $true
    }

    # hidden 
    [bool]_LoadConfig([string]$Name){
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

    [bool]_CreateAppConfig([string]$PATH, $config){
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
}