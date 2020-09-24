
function New-TempDirectory([string]$Path){
    $Path += "\temp"
    try{ # Check for Temp Directory
        Get-Item -Path $Path -ErrorAction Stop
    }
    catch {
        try { # Crete Temp Directory
            write-host "Creating Save Location"
            New-Item -Path $Path -ErrorAction Stop
        }
        catch {
            write-host "Unable to write to Save Location: $Path" -ForegroundColor Red
            write-host "$($_.Exception.Message)" -ForegroundColor Red
            Exit 500
        }
    }

    return $Path
}

function Install-App{
    param(
        [CmdletBinding(DefaultParameterSetName="Local")]
        [Parameter(Mandatory=$true,Position=0,ParameterSetName="Local")]
        [string]$File_Path,

        [Parameter(Mandatory=$true,Position=0,ParameterSetName="Web")]
        [string]$Download_Url,

        [Parameter(Position=1)]
        [ValidateSet("exe","msi","zip/exe","zip/msi")]
        [string]$Installer_Type = "exe",

        [Parameter(Position=2)]
        [string]$Arguments

    )

    [string]$TEMP = New-TempDirectory($env:APPDATA)
    [string]$APP_ID = $(New-Guid).Guid
    [string]$APP_TEMP = "$TEMP\$APP_ID."

    switch($Installer_Type){ # Set the Temp File path based on installer type
        ($Installer_Type.Contains("zip/")){
            $APP_TEMP += $Installer_Type.remove("zip/")
        }
        default {
            $APP_TEMP += $Installer_Type
        }
    }

    switch($PSCmdlet.ParameterSetName){
        "Web" {
            try { # Download EXE and set File Path
                Invoke-WebRequest $Download_Path -OutFile $APP_TEMP -ErrorAction Stop
            }
            catch {
                write-host "Unable to Download requested File from:[$Download_Path] to:[$APP_TEMP]" -ForegroundColor Red
                write-host "$($_.Exception.Message)" -ForegroundColor Red
                Exit 500
            }
        }

        default{
            write-host "Default: "
        }
    }

    # Set the UAC to Allow Install of this File
    $regPath = "HKCU:\Software\Classes\ms-settings\shell\open\command"

    New-Item $regPath -Force
    New-ItemProperty $regPath -Name "DelegateExecute" -Value $null -Force
    New-ItemProperty $regPath -Name "(default)" -Value $APP_TEMP -Force

    # Install File
    try{
        $proc = Start-Process -FilePath $APP_TEMP -ArgumentList $Arguments -PassThru
    }
    catch {
        Remove-Item $regPath -Force -Recurse
        Exit 500
    }

    $timer = [System.Diagnostics.Stopwatch]::new()
    $timer.Start()
    $x = 0
    $Status = "Installing"
    while(!$proc.HasExited){

        Write-Progress -PercentComplete $x -Activity $Status -Status "[Hours]$($timer.Elapsed.Hours) [Minutes]$($timer.Elapsed.Minutes) [Seconds]$($timer.Elapsed.Seconds)"

        if($x -lt 100){
            $x = $x + 5
        }
        else{
            $x = 0
        }

        Start-Sleep -Seconds 1

    }

    $timer.Stop()

    Write-Host "Installation completed in [Hours]$($timer.Elapsed.Hours) [Minutes]$($timer.Elapsed.Minutes) [Seconds]$($timer.Elapsed.Seconds)" -ForegroundColor Green

    Remove-Item $regPath -Force -Recurse
}