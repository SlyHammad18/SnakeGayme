@echo off
set MASM32=C:\masm32
if not exist "%MASM32%\bin\ml.exe" (
    echo MASM32 not found in %MASM32%
    exit /b 1
)

"%MASM32%\bin\ml.exe" /c /coff /Cp snake.asm
if %errorlevel% neq 0 exit /b %errorlevel%

"%MASM32%\bin\link.exe" /SUBSYSTEM:WINDOWS /LIBPATH:"%MASM32%\lib" snake.obj
if %errorlevel% neq 0 exit /b %errorlevel%

echo Build successful!
