$ErrorActionPreference = 'Stop'

$packageName = 'flowlayer'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$checksumPlaceholder = 'REPLACE_WITH_REAL_SHA256_FROM_RELEASE_SHA256SUMS'
$tempDir = Join-Path $env:TEMP ("flowlayer-" + [Guid]::NewGuid().ToString('N'))

# Generated for release v1.0.0.
# Sources:
# - Server: FlowLayer/flowlayer
# - TUI: FlowLayer/tui
$serverUrlX64 = 'https://github.com/FlowLayer/flowlayer/releases/download/v1.0.0/flowlayer-server-1.0.0-windows-amd64.zip'
$serverChecksumX64 = 'a0e64c9d68cff7c27809aca06572ebf938b8b76e9ef292513c381814bac2fc75'

$serverUrlArm64 = 'https://github.com/FlowLayer/flowlayer/releases/download/v1.0.0/flowlayer-server-1.0.0-windows-arm64.zip'
$serverChecksumArm64 = 'd6148c91d249f11c74bf030c0d4d1d53e00b177f11cbb00b50f2b38dfe29e929'

$tuiUrlX64 = 'https://github.com/FlowLayer/tui/releases/download/v1.0.0/flowlayer-client-tui-1.0.0-windows-amd64.zip'
$tuiChecksumX64 = '3fc0111b57d82d1d2c1883842c17f9d22fab7d1dad927104e72521068b41392b'

$tuiUrlArm64 = 'https://github.com/FlowLayer/tui/releases/download/v1.0.0/flowlayer-client-tui-1.0.0-windows-arm64.zip'
$tuiChecksumArm64 = '378ad56a46266bf87d74946f34aa239bad4c546404ca78acd8c8478ffb3dd19c'

$isArm64 = ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') -or ($env:PROCESSOR_ARCHITEW6432 -eq 'ARM64')

function Assert-Sha256 {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string]$Expected,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if ($Expected -eq $checksumPlaceholder) {
    Write-Warning "$Label checksum placeholder detected; verification skipped."
    return
  }

  $actual = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $Expected.ToLowerInvariant()) {
    throw "$Label checksum mismatch. Expected $Expected, got $actual."
  }
}

if ($isArm64) {
  $serverUrl = $serverUrlArm64
  $serverChecksum = $serverChecksumArm64
  $tuiUrl = $tuiUrlArm64
  $tuiChecksum = $tuiChecksumArm64
}
else {
  $serverUrl = $serverUrlX64
  $serverChecksum = $serverChecksumX64
  $tuiUrl = $tuiUrlX64
  $tuiChecksum = $tuiChecksumX64
}

try {
  New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

  $serverZip = Join-Path $tempDir 'server.zip'
  $tuiZip = Join-Path $tempDir 'tui.zip'
  $serverExtract = Join-Path $tempDir 'server-extract'
  $tuiExtract = Join-Path $tempDir 'tui-extract'

  Get-ChocolateyWebFile -PackageName $packageName -FileFullPath $serverZip -Url $serverUrl | Out-Null
  Get-ChocolateyWebFile -PackageName $packageName -FileFullPath $tuiZip -Url $tuiUrl | Out-Null

  Assert-Sha256 -FilePath $serverZip -Expected $serverChecksum -Label 'server archive'
  Assert-Sha256 -FilePath $tuiZip -Expected $tuiChecksum -Label 'tui archive'

  Expand-Archive -Path $serverZip -DestinationPath $serverExtract -Force
  Expand-Archive -Path $tuiZip -DestinationPath $tuiExtract -Force

  $serverExe = Get-ChildItem -Path $serverExtract -Recurse -Filter 'flowlayer-server.exe' | Select-Object -First 1
  if (-not $serverExe) {
    throw 'flowlayer-server.exe was not found after extracting server archive.'
  }

  $tuiExe = Get-ChildItem -Path $tuiExtract -Recurse -Filter 'flowlayer-client-tui.exe' | Select-Object -First 1
  if (-not $tuiExe) {
    throw 'flowlayer-client-tui.exe was not found after extracting TUI archive.'
  }

  Copy-Item -Path $serverExe.FullName -Destination (Join-Path $toolsDir 'flowlayer-server.exe') -Force
  Copy-Item -Path $tuiExe.FullName -Destination (Join-Path $toolsDir 'flowlayer-client-tui.exe') -Force

  Write-Host 'FlowLayer server and TUI binaries were staged successfully.'
}
finally {
  if (Test-Path -Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
  }
}
