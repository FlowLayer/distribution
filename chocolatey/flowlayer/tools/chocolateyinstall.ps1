$ErrorActionPreference = 'Stop'

$packageName = 'flowlayer'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Generated for release v1.0.0.
# TODO: Replace placeholder URLs/checksums with real release metadata.
# This package is intentionally not publishable until those placeholders are replaced.
$urlX64 = 'https://github.com/FlowLayer/flowlayer/releases/download/v1.0.0/flowlayer_windows_amd64.zip'
$checksumX64 = 'REPLACE_WITH_REAL_SHA256_FROM_RELEASE_SHA256SUMS'

$urlArm64 = 'https://github.com/FlowLayer/flowlayer/releases/download/v1.0.0/flowlayer_windows_arm64.zip'
$checksumArm64 = 'REPLACE_WITH_REAL_SHA256_FROM_RELEASE_SHA256SUMS'

$isArm64 = ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') -or ($env:PROCESSOR_ARCHITEW6432 -eq 'ARM64')

if ($isArm64) {
  $url = $urlArm64
  $checksum = $checksumArm64
}
else {
  $url = $urlX64
  $checksum = $checksumX64
}

Install-ChocolateyZipPackage `
  -PackageName $packageName `
  -Url $url `
  -Checksum $checksum `
  -ChecksumType 'sha256' `
  -UnzipLocation $toolsDir

Write-Host 'FlowLayer install metadata applied. Replace placeholders before real publication.'
