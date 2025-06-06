@echo off
title Git Proxy Tool
echo [1] Set proxy for Clash (127.0.0.1:7890)
echo [2] Remove proxy settings
set /p choice="Enter choice [1/2]: "

if "%choice%"=="1" (
    git config --global http.proxy http://127.0.0.1:7890
    git config --global https.proxy http://127.0.0.1:7890
    echo Proxy set successfully!
) else if "%choice%"=="2" (
    git config --global --unset http.proxy
    git config --global --unset https.proxy
    echo Proxy removed successfully!
) else (
    echo Invalid choice
)

echo.
echo Current proxy status:
call :show_proxy_status
echo.
pause
exit /b

:show_proxy_status
git config --global --get http.proxy
if errorlevel 1 echo HTTP Proxy: Not set
git config --global --get https.proxy
if errorlevel 1 echo HTTPS Proxy: Not set
goto :eof