@echo off
REM Runs the Flutter app on the USB-connected phone. Start RUN-MEDISYNC.bat first (it starts the server).
cd /d "%~dp0mobile"
if not exist "android" powershell -ExecutionPolicy Bypass -File setup-android.ps1
set ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe
set DEVICE=
for /f "skip=1 tokens=1,2" %%a in ('"%ADB%" devices') do if "%%b"=="device" set DEVICE=%%a
if "%DEVICE%"=="" (
  echo No phone found. Plug in the USB cable, unlock the phone, turn USB debugging ON and tap Allow.
  pause
  exit /b
)
"%ADB%" reverse tcp:5000 tcp:5000
flutter run -d %DEVICE%
pause
