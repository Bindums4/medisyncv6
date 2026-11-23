@echo off
REM Installs the MediSync app on your REAL phone so it works over Wi-Fi, with no cable needed afterwards.
REM 1) Start RUN-MEDISYNC.bat first.  2) Phone and laptop on the SAME Wi-Fi.  3) Plug the phone in once (USB debugging ON).
cd /d "%~dp0mobile"
if not exist "android" powershell -ExecutionPolicy Bypass -File setup-android.ps1
set IP=
for /f %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mobile\get-ip.ps1"') do set IP=%%i
if "%IP%"=="" (
  echo Could not find the laptop Wi-Fi address. Connect the laptop to Wi-Fi and try again.
  pause
  exit /b
)
echo Laptop address: %IP%
net session >nul 2>&1
if %errorlevel%==0 (
  netsh advfirewall firewall add rule name="MediSync server 5000" dir=in action=allow protocol=TCP localport=5000 >nul 2>&1
  echo Windows Firewall: port 5000 allowed.
) else (
  echo NOTE: if the phone cannot connect, right-click this file and choose Run as administrator once to open port 5000.
)
echo Building the app. The first build takes a few minutes...
call flutter build apk --release --dart-define=API=http://%IP%:5000/api
if errorlevel 1 (
  echo Build failed. Send a screenshot of the red error.
  pause
  exit /b
)
set APK=build\app\outputs\flutter-apk\app-release.apk
set ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe
set DEVICE=
if exist "%ADB%" for /f "skip=1 tokens=1,2" %%a in ('"%ADB%" devices') do if "%%b"=="device" set DEVICE=%%a
if "%DEVICE%"=="" (
  echo.
  echo No phone connected. Copy this file to the phone and open it to install:
  echo   %CD%\%APK%
  pause
  exit /b
)
"%ADB%" -s %DEVICE% install -r "%APK%"
echo.
echo Done. Open MediSync on the phone. It talks to http://%IP%:5000 over Wi-Fi.
echo If the laptop Wi-Fi address changes later, tap "Server" on the app login screen and type the new address.
pause
