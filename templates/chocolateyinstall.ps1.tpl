$ErrorActionPreference = 'Stop'

$packageName = 'flowlayer'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$checksumPlaceholder = 'REPLACE_WITH_REAL_SHA256_FROM_RELEASE_SHA256SUMS'
$tempDir = Join-Path $env:TEMP ("flowlayer-" + [Guid]::NewGuid().ToString('N'))

# Generated for release {{RELEASE_TAG}}.
# Assets are published from the global FlowLayer release: FlowLayer/flowlayer.
$serverUrlX64 = '{{SERVER_WINDOWS_AMD64_URL}}'
$serverChecksumX64 = '{{SERVER_WINDOWS_AMD64_SHA256}}'

$serverUrlArm64 = '{{SERVER_WINDOWS_ARM64_URL}}'
$serverChecksumArm64 = '{{SERVER_WINDOWS_ARM64_SHA256}}'

$tuiUrlX64 = '{{TUI_WINDOWS_AMD64_URL}}'
$tuiChecksumX64 = '{{TUI_WINDOWS_AMD64_SHA256}}'

$tuiUrlArm64 = '{{TUI_WINDOWS_ARM64_URL}}'
$tuiChecksumArm64 = '{{TUI_WINDOWS_ARM64_SHA256}}'

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
