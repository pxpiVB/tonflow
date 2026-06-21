Set shell = CreateObject("WScript.Shell")
shell.Run "cmd /k ""cd /d C:\Users\сергій\Downloads\yelay-lite-main && npm install && npx blueprint build TonFlow && npx blueprint run deployTonFlow --testnet"""
