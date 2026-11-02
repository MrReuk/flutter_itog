@echo off
cd /d "%~dp0.."
call flutter build web --release > build-web.log 2>&1
echo build exit code: %errorlevel% >> build-web.log
powershell -NoProfile -Command "if (Test-Path webbuild3.zip) { Remove-Item webbuild3.zip }; Compress-Archive -Path build\web\* -DestinationPath webbuild3.zip" >> build-web.log 2>&1
echo zip done >> build-web.log
