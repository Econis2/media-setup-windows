
function New-TempDirectory([string]$Path){
    $Path += "\temp"
    try{ # Check for Temp Directory
        Get-Item -Path $Path -ErrorAction Stop
    }
    catch {
        try { # Crete Temp Directory
            Set-Log -LogType I -Message "Creating Save Location" -LogConsole
            New-Item -Path $Path -ErrorAction Stop
        }
        catch {
            Set-Log -LogType I -Message "Unable to write to Save Location: $Path" -LogConsole
            return 500
        }
    }

    return $Path
}

function Install-App{
    param(
        [CmdletBinding(DefaultParameterSetName="Local")]
        [Parameter(Mandatory=$true,Position=0,ParameterSetName="Local")]
        [string]$Path,

        [Parameter(Mandatory=$true,Position=0,ParameterSetName="Web")]
        [string]$Url,

        [Parameter(Position=1)]
        [ValidateSet("exe","msi","zip/exe","zip/msi")]
        [string]$Installer_Type = "exe",

        [Parameter(Position=2)]
        [string]$Arguments,

        [Parameter(Position=3)]
        [string]$Temp_Path = "$env:APPDATA\temp",

        [Parameter(Mandatory=$true)]
        [ref]$Result

    )

    [string]$APP_ID = $(New-Guid).Guid

    if(!$env:TEMP_PATH){
        [string]$TEMP = $(New-TempDirectory($Temp_Path)).fullName
        [string]$APP_TEMP = "$TEMP\$APP_ID."
    }
    else{ $APP_TEMP = "$env:TEMP_PATH\$APP_ID."}

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
            #try { # Download EXE and set File Path
                Set-Log -LogType I -Message "Downloading Application" -LogConsole
                #Invoke-WebRequest $Download_Path -OutFile $APP_TEMP -ErrorAction Stop
                $DLR = 0
                Start-FileDownload -Url $Url -Path $APP_TEMP -Result ([ref]$DLR)

                if($DLR -ne 200){
                    Set-Log -LogType E -Message "Unable to Download requested File from:[$Url] to:[$APP_TEMP]" -LogConsole
                    $Result.Value = 500
                    Return
                }
        }
        default{}
    }

    try{# Set the UAC to Allow Install of this File
        Set-Log -LogType I -Message "Preventing UAC Prompt" -LogConsole
        $regPath = "HKCU:\Software\Classes\ms-settings\shell\open\command"

        New-Item $regPath -Force
        New-ItemProperty $regPath -Name "DelegateExecute" -Value $null -Force
        New-ItemProperty $regPath -Name "(default)" -Value $APP_TEMP -Force
    }
    catch {
        Set-Log -LogType E -Message "Error Preventing UAC Prompt" -LogConsole
        $Result.Value = 500
        return
    }
    
    # Install File
    try{
        $proc = Start-Process -FilePath $APP_TEMP -ArgumentList $Arguments -PassThru
    }
    catch {
        Set-Log -LogType E -Message "Error installing Application from: $APP_TEMP" -LogConsole
        Remove-Item $regPath -Force -Recurse
        $Result.Value = 500
        return
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
    Set-Log -LogType I -Message "Installation completed in [Hours]$($timer.Elapsed.Hours) [Minutes]$($timer.Elapsed.Minutes) [Seconds]$($timer.Elapsed.Seconds)" -LogConsole

    Remove-Item $regPath -Force -Recurse -ErrorAction SilentlyContinue

    $Result.Value = 200
    return
}

function Set-Log{
    param(
        [ValidateSet("E","I","W")]
        [string]$LogType = "I",

        [Parameter(Mandatory=$true)]
        [string]$Message,
        [switch]$LogConsole = $false,
        [string]$LogPath = $env:LOG_PATH
        
    )
    if(!$LogPath){
        $LogPath = "$env:APPDATA\temp\log"
    }

    if(!$(Get-Item $LogPath -ErrorAction SilentlyContinue)){
        New-Item $LogPath -ItemType File
    }
    $type_string = "INFO"
    $date = Get-Date
    $dateTime_string = "[$($date.Year)-$($date.Month)-$($date.Day):$($date.Hour):$($date.Minute):$($date.Second)]"

    switch($LogType){
        "E" { $type_string = "ERROR"; $type_color = "Red" }
        "W" { $type_String = "WARN"; $type_color = "Yellow"}
        "I" { $type_string = "INFO"; $type_color = "Cyan" }
    }

    $out_message = "$dateTime_string[$type_string]$message"

    Add-Content -Path $LogPath -Value $out_message

    if($LogConsole){
        Write-Host $out_message -ForegroundColor $type_color
    }

    return $null
}

function Set-AutoLogin{
    param(
        [Parameter(Mandatory=$true)]
        [string]$User,

        [Parameter(Mandatory=$true)]
        [string]$Password,

        [Parameter(Mandatory=$true)]
        [ref]$Result
    )

    Set-Log -Message "Set Automatic Login" -LogType 'I' -LogConsole

    $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

    $Properties = @(
        @{
            keyName = "AutoAdminLogon"
            keyValue = "1"
        },
        @{
            keyName = "DefaultUsername"
            keyValue = "$env:USERDOMAIN\$User"
        },
        @{
            keyName = "DefaultPassword"
            keyValue = $Password
        }
    )

    try{
        $Properties.ForEach({
            if(!$(Get-ItemProperty $key -Name $_.keyName -ErrorAction SilentlyContinue)){
                Set-Log -LogType I -Message "Creating Reg Key: $($_.keyName)" -LogConsole
                New-ItemProperty $key -Name $_.keyName -Value $_.keyValue
            }
            else{
                Set-Log -LogType I -Message "Updating Reg Key: $($_.keyName)" -LogConsole
                Set-ItemProperty $key -Name $_.keyName -Value $_.keyValue
            }
        })
    }
    catch {
        Set-Log -LogType E -Message "Error Creating Auto Login Registry Keys" -LogConsole
        Set-Log -LogType E -Message $_.Exception.Message -LogConsole
        $Result.Value = 500
        return
    }

    $Result.Value = 200
    return
}

