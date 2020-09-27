class DownloadConfig {
    [string]$_Url
    [string]$_Path

    DownloadConfig([string]$Url,[string]$Path){
        $this._Url = $Url
        $this._Path = $Path
    }
}

class DownloadJob {
    static [int]percent($Job){ return [Math]::Round( ($Job.BytesTransferred / $Job.BytesTotal) * 100 ) }
    static [int]total($Job){ return $Job.BytesTotal }
    static [int]current($Job){ return $Job.BytesTransferred }
}

class DownloadManager {
    [DownloadConfig[]]$_Configs
    #[]$CurrentJobs

    MultiFileDownloader([DownloadConfig[]]$Configs){
        $this._Configs = $Configs
    }

    static [int]DownloadFiles([DownloadConfig[]]$Configs){

        $Job = Start-BitsTransfer -Source 

        return 200
    }

    [int]DownloadFiles(){ 
        if($this.DownloadFiles($this._Configs) -ne 200){ return 500 }
        return 200
    }

    static [void]DownloadFile([DownloadConfig]$Config){}

    private [void]getJobPercent(){}
}


class BaseWrapper {


    BaseWrapper(){}


}