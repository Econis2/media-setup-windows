function New-TempDirectory($Path){

    $Path += "\temp"
    try{ # Check for Temp Directory
        Get-Item -Path $Path -ErrorAction Stop
    }
    catch {
        try { # Crete Temp Directory
            write-host "Creating Save Location" -ForegroundColor Green
            $result = $(New-Item -Path $Path -ItemType Directory -ErrorAction Stop).FullName
        }
        catch {
            write-host "Unable to write to Save Location: $Path"
        }
    }

    return $Path
}

function Install-DotNet{
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
        # Set the UAC to Allow Install of this File
        $regPath = "HKCU:\Software\Classes\ms-settings\shell\open\command"
        New-Item $regPath -Force | out-null
        New-ItemProperty $regPath -Name "DelegateExecute" -Value $null -Force | out-null
        New-ItemProperty $regPath -Name "(default)" -Value $APP_TEMP -Force | out-null

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
        Write-Host "Installation can take up to 10 minutes" -ForegroundColor Green
        $proc = Start-Process -FilePath $APP_TEMP -ArgumentList "/q /norestart" -PassThru
    }
    catch {
        write-host "Unable to Install .NET Version: $Version" -ForegroundColor Red
        write-host $_.Exception.Message -ForegroundColor Red
        Exit 500
    }

    $timer = [System.Diagnostics.Stopwatch]::new()
    $timer.Start()
    $x = 0
    $Status = "Installing..."
    while(!$proc.HasExited){

        Write-Progress -PercentComplete $x -Status $Status -Activity "[Hours]$($timer.Elapsed.Hours) [Minutes]$($timer.Elapsed.Minutes) [Seconds]$($timer.Elapsed.Seconds)"

        if($x -lt 100){
            $x = $x++
            #$Status += "."
        }
        elseif($x -eq 20){
            #$Status = "Installing"
        }
        else{
            $x = 0
        }

        Start-Sleep -Seconds 1

    }

    $timer.Stop()

    Write-Host "Installation completed in [Hours]$($timer.Elapsed.Hours) [Minutes]$($timer.Elapsed.Minutes) [Seconds]$($timer.Elapsed.Seconds)" -ForegroundColor Green

    Remove-Item $regPath -Force -Recurse
    # Need to add a Run Once to Continue Script or move to next one
    # Prollay a running config file, that we can clean up later
}