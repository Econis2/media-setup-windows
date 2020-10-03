using module "..\classes\DownloadManager\DownloadManager.psm1"
using module "..\classes\DownloadManager\DownloadConfig\DownloadConfig.psm1"
using module "..\classes\Logger\Logger.psm1"

class BaseWrapper {

    BaseWrapper(){}

    [void]Download(){
        [DownloadManager]::new().DownloadFile()
    }

    [void]Install(){}
}