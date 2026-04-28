$ErrorActionPreference = 'Stop'

$packageName = 'flowlayer'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$checksumPlaceholder = 'REPLACE_WITH_REAL_SHA256_FROM_RELEASE_SHA256SUMS'
$tempDir = Join-Path $env:TEMP ("flowlayer-" + [Guid]::NewGuid().ToString('N'))

# Generated for release v1.0.0.
# Assets are published from the global FlowLayer release: FlowLayer/flowlayer.
$serverUrlX64 = 'https://github.com/FlowLayer/flowlayer/releases/download/v1.0.0/flowlayer-server-1.0.0-windows-amd64.zip'
$serverChecksumX64 = '1a68fe2087657b7a85e4d9210f73f0ac0eccb83d4b672c71442d4855cdfed968'

$serverUrlArm64 = 'https://github.com/FlowLayer/flowlayer/releases/download/v1.0.0/flowlayer-server-1.0.0-windows-arm64.zip'
$serverChecksumArm64 = '3ea14c4838bd9bb3d90ddb2108fe3fa45ef48446f798cfad83c64fa7f7b64507'

$tuiUrlX64 = 'https://github.com/FlowLayer/flowlayer/releases/download/v1.0.0/flowlayer-client-tui-1.0.0-windows-amd64.zip'
$tuiChecksumX64 = 'f4a12591c05f8757c014d05d5eda752ddea332ead4fe23fdb59f7ecc39158ef6'

$tuiUrlArm64 = 'https://github.com/FlowLayer/flowlayer/releases/download/v1.0.0/flowlayer-client-tui-1.0.0-windows-arm64.zip'
$tuiChecksumArm64 = '6a094841a161ea8f827693859834e769ed2442d85a4e00178c6aee4d573e178c'

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
