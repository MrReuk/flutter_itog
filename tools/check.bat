@echo off
cd /d "%~dp0.."
echo === flutter pub get === > check.log
call flutter pub get >> check.log 2>&1
echo === dart format lib test (apply) === >> check.log
call dart format lib test >> check.log 2>&1
echo === dart format --set-exit-if-changed lib test === >> check.log
call dart format --output=none --set-exit-if-changed lib test >> check.log 2>&1
echo format exit code: %errorlevel% >> check.log
echo === flutter analyze === >> check.log
call flutter analyze >> check.log 2>&1
echo analyze exit code: %errorlevel% >> check.log
echo === flutter test === >> check.log
call flutter test --reporter expanded >> check.log 2>&1
echo test exit code: %errorlevel% >> check.log
echo === done === >> check.log
