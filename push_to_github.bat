@echo off
cd /d "%~dp0"
echo === TonFlow — push to GitHub ===

git init
git add CryptoVisit.sol CryptoVisit.tact miniapp.html index.html tonconnect-manifest.json CryptoVisit-Plan.md
git commit -m "Initial commit: TonFlow — DCA & Limit Orders on TON (STON.fi grant)"
git branch -M main
git remote add origin https://github.com/pxpiVB/tonflow.git
git push -u origin main

echo.
echo === Done! Check https://github.com/pxpiVB/tonflow ===
pause
