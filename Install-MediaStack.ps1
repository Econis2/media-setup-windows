using module "classes\MediaStack\MediaStack.psm1"

param(
    [int]$Stage = 0
)

# $env:APP_TEMP = "C:/Users/Administrator/Desktop/Apps"

# New-Item -Path $env:APP_TEMP -ItemType Directory -ErrorAction SilentlyContinue

$MS = [MediaStack]::new("configs/system-config.json","configs/user-config.json")
$MS.SetStage($Stage)
$MS.Setup()
# $MS._LoadSystemConfig()
# $MS._GetMediaStackDependencies() # Download Only
# $MS._GetMediaStackApps() # Download Only
# param(
#     [Parameter(Position=0)]
#     [int]$Stage = 0
# )

# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# # Import the Installer Function
# Import-Module ".\Utilities.psm1"
# Import-Module ".\DotNet-Utilities.psm1"

# # Will Be YAML File Settings
# $UCR = 0
# Import-UserConfig -Path ".\user-config.json" -Result ([ref]$UCR)
# if($UCR -ne 200){ Exit 500 }

# $MEDIA_CONFIG = "" 
# Import-MediaConfig -Path ".\media-config.json" -Result ([ref]$MEDIA_CONFIG)
# if($MEDIA_CONFIG -eq 500){ Exit 500 }

# $ISR = 0
# Initialize-Setup -Result ([ref]$ISR)
# if( $ISR -ne 200 ){ Exit 500 }

# [System.Collection.Arraylist]$PID_POOL = @()
# $PWSH_PATH = "$env:SystemRoot\system32\WindowsPowershell\v1.0\powershell.exe"
# $ROOT_URL = "https://github.com/Econis2/media-setup-windows/releases/download/$($MEDIA_CONFIG.RELEASE)/"

# #### Download All the required Apps ASYNC
# for($x = $Stage; $x -lt $MEDIA_CONFIG.APPS.length; $x++ ){
#     $app = $MEDIA_CONFIG.APPS[$x]
#     $APP_NAME = "$($app.name)-$($app.version).$($app.type)"
#     $APP_PATH = "$TEMP_PATH\$APP_NAME"
#     $Url = $ROOT_URL + $APP_NAME
#     $command = @"
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# [System.Net.WebClient]::new().DownloadFile('$Url', '$APP_PATH')
# "@
#     $EncodedCommand = [Convert]::ToBase64String( ([System.Text.Encoding]::Unicode.GetBytes($command)) )
#     $app_id = Start-Process -FilePath $PWSH_PATH -WindowStyle Hidden -PassThru -ArgumentList "-encodedCommand $EncodedCommand"

#     $PID_POOL.add(@{
#         proc = $app_id
#         done = $false
#     }) | Out-Null
# }


# $timer = [System.Diagnostics.Stopwatch]::new()
# $timer.Start()
# $x = 0

# $ALL_DONE = $false

# while(!$ALL_DONE){
#     $check_pool = $PID_POOL | ?{$_.done -eq $false}

#     $Status = "$($check_pool.length) of $($PID_POOL.length)"
#     Write-Progress -PercentComplete $x -Activity $Status -Status "[Hours]$($timer.Elapsed.Hours) [Minutes]$($timer.Elapsed.Minutes) [Seconds]$($timer.Elapsed.Seconds)"

#     if($x -lt 100){ $x = $x++ }
#     else{ $x = 0 }

#     Start-Sleep -Seconds 1

#     $check_pool = $PID_POOL | ?{$_.done -eq $false}
#     if($check_pool.length -gt 0){
#         $PID_POOL.forEach({
#             if($_.proc.HasExited){ $_.done = $true }
#         })
#     }
#     else{ $ALL_DONE = $true }

# }

# $timer.Stop()

# for($x = $Stage; $x -lt $MEDIA_CONFIG.APPS.length; $x++){
#     $APPLICATION = $MEDIA_CONFIG.APPS[$x]
#     $APP_PATH = "$APP_DIR\$($APPLICATION.name)"
#     $APP = 0
#     if($APPLICATION.expression){
#         $URL = ""
#         Invoke-Expression $APPLICATION.expression
#         Install-App -Path $APP_PATH -Result $APP
#     }
#     else{
#         Install-App -Path $APP_PATH -Result $APP
#     }
# }

# switch($Stage){
#     0 { #Install Pre-Req Stage
#         $Result = 0
#         Set-AutoLogin -User $env:DEFAULT_USER -Password $env:DEFAULT_PASSWORD -Result ([ref]$Result)
#         if( $Result -ne 200){ Exit 500 } # Create the User AutoLogin

#         if($(Confirm-DotNetVersion -Version $DOT_NET_VERSION)){ # Check if Min .NET version is installed
#             # Install .NET
#             # Get the .NET Download Link
#             $DNR_Link = 0
#             Get-DotNetDownloadLink -Version $DOT_NET_VERSION -Result $DNR_Link
#             if($DNR_Link -eq 500){ Exit 500 }

#             # Download / Install .NET Version
#             $DNR = 0
#             Install-App -Download_Url $DNR_Link -Result ([ref]$DNR)
#             #Install-DotNet -Version $DOT_NET_VERSION -Result ([ref]$Result)
#             if($Result -ne 200 ){ Exit 500 }
            
#             # Set Script to Run on Start
#             $Result = 0
#             Set-RunOnce -Stage 1 -Result ([ref]$Result)
#             if($Result -ne 200) { Exit 500 }
#         }
#         Set-Log -I -Message "Restarting Computer" -LogConsole
#         #Restart-Computer 
#     }

#     1 { # Install Sonarr
#         #Install-App -Download_Url $SONARR_URL -Installer_Type "exe" -Arguments "/Silent /VERYSILENT /NORESTART /SP-"
#     }
# }
