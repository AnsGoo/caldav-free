@echo off
setlocal

:: -- caldav-free Windows one-click build --
:: Output: mobile\windows\installer\output\caldav-free-windows-x64.exe

cd /d "%~dp0"

:: -- Read version from pubspec.yaml (strip build number after +) --
for /f "tokens=2 delims=: " %%v in ('findstr /b "version:" mobile\pubspec.yaml') do (
    for /f "tokens=1 delims=+" %%n in ("%%v") do set "APP_VERSION=%%n"
)
if not defined APP_VERSION (
    echo [ERROR] Cannot read version from mobile\pubspec.yaml
    exit /b 1
)
echo [INFO] Version: %APP_VERSION%

:: -- Check Flutter (try PATH, then common locations) --
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    if exist "D:\flutter\bin\flutter.bat" (
        set "PATH=D:\flutter\bin;%PATH%"
    ) else if exist "%USERPROFILE%\flutter\bin\flutter.bat" (
        set "PATH=%USERPROFILE%\flutter\bin;%PATH%"
    ) else if exist "%LOCALAPPDATA%\flutter\bin\flutter.bat" (
        set "PATH=%LOCALAPPDATA%\flutter\bin;%PATH%"
    ) else (
        echo [ERROR] flutter not found. Please install and add to PATH.
        exit /b 1
    )
)

:: -- Check Inno Setup --
set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=C:\Program Files\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" (
    echo [ERROR] Inno Setup 6 not found. Install from https://jrsoftware.org/isdl.php
    exit /b 1
)

:: -- [1/4] Sync dependencies --
echo.
echo ---- [1/4] flutter pub get ----
cd mobile
call flutter pub get
if %errorlevel% neq 0 (
    echo [ERROR] flutter pub get failed
    exit /b 1
)
cd ..

:: -- [2/4] Build Windows release --
echo.
echo ---- [2/4] flutter build windows --release ----
cd mobile
call flutter build windows --release
if %errorlevel% neq 0 (
    echo [ERROR] flutter build windows failed
    exit /b 1
)
cd ..

:: -- [3/4] Build installer (pass version via /D) --
echo.
echo ---- [3/4] ISCC build installer ----
cd mobile\windows\installer
"%ISCC%" /DMyAppVersion=%APP_VERSION% caldav-free.iss
if %errorlevel% neq 0 (
    echo [ERROR] Inno Setup compile failed
    cd ..\..\..
    exit /b 1
)
cd ..\..\..

:: -- [4/4] Done --
set "OUTPUT=mobile\windows\installer\output\caldav-free-windows-x64.exe"
echo.
echo ---- [4/4] Done ----
echo.
echo   Output: %OUTPUT%
echo   Version: %APP_VERSION%
echo.

explorer /select,"%OUTPUT%"
endlocal
