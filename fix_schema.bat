@echo off
REM Fix script for Hotel Management database schema issues
echo ========================================
echo Hotel Management Schema Fix Script
echo ========================================
echo.

echo Step 1: Pulling latest schema fixes...
git pull origin claude/flutter-web-mobile-app-011CUrev2Uyd9CXv4aLzfr1y
if errorlevel 1 (
    echo ERROR: Git pull failed!
    pause
    exit /b 1
)
echo.

echo Step 2: Cleaning build cache...
flutter clean
if errorlevel 1 (
    echo ERROR: Flutter clean failed!
    pause
    exit /b 1
)
echo.

echo Step 3: Deleting old generated files...
del /s /q "lib\*.g.dart" 2>nul
del /s /q "lib\db\*.g.dart" 2>nul
echo Old generated files deleted.
echo.

echo Step 4: Getting dependencies...
flutter pub get
if errorlevel 1 (
    echo ERROR: Flutter pub get failed!
    pause
    exit /b 1
)
echo.

echo Step 5: Regenerating database code (this will take 1-3 minutes)...
dart run build_runner build --delete-conflicting-outputs
if errorlevel 1 (
    echo ERROR: Code generation failed!
    pause
    exit /b 1
)
echo.

echo ========================================
echo Schema fix completed successfully!
echo ========================================
echo.
echo Now try running: flutter run -d windows
echo.
pause
