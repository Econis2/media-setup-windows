# Import the Installer Function
. .\Utilities.ps1
. .\DotNet-Utilities.ps1
# Will Be YAML File Settings

#Optional
[string]$TEMP_PATH = "$env:APPDATA\temp"

# Sonarr requires .NET 4.7.2 min
$dotNetVersion = '4.7.2'
# Check for version
Set-Log -Message "Checking for .NET v:$dotNetVersion or greater" -LogType 'I' -LogPath "$TEMP_PATH\log" -LogConsole

if(!Compare-DotNetVersion -Version $dotNetVersion){
    
    Set-Log -Message "Installing .NET $dotNetVersion" -LogType 'W' -LogPath "$TEMP_PATH\log" -LogConsole
    Install-DotNet -Version $dotNetVersion
}

$Sonarr_Arguments = "/Silent /VERYSILENT /NORESTART /SP-"