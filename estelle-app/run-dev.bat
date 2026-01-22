@echo off
cd /d %~dp0
C:\flutter\bin\flutter.bat run -d web-server --web-port=8080
pause
