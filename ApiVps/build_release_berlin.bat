@echo off
setlocal

set PROJECT=C:\DEV\Confere_Arquivo\ApiVps\Projeto\ConfereArquivoApi.dpr
set DCC32="C:\Program Files (x86)\Embarcadero\Studio\18.0\bin\DCC32.EXE"
set RSVARS="C:\Program Files (x86)\Embarcadero\Studio\18.0\bin\rsvars.bat"
set OUTDIR=C:\DEV\Confere_Arquivo\ApiVps\Bin
set UNITS=C:\DEV\Confere_Arquivo\ApiVps\Projeto;C:\DEV\Confere_Arquivo\Common;C:\horse\src

if not exist %OUTDIR% mkdir %OUTDIR%

call %RSVARS%
cd /d C:\DEV\Confere_Arquivo\ApiVps\Projeto
%DCC32% -B -Q -E%OUTDIR% -N0%OUTDIR% -U%UNITS% ConfereArquivoApi.dpr
if errorlevel 1 exit /b 1

echo Build concluido em %OUTDIR%
endlocal
