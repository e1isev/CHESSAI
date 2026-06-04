@echo off
setlocal

REM Run this from the repository root on Windows to overwrite the Android
REM Gradle files, clear stale Gradle/Flutter build output, and refresh packages.

cd /d "%~dp0"

echo Replacing Android Gradle files...
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\replace_android_gradle_files.ps1"
if errorlevel 1 goto failed

echo.
echo Ensuring Gradle wrapper JAR exists locally...
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\ensure_gradle_wrapper.ps1"
if errorlevel 1 goto failed

echo.
echo Verifying android\app\build.gradle uses the modern Flutter plugins DSL...
powershell -NoProfile -Command "Get-Content 'android\app\build.gradle' -TotalCount 20"
if errorlevel 1 goto failed

echo.
echo Running flutter clean...
flutter clean
if errorlevel 1 goto failed

echo.
echo Running flutter pub get...
flutter pub get
if errorlevel 1 goto failed

echo.
echo Android Gradle files were refreshed. Now run:
echo flutter run
exit /b 0

:failed
echo.
echo Fix script failed. Copy the output above and send it back.
exit /b 1
