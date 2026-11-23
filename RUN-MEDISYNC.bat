@echo off
setlocal
cd /d "%~dp0"
echo ===== MediSync =====
if not exist "server\node_modules" (
  echo Installing server packages. Please wait 2 to 3 minutes...
  pushd server
  call npm install
  popd
)
if not exist "client\node_modules\qrcode" (
  echo Installing website packages. Please wait 2 to 3 minutes...
  pushd client
  call npm install
  popd
)
if not exist "server\.seeded" (
  echo Adding demo doctors and patient...
  pushd server
  call npm run seed
  echo done> .seeded
  popd
)
start "MediSync Server" cmd /k "cd /d %~dp0server && npm start"
start "MediSync Website" cmd /k "cd /d %~dp0client && npm run dev"
timeout /t 8 >nul
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
  "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" reverse tcp:5000 tcp:5000
  "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" reverse tcp:5173 tcp:5173
)
echo.
echo MediSync is running.
echo Laptop : open  http://localhost:5173  in Chrome
echo Phone  : connect the USB cable, then open  http://localhost:5173  in the phone Chrome
echo.
echo Logins:  Doctor  ananya@medisync.com / Doctor@123
echo          Patient patient@medisync.com / Patient@123
echo          Admin   admin@medisync.com   / Admin@123
pause
