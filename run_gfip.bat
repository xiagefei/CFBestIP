@echo off
setlocal

:: 获取当前脚本所在目录
set "scriptDir=%~dp0"

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo 正在以管理员权限重新启动...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: 执行 PowerShell 脚本，绕过执行策略
powershell -NoProfile -ExecutionPolicy Bypass -File "%scriptDir%gfip.ps1"

endlocal
pause
