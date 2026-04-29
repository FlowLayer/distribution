# Run as a normal user (NOT admin) in PowerShell.
# It installs the local 1.1.0 manifest with verbose logging, then prints
# the tail of the verbose log so we can see why winget extracts but does
# not register the portable package.

$ErrorActionPreference = 'Continue'

$Manifest = 'Z:\flowlayer\distribution\winget\manifests\FlowLayer.FlowLayer\1.1.0'
$LogFile = Join-Path $env:USERPROFILE 'winget-install-flowlayer.log'

Write-Host '=== Step 0: env ===' -ForegroundColor Cyan
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host ("Admin: {0}" -f $isAdmin)
Write-Host ("Manifest: {0}" -f $Manifest)
Write-Host ("Log file: {0}" -f $LogFile)

Write-Host ''
Write-Host '=== Step 1: residual checks ===' -ForegroundColor Cyan
Write-Host '-- Links/ entries that match flowlayer*'
Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Links" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'flowlayer*' } | Format-Table Name, LastWriteTime
Write-Host '-- Packages/ entries that match FlowLayer*'
Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'FlowLayer*' } | Format-Table Name, LastWriteTime

Write-Host ''
Write-Host '=== Step 2: clean uninstall (best effort) ===' -ForegroundColor Cyan
winget uninstall --id FlowLayer.FlowLayer 2>&1 | Out-Host

Write-Host ''
Write-Host '=== Step 3: install with verbose logging to a dedicated file ===' -ForegroundColor Cyan
if (Test-Path $LogFile) { Remove-Item $LogFile -Force }
winget install --manifest $Manifest --verbose-logs --log $LogFile --accept-package-agreements --accept-source-agreements 2>&1 | Out-Host

Write-Host ''
Write-Host '=== Step 4: post-install state ===' -ForegroundColor Cyan
Write-Host '-- winget list FlowLayer'
winget list FlowLayer 2>&1 | Out-Host
Write-Host '-- where.exe flowlayer-server'
where.exe flowlayer-server 2>&1 | Out-Host
Write-Host '-- where.exe flowlayer-client-tui'
where.exe flowlayer-client-tui 2>&1 | Out-Host
Write-Host '-- Links/ entries after install'
Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Links" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'flowlayer*' } | Format-Table Name, LastWriteTime
Write-Host '-- Packages/ entries after install'
Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'FlowLayer*' } | Format-Table Name, LastWriteTime

Write-Host ''
Write-Host '=== Step 5: verbose log tail (last 200 lines) ===' -ForegroundColor Cyan
if (Test-Path $LogFile) {
    Get-Content $LogFile -Tail 200
} else {
    # winget --log redirects to a file under DiagOutputDir; pick the most recent matching install
    $candidate = Get-ChildItem "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir" -Filter 'WinGet-*.log' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($candidate) {
        Write-Host ("(Falling back to {0})" -f $candidate.FullName)
        Get-Content $candidate.FullName -Tail 200
    } else {
        Write-Host 'No log file found.'
    }
}
