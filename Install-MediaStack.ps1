param(
    [Parameter(Position=0)]
    [int]$Stage = 0,

    [Parameter(ParameterSetName="config")]
    [string]$InputConfig
    
)


# Import the Installer Function
. .\Utilities.ps1
. .\DotNet-Utilities.ps1
# Will Be YAML File Settings

#Optional
[string]$DEFAULT_USER = "Administrator"
[string]$DEFAULT_PASSWORD = "Test1234" # Might Auto Generate this?
[string]$TEMP_PATH = "$env:APPDATA\MediaStack"
[string]$CONFIG_PATH = "$env:APPDATA\MediaStack\config.json"
[string]$env:LOG_PATH = "$env:APPDATA\MediaStack\install-log"

# Load Config
if($InputConfig){
    $CONFIG = ConvertFrom-Json $(Get-Content -Path $InputConfig -Raw) -AsHashtable

}

# Sonarr requires .NET 4.7.2 min
$dotNetVersion = '4.7.2'

switch($Stage){
    0 { #Install Pre-Req Stage
        Set-Log -Message "Set Automatic Login" -LogType 'I' -LogPath "$TEMP_PATH\log" -LogConsole

        Set-AutoLogon -User $DEFAULT_USER -Password $DEFAULT_PASSWORD

        Set-Log -Message "Checking for .NET v:$dotNetVersion or greater" -LogType 'I' -LogPath "$TEMP_PATH\log" -LogConsole

        if(!Confirm-DotNetVersion -Version $dotNetVersion){ # Check if Min .Net version is installed
            
            Set-Log -Message "Installing .NET $dotNetVersion" -LogType 'W' -LogPath "$TEMP_PATH\log" -LogConsole
            
            Install-DotNet -Version $dotNetVersion # Install .NET 4.7.2
        
            # Write Run Once Key
            New-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
        
        }
    }

    1 { # Install Sonarr

    }
}


$Sonarr_Arguments = "/Silent /VERYSILENT /NORESTART /SP-"