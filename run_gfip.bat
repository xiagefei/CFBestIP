@echo off
setlocal

:: ��ȡ��ǰ�ű�����Ŀ¼
set "scriptDir=%~dp0"

:: ������ԱȨ��
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo �����Թ���ԱȨ����������...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: ִ�� PowerShell �ű����ƹ�ִ�в���
powershell -NoProfile -ExecutionPolicy Bypass -File "%scriptDir%gfip.ps1"

endlocal
pause
