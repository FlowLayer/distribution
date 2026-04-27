$ErrorActionPreference = 'Stop'

$packageName = 'flowlayer'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$checksumPlaceholder = 'REPLACE_WITH_REAL_SHA256_FROM_RELEASE_SHA256SUMS'
$tempDir = Join-Path $env:TEMP ("flowlayer-" + [Guid]::NewGuid().ToString('N'))

# Generated for release {{RELEASE_TAG}}.
# Sources:
# - Server: FlowLayer/flowlayer
# - TUI: FlowLayer/tui
$serverUrlX64 = '{{SERVER_WINDOWS_AMD64_URL}}'
$serverChecksumX64 = '{{SERVER_WINDOWS_AMD64_SHA256}}'

$serverUrlArm64 = '{{SERVER_WINDOWS_ARM64_URL}}'
$serverChecksumArm64 = '{{SERVER_WINDOWS_ARM64_SHA256}}'

$tuiUrlX64 = '{{TUI_WINDOWS_AMD64_URL}}'
$tuiChecksumX64 = '{{TUI_WINDOWS_AMD64_SHA256}}'

$tuiUrlArm64 = '{{TUI_WINDOWS_ARM64_URL}}'
$tuiChecksumArm64 = '{{TUI_WINDOWS_ARM64_SHA256}}'

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
