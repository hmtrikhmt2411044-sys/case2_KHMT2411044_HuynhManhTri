@echo off
title Case Study 2 - Task Manager (Development Environment)
setlocal enabledelayedexpansion

echo ===================================================================
echo   KHOI DONG HE THONG TASK MANAGER (CASE STUDY 2)
echo   Sinh vien: Huynh Manh Tri - MSSV: KHMT2411044
echo ===================================================================

set "PATH=C:\laragon\bin\nodejs\node-v22;C:\flutter\bin;%PATH%"

echo.
echo [1/2] Dang khoi dong Backend API Server tai http://localhost:3000 ...
start "Backend API Server (Port 3000)" cmd /k "cd /d "%~dp0api" && call run_api.bat"

echo.
echo [2/2] Dang khoi dong TaskManager Frontend (Flutter Web)...
cd /d "%~dp0TaskManager"
call C:\flutter\bin\flutter.bat run -d chrome

echo.
echo ===================================================================
echo Nhan phim bat ky de dung chuong trinh...
echo ===================================================================
pause