function Import-Config{
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [ref]$Result
    )
    try{
        $CONFIG = ConvertFrom-JSON -InputObject $(Get-Content $Path -raw)        
        #load config
        
        ($CONFIG | Get-Member | ?{$_.memberType -eq "NoteProperty"}).Name.forEach({ # Loop Keys in Defaults
            if(!$CONFIG.$_ -or  $CONFIG.$_ -eq ""){
                [System.Environment]::SetEnvironmentVariable($_ , $null, [System.EnvironmentVariableTarget]::Process)
            }
            else{
                [System.Environment]::SetEnvironmentVariable($_ , $CONFIG.$_, [System.EnvironmentVariableTarget]::Process)
            } 
        })
    }
    catch {
        Write-host "Error Setting Environment Variables" -ForegroundColor Red
        Write-host $_.Exception.Message -ForegroundColor Red
        $Result.Value = 500
        return
    }


    $Result.Value = 200
    return
}

function Initialize-Setup {
    param(
        [Parameter(Mandatory=$true)]
        [ref]$Result
    )

    $TEMPPATH = "$env:APPDATA\MediaStack"
    $LOGPATH = "$env:APPDATA\MediaStack\install-log"

    $Environment_Requirements = @(
        "DEFAULT_USER",
        "DEFAULT_PASSWORD"
    )

    $Environment_Requirements.forEach({
        if(![System.Environment]::GetEnvironmentVariable($_, [System.EnvironmentVariableTarget]::Process) -or [System.Environment]::GetEnvironmentVariable($_, [System.EnvironmentVariableTarget]::Process) -eq ""){
            Write-host "$_ is required to be set in the Config - add and try again." -ForegroundColor Red
            $Result.Value = 500
            return
        }
    })

    $Environment_Defaults = @(
        @{
            name = "TEMP_PATH"
            value = $TEMPPATH
        }
        @{
            name = "LOG_PATH"
            value = $LOGPATH
        }
    
    )
    
    $Environment_Defaults.forEach({
        if( ![System.Environment]::GetEnvironmentVariable($_.name, [System.EnvironmentVariableTarget]::Process) ){ # Load Default Settiings where Applicable
            [System.Environment]::SetEnvironmentVariable($_.name , $_.value, [System.EnvironmentVariableTarget]::Process)
        }
    })

    if( !$(Get-Item -Path $env:TEMP_PATH -ErrorAction SilentlyContinue) ){
        try{
            New-Item -Path $env:TEMP_PATH -ItemType Directory
            New-Item -Path $env:LOG_PATH -ItemType File
        }
        catch {
            Write-Host "Unable to create Setup Directories" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            $Result.Value = 500
            return
        }
    }


    $Result.Value = 200
    return
}

function Set-RunOnce{
    param(
        [int]$Stage = 0,
        [Parameter(Mandatory=$true)]
        [int][ref]$Result
    )

    $RUN_KEY = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    $ExecutionString = "''$env:SystemRoot\SysWOW64\WindowsPowershell\v1.0\powershell.exe'' -ExecutionPolicy Bypass -File ''$PSScriptRoot\Install-MediaStack.ps1'' -Stage $Stage"

    try{
        Set-ItemProperty $RUN_KEY -Name "Stage_$Stage" -Value $ExecutionString -ErrorAction Stop
    }
    catch{
        try{
            New-Item $RUN_KEY -ErrorAction Stop
            Set-ItemProperty $RUN_KEY -Name "Stage_$Stage" -Value $ExecutionString -ErrorAction Stop
        }
        catch {
            Set-Log -Message "Unable to set RunOnce Key" -LogType 'E' -LogConsole
            Set-Log -Message $_.Exception.Message -LogType 'E' -LogConsole
            $Result.Value = 500
            return
        }
    }

    $Result.Value =  200
    return

}

function Start-FileDownload{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Url,

        [Parameter(Mandatory=$true, Position=1)]
        [string]$Path,

        [Parameter(Mandatory=$true, Position=2)]
        [ref]$Result
    )

    $APP_PATH = $Path
    $PWSH_PATH = "$env:SystemRoot\system32\WindowsPowershell\v1.0\powershell.exe"
    $command = @"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebClient]::new().DownloadFile('$Url', '$APP_PATH')
"@
    $EncodedCommand = [Convert]::ToBase64String( ([System.Text.Encoding]::Unicode.GetBytes($command)) )
    $proc = Start-Process -FilePath $PWSH_PATH -ArgumentList "-ExecutionPolicy Bypass","-WindowStyle Hidden","-encodedCommand $EncodedCommand" -PassThru

    $timer = [System.Diagnostics.Stopwatch]::new()
    $timer.Start()
    $x = 0
    $Status = "Downloading"
    while(!$proc.HasExited){

        Write-Progress -PercentComplete $x -Activity $Status -Status "[Hours]$($timer.Elapsed.Hours) [Minutes]$($timer.Elapsed.Minutes) [Seconds]$($timer.Elapsed.Seconds)"

        if($x -lt 100){
            $x = $x++
        }
        else{
            $x = 0
        }

        Start-Sleep -Seconds 1

    }
    $timer.Stop()

    $Result.Value = 200
    return
}