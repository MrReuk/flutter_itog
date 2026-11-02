@echo off
cd /d "%~dp0"
if exist pb_data rmdir /s /q pb_data
echo База удалена. Запустите start.bat
