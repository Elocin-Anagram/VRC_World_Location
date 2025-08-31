@echo off
REM This batch file runs a PowerShell script with administrative privileges.
REM When you run this file, a User Account Control (UAC) prompt will appear.
REM Click "Yes" to allow the script to run as an administrator.


PowerShell -Command "Start-Process PowerShell -Verb RunAs -ArgumentList '-NoExit -ExecutionPolicy Bypass -File \"VRC_Locator.PS1\"'"

pause
