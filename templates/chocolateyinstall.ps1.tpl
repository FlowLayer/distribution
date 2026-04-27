$ErrorActionPreference = 'Stop'

$packageName = 'flowlayer'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Generated for release {{RELEASE_TAG}}.
# TODO: Replace placeholder URLs/checksums with real release metadata.
# This package is intentionally not publishable until those placeholders are replaced.
$urlX64 = '{{WINDOWS_AMD64_URL}}'
$checksumX64 = '{{WINDOWS_AMD64_SHA256}}'

$urlArm64 = '{{WINDOWS_ARM64_URL}}'
$checksumArm64 = '{{WINDOWS_ARM64_SHA256}}'

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
