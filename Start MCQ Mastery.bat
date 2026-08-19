@echo off
title MCQ Mastery
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1"

echo.
echo The server has stopped.
pause
