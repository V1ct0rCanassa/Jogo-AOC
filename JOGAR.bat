@echo off
rem Core Defense x86 - abre o CORE.COM no DOSBox-X ou DOSBox
rem (o Windows 64 bits nao roda programas DOS de 16 bits sozinho)
cd /d "%~dp0"
set "DB="

for %%P in (
  "%ProgramFiles%\DOSBox-X\dosbox-x.exe"
  "%ProgramFiles(x86)%\DOSBox-X\dosbox-x.exe"
  "%LocalAppData%\Programs\DOSBox-X\dosbox-x.exe"
  "C:\DOSBox-X\dosbox-x.exe"
  "%~dp0DOSBox-X\dosbox-x.exe"
  "%ProgramFiles(x86)%\DOSBox-0.74-3\DOSBox.exe"
  "%ProgramFiles%\DOSBox-0.74-3\DOSBox.exe"
) do if not defined DB if exist %%P set "DB=%%~P"

if not defined DB for %%E in (dosbox-x.exe dosbox.exe) do if not defined DB (
  for /f "delims=" %%F in ('where %%E 2^>nul') do if not defined DB set "DB=%%F"
)

if defined DB goto run

echo.
echo  DOSBox nao encontrado. Ele e o emulador que roda programas DOS.
echo.
choice /c SN /m " Instalar o DOSBox-X agora pelo winget"
if errorlevel 2 goto manual
winget install -e --id joncampbell123.DOSBox-X --accept-source-agreements --accept-package-agreements
echo.
echo  Instalado. Rode o JOGAR.bat de novo.
pause
exit /b

:manual
start "" "https://dosbox-x.com/"
echo  Baixe e instale o DOSBox-X, depois rode o JOGAR.bat de novo.
pause
exit /b

:run
start "" "%DB%" -conf "%~dp0dosbox-core.conf"
