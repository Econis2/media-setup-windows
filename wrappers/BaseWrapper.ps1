using module "..\classes\DownloadManager\DownloadManager.psm1"
using module "..\classes\DownloadManager\DownloadConfig\DownloadConfig.psm1"
using module "..\classes\Logger\Logger.psm1"

class BaseWrapper {

    BaseWrapper(){}

    [bool]isInstalled(){
        Write-Host "This is a Generic Class, and This Does Nothing"
        return $false
    }

    [bool]Download(){
        Write-Host "This is a Generic Class, and This Does Nothing"
        return $false
    }

    [bool]Install(){
        Write-Host "This is a Generic Class, and This Does Nothing"
        return $false
    }
}