@echo off
REM claude-recall.cmd — Windows launcher for the claude-recall Python script.
REM Put this folder on your PATH, then run `claude-recall ...` from any prompt.
REM Prefers the Python launcher (py); falls back to python on PATH.
setlocal
where py >nul 2>nul
if %errorlevel%==0 (
    py "%~dp0claude-recall" %*
) else (
    python "%~dp0claude-recall" %*
)
exit /b %errorlevel%
