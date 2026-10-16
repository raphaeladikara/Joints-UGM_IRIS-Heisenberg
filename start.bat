@echo off
rem TILIK prototype: API di Docker + build web Flutter disajikan nginx, lalu buka browser.
rem Data demo FIKTIF. Mode demo tidak pernah menelepon 119 / RS.
rem
rem   start.bat           nyalakan semuanya (build web hanya kalau belum ada)
rem   start.bat rebuild   bangun ulang image API dan build web Flutter
rem   start.bat apk       bangun APK Android yang menunjuk ke IP laptop ini
rem   start.bat test      jalankan tes backend
rem   start.bat stop      matikan semua kontainer
setlocal EnableExtensions
cd /d "%~dp0"
set "MODE=%~1"

if /i "%MODE%"=="stop" (
  docker compose --profile web down
  exit /b %errorlevel%
)

rem --- .env ---
if not exist ".env" (
  copy /y ".env.example" ".env" >nul
  echo [i] .env dibuat dari .env.example. Isi OPENAI_API_KEY bila ingin jalur LLM aktif.
)

rem --- Docker ---
docker info >nul 2>&1
if not errorlevel 1 goto dockerok
echo [i] Docker belum menyala, mencoba membuka Docker Desktop...
if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" start "" "%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
set /a TRIES=0
:waitdocker
timeout /t 3 /nobreak >nul
docker info >nul 2>&1
if not errorlevel 1 goto dockerok
set /a TRIES+=1
if %TRIES% lss 40 goto waitdocker
echo [x] Docker tidak bisa dihubungi. Nyalakan Docker Desktop lalu jalankan lagi.
goto fail
:dockerok

if /i "%MODE%"=="test" (
  docker compose build api || goto fail
  docker compose run --rm api pytest -q
  pause
  exit /b %errorlevel%
)

for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Find-NetRoute -RemoteIPAddress 8.8.8.8 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress"`) do set "LANIP=%%i"
if not defined LANIP set "LANIP=IP-laptop"

if /i "%MODE%"=="apk" goto apk

rem --- 1. API ---
echo [1/3] Menyalakan API (Docker)...
if /i "%MODE%"=="rebuild" (
  docker compose up -d --build --force-recreate api || goto fail
) else (
  docker compose up -d --build api || goto fail
)

echo       Menunggu API siap...
powershell -NoProfile -Command "$ok=$false; for($i=0;$i -lt 40;$i++){ try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 http://127.0.0.1:8080/v1/health | Out-Null; $ok=$true; break } catch { Start-Sleep 1 } }; if(-not $ok){ exit 1 }"
if errorlevel 1 (
  echo [x] API tidak merespons. Lihat log: docker compose logs api
  goto fail
)

rem --- 2. Build web Flutter ---
if /i "%MODE%"=="rebuild" if exist "apps\mobile\build\web" rmdir /s /q "apps\mobile\build\web"
if exist "apps\mobile\build\web\index.html" (
  echo [2/3] Build web sudah ada. Pakai "start.bat rebuild" untuk membangun ulang.
  goto serve
)
where flutter >nul 2>&1
if errorlevel 1 (
  echo [x] Flutter tidak ditemukan di PATH, padahal build web belum ada.
  goto fail
)
echo [2/3] Membangun aplikasi Flutter versi web, bisa beberapa menit...
pushd apps\mobile
call flutter build web --release --dart-define=TILIK_API=http://127.0.0.1:8080
if errorlevel 1 (
  popd
  goto fail
)
popd

:serve
rem --- 3. Sajikan web ---
echo [3/3] Menyajikan aplikasi web...
docker compose --profile web up -d --force-recreate web || goto fail

start "" http://127.0.0.1:8081
echo.
echo  Aplikasi web : http://127.0.0.1:8081
echo  API + docs   : http://127.0.0.1:8080/docs
echo  Dari HP      : http://%LANIP%:8081  (Wi-Fi yang sama; ganti alamat server di ikon gear ke http://%LANIP%:8080)
echo.
echo  APK Android  : start.bat apk
echo  Matikan      : start.bat stop
pause
exit /b 0

:apk
where flutter >nul 2>&1
if errorlevel 1 (
  echo [x] Flutter tidak ditemukan di PATH.
  goto fail
)
echo Membangun APK dengan server http://%LANIP%:8080 ...
pushd apps\mobile
call flutter build apk --release --split-per-abi --dart-define=TILIK_API=http://%LANIP%:8080
set "RC=%errorlevel%"
popd
if not "%RC%"=="0" goto fail
echo.
echo  APK ada di apps\mobile\build\app\outputs\flutter-apk\  (pakai app-arm64-v8a-release.apk untuk HP modern)
pause
exit /b 0

:fail
echo Gagal. Pastikan Docker Desktop menyala dan Flutter terpasang.
pause
exit /b 1
