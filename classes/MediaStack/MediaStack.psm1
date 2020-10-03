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

    MediaStack([string]$SystemConfig, [string]$UserConfig){
        $this.Paths.config.system = $SystemConfig
        $this.Paths.config.user = $UserConfig
    }

    [void]_DownloadDependencies(){
        $this._Logger.WriteLog([LogType]::INFO,"Collection Application Dependency details")
        [System.Collections.ArrayList]$Apps = $this.Config.system.APPS.forEach({
            $full_name = "$($_.name)-$($_.version).$($_.type)"
            $url = "$($this.Config.system.'BASE_URL')/$($this.Config.system.'RELEASE')/$full_name"
            $path = "$env:APP_TEMP\$full_name"
            return [DownloadConfig]::new($url, $path)
        })
        $this._Logger.WriteLog([LogType]::INFO,"Downloading Dependency Applications")

        while($Apps.Count -ne 0){
            [DownloadManager]::new().DownloadFiles($Apps)
            $this._Logger.WriteLog([LogType]::INFO,"Verifying Apps have successfully downloaded")
            for($x=0; $x -lt $Apps.Count; $x++){
                if(Test-Path $Apps[$x].Path){ 
                    $this._Logger.WriteLog([LogType]::INFO,"Checking $($Apps[$x].Path)")
                    $Apps.RemoveAt($x) | Out-Null
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
            $this._Logger.WriteLog([LogType]::INFO,"Getting $Name config from: $($this.Paths.config[$Name])")
            $_config = ConvertFrom-Json -InputObject $(Get-Content -Path $this.Paths.config[$Name] -Raw -ErrorAction Stop) -ErrorAction Stop
            $this.Config = $_config
        }
        catch {
            $this._Logger.WriteLog([LogType]::ERROR,"Error Getting $Name config from: $($this.Paths.config[$Name])")
            $this._Logger.WriteLog([LogType]::ERROR,"$($_.Exception.Message)")
            return $false
        }
        return $true   
    }
}