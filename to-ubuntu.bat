@echo off
rem to-ubuntu.bat - double-click to reboot into Ubuntu (auto elevates to admin)
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0to-ubuntu.ps1\"'"
