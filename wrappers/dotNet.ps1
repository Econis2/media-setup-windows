using module ".\BaseWrapper.psm1"
using module "..\classes\Logger\Logger.psm1"
using module "..\classes\Logger\LogType\LogType.psm1"
using module "..\classes\DownloadManager\DownloadManager.psm1"
using module "..\classes\DownloadManager\DownloadType\DownloadType.psm1"

class DotNetWrapper : BaseWrapper {
    hidden [Logger]$_Logger
    hidden [string]$_version
    hidden $_versionChart = @{
        '4.7.2' = @{
            path = 'HKLM:\SOFTWARE\Microsoft\Net Framwork Setup\NDP\v4\Full'
            check = 41808
            init_url = "https://dotnet.microsoft.com/download/dotnet-framework/thank-you/net472-offline-installer"
        }
        
    }


    DotNetWrapper([string]$Version){
        $this._version = $Version
        $this._Logger = [Logger]::new($true,$true)
    }

    DotNetWrapper([string]$Version, [Logger]$Logger){
        $this._version = $Version
        $this._Logger = $Logger
    }

    [bool]isInstalled(){
        $checkVersion = $this._versionChart.$($this._version)

        try{
            $this._Logger.WriteLog([LogType]::INFO, "Checking .NET Version $($this._version)")
            return (Get-ChildItem -Path $checkVersion.path -ErrorAction Stop).GetValue('release') -gt $checkVersion.check
        }
        catch{
            $this._Logger.WriteLog([LogType]::ERROR, ".NET Version $($this._version) not found")
            return $false
        }
    }

    [bool]Download(){

    }

    hidden [string]_getDownloadLink([string]$url){
        try{
            return ($( Invoke-WebRequest -Uri $url -ErrorAction Stop ).Links | ?{ $_.outerHTML -like "*click here to download manually*"}).href
        }
        catch {
            $this._Logger.WriteLog([LogType]::ERROR,"Unable to Get Download Link")
            $this._Logger.WriteLog([LogType]::ERROR,"$($_.Exception.Message)")
            return "none"
        }
    }
}
