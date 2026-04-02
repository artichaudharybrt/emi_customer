@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"
if not exist "..\qr_payload_enterprise_provisioning.json" (
  echo qr_payload_enterprise_provisioning.json missing at repo root
  exit /b 1
)
if not exist "..\qr_payload_normal_apk_url.txt" (
  echo qr_payload_normal_apk_url.txt missing at repo root
  exit /b 1
)
if not exist "package.json" (
  echo tools\package.json missing
  exit /b 1
)
if not exist "node_modules\qrcode\" (
  echo Installing qrcode in tools\ (one-time^)...
  call npm install --omit=dev
  if errorlevel 1 exit /b 1
)

node write_enterprise_qr_png.cjs
if errorlevel 1 exit /b 1

echo QR_OK
exit /b 0

