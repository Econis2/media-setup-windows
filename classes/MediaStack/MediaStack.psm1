using module "..\Logger\Logger.psm1"
using module "..\Logger\LogType\LogType.psm1"
using module "..\DownloadManager\DownloadManager.psm1"
using module "..\DownloadManager\DownloadConfig\DownloadConfig.psm1"

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
    hidden [Logger]$_Logger = [Logger]::new($true, $true)
    hidden [System.Collections.ArrayList]$_toInstall = @()

    MediaStack([string]$SystemConfig, [string]$UserConfig){
        $this._FormatConsole()
        $this.Paths.config.system = $SystemConfig
        $this.Paths.config.user = $UserConfig
    }

    hidden [bool]_isInstalled([string]$name){
        $app_key = Get-ChildItem "HKLM:\\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | ?{$_.name -like "*$name*"}
        if(!$app_key){ return $false }
        else{ return $true }
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

    hidden [void]_CheckDependencies(){
        $this._Logger.WriteLog([LogType]::INFO, "Checking for required installed apps")
        $this.Config.system.APPS.forEach({
            if(!($this._isInstalled($_.name))){
                $this._Logger.WriteLog([LogType]::WARN, "App $($_.name) not installed")
                $this._toInstall.Add($_) | Out-Null
            }
        })
    }

    hidden [void]_DownloadDependencies(){

        $this._Logger.WriteLog([LogType]::INFO,"Collection Application Dependency details")
        [System.Collections.ArrayList]$Apps = $this._toInstall.forEach({
            $this._Logger.WriteLog([LogType]::INFO,"Getting config for app: $full_name")
            $full_name = "$($_.name)-$($_.version).$($_.type)"
            $url = "$($this.Config.system.'BASE_URL')/$($this.Config.system.'RELEASE')/$full_name"
            $path = "$env:APP_TEMP\$full_name"
            return [DownloadConfig]::new($url, $path)
        })
        $this._Logger.WriteLog([LogType]::INFO,"Downloading Dependency Applications")
        while($Apps.Count -ne 0){
            [DownloadManager]::new($this._Logger).DownloadFiles($Apps)

            $this._Logger.WriteLog([LogType]::INFO,"Verifying Apps have successfully downloaded")
            for($x=0; $x -lt $Apps.Count; $x++){
                $this._Logger.WriteLog([LogType]::INFO,"Checking $($Apps[$x].Path)")
                if(Test-Path $Apps[$x].Path){
                    $this._Logger.WriteLog([LogType]::INFO,"App Found")
                    $Apps.RemoveAt($x)
                    $x = $x -1
                }
            }
        }
    }

    hidden [bool]_LoadSystemConfig(){
        if(!$this._LoadConfig("system")){ return $false}
        return $true
    }

    hidden [bool]_LoadUserConfig(){
        if(!$this._LoadConfig("user")){ return $false}
        return $true
    }

    hidden [bool]_LoadConfig([string]$Name){
        try{
            $this._Logger.WriteLog([LogType]::INFO,"Getting $Name config from: $($this.Paths.config.$Name)")
            $_config = ConvertFrom-Json -InputObject $(Get-Content -Path $this.Paths.config.$Name -Raw -ErrorAction Stop) -ErrorAction Stop
            $this.Config.$Name = $_config
        }
        catch {
            $this._Logger.WriteLog([LogType]::ERROR,"Error Getting $Name config from: $($this.Paths.config.$Name)")
            $this._Logger.WriteLog([LogType]::ERROR,"$($_.Exception.Message)")
            return $false
        }
        return $true   
    }
}