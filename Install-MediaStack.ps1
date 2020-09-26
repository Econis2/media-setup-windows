param(
    [Parameter(Position=0)]
    [int]$Stage = 0
)

# Import the Installer Function
Import-Module ".\Utilities.psm1"
Import-Module ".\DotNet-Utilities.psm1"
# Will Be YAML File Settings
$Result = 0
Import-Config -Path ".\config.json" -Result ([ref]$Result)
if($Result -ne 200){ Exit 500 }

$Result = 0
Initialize-Setup -Result ([ref]$Result)
if( $Result -ne 200 ){ Exit 500 }

# Sonarr requires .NET 4.7.2 min
$DOT_NET_VERSION = '4.7.2'
$SONARR_URL = ""

switch($Stage){
    0 { #Install Pre-Req Stage
        $Result = 0
        Set-AutoLogin -User $env:DEFAULT_USER -Password $env:DEFAULT_PASSWORD -Result ([ref]$Result)
        if( $Result -ne 200){ Exit 500 } # Create the User AutoLogin

        if($(Confirm-DotNetVersion -Version $DOT_NET_VERSION)){ # Check if Min .NET version is installed
            # Install .NET
            $Result = 0
            Install-DotNet -Version $DOT_NET_VERSION -Result ([ref]$Result)
            if($Result -ne 200 ){ Exit 500 }
            
            # Set Script to Run on Start
            $Result = 0
            Set-RunOnce -Stage 1 -Result ([ref]$Result)
            if($Result -ne 200) { Exit 500 }
        }
        Set-Log -I -Message "Restarting Computer" -LogConsole
        #Restart-Computer 
    }

    1 { # Install Sonarr
        #Install-App -Download_Url $SONARR_URL -Installer_Type "exe" -Arguments "/Silent /VERYSILENT /NORESTART /SP-"
    }
}
