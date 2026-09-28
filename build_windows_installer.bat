@echo off
echo ========================================================
echo   DSA INCENTIVE TRACKER - WINDOWS BUILD & INNO SETUP
echo   XL SATU CILACAP - TSC PIPIN
echo ========================================================
echo.

echo [1/3] Membangun aplikasi Windows Release (Flutter)...
call flutter build windows --release
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Gagal melakukan flutter build windows.
    echo Pastikan Visual Studio dengan workload "Desktop development with C++" sudah terpasang.
    pause
    exit /b %errorlevel%
)

echo.
echo [2/3] Mengemas file installer dengan Inno Setup...
set "ISCC_PATH=C:\Users\Fadli Santoso\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
if not exist "%ISCC_PATH%" (
    set "ISCC_PATH=C:\Program Files\Inno Setup 7\ISCC.exe"
)
if not exist "%ISCC_PATH%" (
    set "ISCC_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
)

"%ISCC_PATH%" windows_installer.iss
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Inno Setup gagal mengompilasi installer.
    pause
    exit /b %errorlevel%
)

echo.
echo [3/3] Menyalin installer ke root project...
if exist "Output\DSA_XL_Satu_Handbook_Setup_v1.0.8.exe" (
    copy /y "Output\DSA_XL_Satu_Handbook_Setup_v1.0.8.exe" "DSA_XL_Satu_Handbook_Setup_v1.0.8.exe"
    copy /y "Output\DSA_XL_Satu_Handbook_Setup_v1.0.8.exe" "DSA_XL_Satu_Handbook_Setup.exe"
    echo.
    echo [SUKSES] Installer Windows telah siap di root project:
    echo   - DSA_XL_Satu_Handbook_Setup_v1.0.8.exe
    echo   - DSA_XL_Satu_Handbook_Setup.exe
)

echo.
echo Selesai!
pause
