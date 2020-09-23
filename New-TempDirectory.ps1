param(
    [Parameter(Mandatory=$true,Position=0)]
    [string]$Path
)

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