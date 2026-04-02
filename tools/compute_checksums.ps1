# Usage: get cert SHA-256 hex from "apksigner verify --print-certs your.apk" (Signer #1 certificate SHA-256 digest),
# then: .\compute_checksums.ps1 -ApkPath .\app.apk -CertSha256Hex 6ddb81d7...
# Paste APK_CHECKSUM_B64URL and CERT_CHECKSUM_B64URL into qr_payload_enterprise_provisioning.json, then run tools\generate_qr.cmd

param(
  [Parameter(Mandatory = $true)]
  [string]$ApkPath,

  [Parameter(Mandatory = $true)]
  [string]$CertSha256Hex
)

$ErrorActionPreference = "Stop"

function Convert-HexToBytes([string]$Hex) {
  $hexNorm = $Hex.Trim().ToLower()
  if ($hexNorm.Length % 2 -ne 0) { throw "Hex must have even length." }

  $bytes = New-Object byte[] ($hexNorm.Length / 2)
  for ($i = 0; $i -lt $bytes.Length; $i++) {
    $bytes[$i] = [Convert]::ToByte($hexNorm.Substring($i * 2, 2), 16)
  }
  return $bytes
}

function Convert-BytesToBase64Url([byte[]]$Bytes) {
  $b64 = [Convert]::ToBase64String($Bytes)
  return ($b64.TrimEnd("=") -replace "\+", "-" -replace "/", "_")
}

$apkHex = (Get-FileHash -Algorithm SHA256 -Path $ApkPath).Hash.ToLower()
$apkB64Url = Convert-BytesToBase64Url (Convert-HexToBytes $apkHex)

$certHex = $CertSha256Hex.Trim().ToLower()
$certB64Url = Convert-BytesToBase64Url (Convert-HexToBytes $certHex)

Write-Output "APK_SHA256_HEX=$apkHex"
Write-Output "APK_CHECKSUM_B64URL=$apkB64Url"
Write-Output "CERT_SHA256_HEX=$certHex"
Write-Output "CERT_CHECKSUM_B64URL=$certB64Url"

