
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
    [CmdletBinding(DefaultParameterSetName="Local")]
    [Parameter(Mandatory=$true,Postition=0,ParameterSetName="Local")]
    [string]$File_Path,

    [Parameter(Mandatory=$true,Postition=0,ParameterSetName="Web")]
    [string]$Download_Url,

    [Parameter(Mandatory=$true,Postition=1)]
    [ValidateSet("exe","msi","zip/exe","zip/msi")]
    [string]$Installer_Type = "exe"

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
            Write-Error "Unable to Download requested File from:[$Download_Path] to:[$APP_TEMP]"
            Write-Error "$($_.Exception.Message)"
        }
    }

    default{
        write-host "Default: "
    }
}

# Install File
try{
    Start-Process -FilePath $APP_TEMP
}