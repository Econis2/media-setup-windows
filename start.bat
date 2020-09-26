powershell.exe -ExecutionPolicy Bypass -command "& { $shell = New-Object -COM Shell.Application; $target = $shell.NameSpace(%CD%); $zip = $shell.NameSpace(%CD%); $target.CopyHere($zip.Items(), 16); }"

powershell.exe -ExecutionPolicy Bypass -File "%CD%\Install-MediaStack.ps1" -Stage 0