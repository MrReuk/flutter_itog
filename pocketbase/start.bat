@echo off
cd /d "%~dp0"
pocketbase.exe serve --http=127.0.0.1:8090
