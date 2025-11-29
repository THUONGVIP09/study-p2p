@echo off
REM Script chạy Flutter app trên Chrome để test Screen Sharing và WebRTC

echo.
echo ========================================
echo   Flutter P2P Call - Web Mode
echo ========================================
echo.

cd flutter-app\flutter_application_1

echo [1/2] Checking Flutter...
flutter doctor -v

echo.
echo [2/2] Running on Chrome...
echo.
echo 💡 Tips:
echo   - Press R to hot reload
echo   - Press Q to quit
echo   - Press F12 in Chrome to open DevTools
echo.

flutter run -d chrome

pause
