@echo off
REM Makes an APK you can send to any Android phone (installs like WhatsApp).
REM For an APK that works anywhere, first deploy the server (see DEPLOY.md) and put its address below.
set API=https://YOUR-API.onrender.com/api
cd /d "%~dp0mobile"
if not exist "android" powershell -ExecutionPolicy Bypass -File setup-android.ps1
flutter build apk --release --dart-define=API=%API%
echo.
echo APK is here:  mobile\build\app\outputs\flutter-apk\app-release.apk
pause
