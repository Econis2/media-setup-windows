class DownloadConfig {
    [string]$Url
    [string]$Path

    DownloadConfig([string]$_url,[string]$_path){
        $this.Url = $_url
        $this.Path = $_path
    }
}