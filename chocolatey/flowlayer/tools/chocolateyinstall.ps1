$ErrorActionPreference = 'Stop'

$packageName = 'flowlayer'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$checksumPlaceholder = 'REPLACE_WITH_REAL_SHA256_FROM_RELEASE_SHA256SUMS'
$tempDir = Join-Path $env:TEMP ("flowlayer-" + [Guid]::NewGuid().ToString('N'))

# Generated for release v1.1.1.
# Assets are published from the global FlowLayer release: FlowLayer/flowlayer.
$serverUrlX64 = 'https://github.com/FlowLayer/flowlayer/releases/download/v1.1.1/flowlayer-server-1.1.1-windows-amd64.zip'
$serverChecksumX64 = '2b6df087e38f9193f35c92a34fd3a44ccc4f672c21cd60789a0cded6c10e038a'

$serverUrlArm64 = 'https://github.com/FlowLayer/flowlayer/releases/download/v1.1.1/flowlayer-server-1.1.1-windows-arm64.zip'
$serverChecksumArm64 = '09a65f9a30238a0560a9efd0ab050d7d9f8f6da1c4d1522c84a498925874d64e'

$tuiUrlX64 = 'https://github.com/FlowLayer/flowlayer/releases/download/v1.1.1/flowlayer-client-tui-1.1.1-windows-amd64.zip'
$tuiChecksumX64 = '0347319710e009949207530963dbe2dc530063bb9cf87c57c6ac497a27bdcf50'

$tuiUrlArm64 = 'https://github.com/FlowLayer/flowlayer/releases/download/v1.1.1/flowlayer-client-tui-1.1.1-windows-arm64.zip'
$tuiChecksumArm64 = '32df6eba5a66596c22725d408331241c8044a30cf94569c4bc3430ae3a8a8aa0'

$isArm64 = ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') -or ($env:PROCESSOR_ARCHITEW6432 -eq 'ARM64')

function Assert-ConcreteSha256 {
  param(
    [Parameter(Mandatory = $true)][string]$Expected,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if ($Expected -eq $checksumPlaceholder) {
    throw "$Label checksum placeholder detected; package must be generated with concrete SHA256 values."
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

  Assert-ConcreteSha256 -Expected $serverChecksum -Label 'server archive'
  Assert-ConcreteSha256 -Expected $tuiChecksum -Label 'tui archive'

  Get-ChocolateyWebFile -PackageName $packageName -FileFullPath $serverZip -Url $serverUrl -Checksum $serverChecksum -ChecksumType 'sha256' | Out-Null
  Get-ChocolateyWebFile -PackageName $packageName -FileFullPath $tuiZip -Url $tuiUrl -Checksum $tuiChecksum -ChecksumType 'sha256' | Out-Null

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
