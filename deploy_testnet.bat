@echo off
cd /d "%~dp0"
echo === TonFlow — TON Testnet Deploy ===
echo.

echo [1/3] Installing dependencies...
npm install

echo.
echo [2/3] Building Tact contract...
npx blueprint build TonFlow

echo.
echo [3/3] Deploying to testnet...
echo NOTE: You need testnet TON in your wallet!
echo Get free testnet TON at: https://t.me/testgiver_ton_bot
echo.
npx blueprint run deployTonFlow --testnet

pause
