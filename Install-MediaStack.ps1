param(
    [Parameter(Position=0)]
    [int]$Stage = 0
)

# Import the Installer Function
. .\Utilities.ps1
. .\DotNet-Utilities.ps1
# Will Be YAML File Settings


# Sonarr requires .NET 4.7.2 min
$DOT_NET_VERSION = '4.7.2'
$SONARR_URL = ""

switch($Stage){
    0 { #Install Pre-Req Stage
        
        if( Set-AutoLogon -User $DEFAULT_USER -Password $DEFAULT_PASSWORD -ne 200){ Exit 500 } # Create the User AutoLogin
            
        if(!Confirm-DotNetVersion -Version $DOT_NET_VERSION){ # Check if Min .NET version is installed
            # Install .NET
            if( Install-DotNet -Version $DOT_NET_VERSION -ne 200 ){ Exit 500 }
            # Set Script to Run on Start
            if( Set-RunOnce -Stage 1 -ne 200) { Exit 500 }
        }
        Set-Log -I -Message "Restarting Computer" -LogConsole
        Restart-Computer 
    }

    1 { # Install Sonarr
        Install-App -Download_Url $SONARR_URL -Installer_Type "exe" -Arguments "/Silent /VERYSILENT /NORESTART /SP-"
    }
}
