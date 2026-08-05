@echo off
cd /d %~dp0
set PORT=4321
start "Planning board server" cmd /k node server.mjs %PORT%
timeout /t 2 >nul
start "" http://localhost:%PORT%
