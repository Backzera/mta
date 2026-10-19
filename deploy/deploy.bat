@echo off
REM Atualiza o repositorio e envia para a hospedagem (FTP) so o que mudou em resources\[dm].
REM Requisitos: Git para Windows e WinSCP (https://winscp.net) instalados; deploy\ftp.local.txt preenchido.
setlocal
cd /d "%~dp0.."
if not exist "deploy\ftp.local.txt" (
    echo Crie deploy\ftp.local.txt a partir de deploy\ftp.exemplo.txt com os dados de FTP da hospedagem.
    pause & exit /b 1
)
echo === git pull ===
git pull || (echo Falha no git pull & pause & exit /b 1)
set WINSCP="%ProgramFiles(x86)%\WinSCP\WinSCP.com"
if not exist %WINSCP% set WINSCP="%ProgramFiles%\WinSCP\WinSCP.com"
if not exist %WINSCP% (echo WinSCP nao encontrado. Instale em https://winscp.net & pause & exit /b 1)
echo === enviando para a hospedagem ===
%WINSCP% /ini=nul /script=deploy\sync.txt /log=deploy\ultimo-envio.log
if errorlevel 1 (echo Erro no envio. Veja deploy\ultimo-envio.log & pause & exit /b 1)
echo.
echo Pronto! No console do painel: restart dm_ui   (ou o resource que mudou)
pause
