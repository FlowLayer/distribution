# Run as a normal user (NOT admin) in PowerShell.
#
# Diagnoses why winget extracts and verifies the hash for the local
# FlowLayer 1.1.0 manifest but never registers the portable package.
#
# Strategy:
#   1. Snapshot the DiagOutputDir before running anything.
#   2. Run only `winget install` (no other winget calls afterwards) so the
#      newest log under DiagOutputDir is guaranteed to be the install log.
#   3. Print the tail of that log.
#   4. Then do the post-install checks (which generate their own logs but
#      do not pollute the previous step).

$ErrorActionPreference = 'Continue'

$Manifest = 'Z:\flowlayer\distribution\winget\manifests\FlowLayer.FlowLayer\1.1.0'
$DiagDir = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir"

Write-Host '=== Step 0: env ===' -ForegroundColor Cyan
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host ("Admin: {0}" -f $isAdmin)
Write-Host ("Manifest: {0}" -f $Manifest)
Write-Host ("Diag dir: {0}" -f $DiagDir)

Write-Host ''
Write-Host '=== Step 1: residual checks (before install) ===' -ForegroundColor Cyan
Write-Host '-- Links/ entries that match flowlayer*'
Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Links" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'flowlayer*' } | Format-Table Name, LastWriteTime
Write-Host '-- Packages/ entries that match FlowLayer*'
Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'FlowLayer*' } | Format-Table Name, LastWriteTime

Write-Host ''
Write-Host '=== Step 2: timestamp before install ===' -ForegroundColor Cyan
$beforeInstall = Get-Date
Write-Host ("Marker: {0}" -f $beforeInstall.ToString('o'))

Write-Host ''
Write-Host '=== Step 3: install with verbose logging ===' -ForegroundColor Cyan
winget install --manifest $Manifest --verbose-logs --accept-package-agreements --accept-source-agreements 2>&1 | Out-Host

Write-Host ''
Write-Host '=== Step 4: install log tail (last 250 lines) ===' -ForegroundColor Cyan
# Pick the newest log written *after* the marker. Do this BEFORE calling any
# other winget command so the install log is guaranteed to be the newest.
$installLog = Get-ChildItem $DiagDir -Filter 'WinGet-*.log' -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $beforeInstall } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if ($installLog) {
    Write-Host ("(install log: {0})" -f $installLog.FullName)
    Get-Content $installLog.FullName -Tail 250
} else {
    Write-Host 'No install log found after marker.'
}

Write-Host ''
Write-Host '=== Step 5: post-install state (winget list / where.exe / Links / Packages) ===' -ForegroundColor Cyan
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
