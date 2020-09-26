param(
    [Parameter(Position=0)]
    [int]$Stage = 0
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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

$APP_INSTALLATION = @(
    {
        name = "dotNet"
        type = "exe"
        version = "4.7.2"
        restart = $true
        args = "/q /norestart"
        expression = "Get-DotNetDownloadLink -Version (Get-Variable -name APPLICATION).version -Result (Get-Variable -name URL)"
    }
    {
        name = "dotNet"
        type = "exe"
        version = ""
        restart = $false
        args = ""
        extra = $false
    }
)



for($x = $Stage; $x -lt $APP_INSTALLATION.length; $x++){
    $APPLICATION = $APP_INSTALLATION[$x]

    if($APPLICATION.expression){
        $URL = ""
        Invoke-Expression $APPLICATION.expression
        $APP = 0
        Install-App -Path "$APP_DIR\$($APPLICATION.name)" -Result $APP
    }
}

switch($Stage){
    0 { #Install Pre-Req Stage
        $Result = 0
        Set-AutoLogin -User $env:DEFAULT_USER -Password $env:DEFAULT_PASSWORD -Result ([ref]$Result)
        if( $Result -ne 200){ Exit 500 } # Create the User AutoLogin

        if($(Confirm-DotNetVersion -Version $DOT_NET_VERSION)){ # Check if Min .NET version is installed
            # Install .NET
            # Get the .NET Download Link
            $DNR_Link = 0
            Get-DotNetDownloadLink -Version $DOT_NET_VERSION -Result $DNR_Link
            if($DNR_Link -eq 500){ Exit 500 }

            # Download / Install .NET Version
            $DNR = 0
            Install-App -Download_Url $DNR_Link -Result ([ref]$DNR)
            #Install-DotNet -Version $DOT_NET_VERSION -Result ([ref]$Result)
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
