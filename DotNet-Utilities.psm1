# Source Utilties

Import-Module ".\Utilities.psm1"
function Install-DotNet{
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateSet("4.7.2")]
        [string]$Version,

        [Parameter(Mandatory=$true)]
        [ref]$Result
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $APP_NAME = "dotNET-$($Version.replace('.','_'))"
    if(!$env:TEMP_PATH){
        $TEMP = $(New-TempDirectory($env:APPDATA)).FullName
        $APP_TEMP = "$TEMP\$APP_NAME.exe"
    }
    else{ $APP_TEMP = "$env:TEMP_PATH\$APP_NAME.exe"}


    $Versions = @{
        "4.7.2" = @{
            init_url = "https://dotnet.microsoft.com/download/dotnet-framework/thank-you/net472-offline-installer"
        }
    }

    function Get-DotNetDownloadLink($init_url){
        try{
            return ($( Invoke-WebRequest -Uri $init_url -ErrorAction Stop ).Links | ?{ $_.outerHTML -like "*click here to download manually*"}).href
        }
        catch {
            Set-Log -LogType E -Message "Unable to Get Download Link" -LogConsole
            Set-Log -LogType E -Message $_.Exception.Message -LogConsole
            return 500
        }
    }

    Set-Log -Message "Installing .NET $Version" -LogType 'I' -LogConsole

    try{ # Download .Net
        
        # Set the UAC to Allow Install of this File
        $regPath = "HKCU:\Software\Classes\ms-settings\shell\open\command"
        New-Item $regPath -Force | out-null
        New-ItemProperty $regPath -Name "DelegateExecute" -Value $null -Force | out-null
        New-ItemProperty $regPath -Name "(default)" -Value $APP_TEMP -Force | out-null

        $link = Get-DotNetDownloadLink($versions[$Version].init_url)

        if($link -ne 500){
            Set-Log -LogType I -Message "Downloading .NET Version: $Version" -LogConsole
            # Invoke-WebRequest -Uri $Link -OutFile $APP_TEMP -ErrorAction Stop
            [System.Net.WebClient]::new().DownloadFile($Link,$APP_TEMP)

        }
    }
    catch {
        Set-Log -LogType E -Message "Unable to Download Dot Net Installer" -LogConsole
        Set-Log -LogType E -Message $_.Exception.Message -LogConsole
        $Result.Value = 500
        return
    }

    try{ # Install .Net
        Set-Log -LogType I -Message "Installing .NET Version: $Version" -LogConsole
        Set-Log -LogType W -Message "Installation can take up to 10 minutes" -LogConsole

        $proc = Start-Process -FilePath $APP_TEMP -ArgumentList "/q /norestart" -PassThru
    }
    catch {
        Set-Log -LogType E -Message "Unable to Install .NET Version: $Version" -LogConsole
        Set-Log -LogType E -Message $_.Exception.Message -LogConsole
        $Result.Value = 500
        return
    }

    $timer = [System.Diagnostics.Stopwatch]::new()
    $timer.Start()
    $x = 0
    $Status = "Installing..."
    while(!$proc.HasExited){

        Write-Progress -PercentComplete $x -Status $Status -Activity "[Hours]$($timer.Elapsed.Hours) [Minutes]$($timer.Elapsed.Minutes) [Seconds]$($timer.Elapsed.Seconds)"

        if($x -lt 100){
            $x = $x++
        }
        else{
            $x = 0
        }

        Start-Sleep -Seconds 1

    }

    $timer.Stop()
    Set-Log -LogType 'I' -LogConsole -Message "Installation completed in [Hours]$($timer.Elapsed.Hours) [Minutes]$($timer.Elapsed.Minutes) [Seconds]$($timer.Elapsed.Seconds)" -ForegroundColor Green

    Remove-Item $regPath -Force -Recurse
    # Need to add a Run Once to Continue Script or move to next one
    # Prollay a running config file, that we can clean up later

    $Result.Value = 200
    return
}

function Confirm-DotNetVersion{
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateSet("4.7.2")]
        [string]$Version
    )

    $Versions = @{
        "4.7.2" = 41808
    }

    Set-Log -Message "Checking for .NET v:$Version or greater" -LogType 'I' -LogConsole

    $dotNET_path = 'HKLM:\SOFTWARE\Microsoft\Net Framwork Setup\NDP\v4\Full'
    
    $val = $(Get-ChildItem -Path $dotNET_path -ErrorAction SilentlyContinue)
    if($val){
        return $val.GetValue('release') -gt $Versions[$version]
    }
    
    return $false

}