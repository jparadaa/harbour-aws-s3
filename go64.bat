@echo off

rem Si la variable DevEnvDir no está definida, significa que el entorno de Visual Studio
rem (cl.exe, link.exe, etc.) no está cargado. Entonces ejecutamos vcvarsall.bat para
rem inicializar las rutas y herramientas necesarias para compilar.

if not defined DevEnvDir (
  call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x86_x64
)

rem ==== Eliminación segura de archivos previos ====
if exist hbsigv4.exe del hbsigv4.exe
if exist hbsigv4.exp del hbsigv4.exp
if exist hbsigv4.lib del hbsigv4.lib
rem ===============================================

c:\harbour\bin\hbmk2 hbsigv4.hbp -comp=msvc64

IF ERRORLEVEL 1 GOTO COMPILEERROR

@cls
hbsigv4.exe

GOTO EXIT

:COMPILEERROR
echo *** Error 
pause

:EXIT