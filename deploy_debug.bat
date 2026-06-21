@echo off
cd /d "%~dp0"
echo === TonFlow Deploy Debug ===
echo.

echo Checking Node.js...
node --version
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Node.js not installed!
    echo Download from: https://nodejs.org
    pause
    exit /b 1
)

echo.
echo Checking npm...
npm --version
echo.

echo [1/3] Installing dependencies...
npm install
if %errorlevel% neq 0 (
    echo ERROR: npm install failed!
    pause
    exit /b 1
)

echo.
echo [2/3] Building contract...
npx blueprint build TonFlow
if %errorlevel% neq 0 (
    echo ERROR: Build failed!
    pause
    exit /b 1
)

echo.
echo [3/3] Deploying to testnet...
echo NOTE: A QR code or link will appear - scan/open with TON Wallet
echo.
npx blueprint run deployTonFlow --testnet

pause
