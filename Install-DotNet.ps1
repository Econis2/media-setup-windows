function New-TempDirectory($Path){

    $Path += "\temp"
    try{ # Check for Temp Directory
        Get-Item -Path $Path -ErrorAction Stop
    }
    catch {
        try { # Crete Temp Directory
            write-host "Creating Save Location" -ForegroundColor Green
            $result = $(New-Item -Path $Path -ErrorAction Stop).FullName
        }
        catch {
            write-host "Unable to write to Save Location: $Path"
        }
    }

    return $Path
}

param(
    [Parameter(Mandatory=$true,Position=0)]
    [ValidateSet("4.7.2")]
    [string]$Version
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$TEMP = $(New-TempDirectory($env:APPDATA)).FullName
$APP_NAME = "dotNET-$($Version.replace('.','_'))"
$APP_TEMP = "$TEMP\$APP_NAME.exe"

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
        write-host "Unable to Get Download Link" -ForegroundColor Red
        write-host $_.Exception.Message -ForegroundColor Red
        Exit 500
    }
}

try{ # Download .Net
    $link = Get-DotNetDownloadLink($versions[$Version].init_url)

    Write-Host "Downloading .NET Version: $Version" -ForegroundColor Green

    Invoke-WebRequest -Uri $Link -OutFile $APP_TEMP -ErrorAction Stop
}
catch {
    write-host "Unable to Download Dot Net Installer" -ForegroundColor Red
    write-host $_.Exception.Message -ForegroundColor Red
    Exit 500
}

try{ # Install .Net
    Write-Host "Installing .NET Version: $Version" -ForegroundColor Green
    Write-Host "This can take up to 15 minutes....." -ForegroundColor Green
    $installer = Start-Process -FilePath $APP_TEMP -ArgumentList "/q /norestart" -PassThru
}
catch {
    write-host "Unable to Install .NET Version: $Version" -ForegroundColor Red
    write-host $_.Exception.Message -ForegroundColor Red
    Exit 500
}

$timer = [System.Diagnostics.Stopwatch]::new()
$timer.Start()
$x = 0
while(!$installer.HasExited){

    $Arrow = "=>"
    Write-Host "H$($timer.Elapsed.Hours):M$($timer.Elapsed.Minutes):S$($timer.Elapsed.Seconds)" -ForegroundColor Yellow
    # Moving Arrow
    if($x -lt 10){
        $Arrow = "=" + $Arrow
        $x++
    }
    else{
        $Arrow = "=>"
        $x = 0
    }
    Write-Host $Arrow -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    clear
}

$timer.Stop()

Write-Host "Installation completed in H$($timer.Elapsed.Hours):M$($timer.Elapsed.Minutes):S$($timer.Elapsed.Seconds)" -ForegroundColor Green