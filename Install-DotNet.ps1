
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
            Write-Error "Unable to write to Save Location: $Path"
            Write-Error "$($_.Exception.Message)"
        }
    }

    return $Path
}


param(
    [Parameter(Mandatory=$true,Position=0)]
    [ValidateSet("4.7.2")]
    [string]$Version
)

$TEMP = New-TempDirectory($env:APPDATA)
$APP_TEMP = "$TEMP\$Version.exe"

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
        Write-Error "Unable to Get Download Link"
        Write-Error "$($_.Exception.Message)"
    }
}

try{ # Download .Net
    $link = Get-DotNetDownloadLink($versions[$Version].init_url)
    Invoke-WebRequest -Uri $Link -OutFile $APP_TEMP -Error -ErrorAction Stop
}
catch {
    Write-Error "Unable to Download Dot Net Installer"
}

# try{ # Install .Net

# }
# catch {

# }