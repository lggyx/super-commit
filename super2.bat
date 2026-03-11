@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

set "REPO_PATH=D:\super-commit2"
set "START_DATE=2024-01-01"
set "END_DATE=2026-03-09"

cd /d "%REPO_PATH%"

:: 极致性能配置
git config core.preloadindex true
git config core.fscache true
git config gc.auto 0
git config index.version 4

echo 开始极速生成...

set "CURRENT_DATE=%START_DATE%"
set /a "COMMIT_COUNT=0"

:DATE_LOOP
call :DATE_CMP %CURRENT_DATE% %END_DATE%
if %ERRORLEVEL% GTR 0 goto DONE

:: 随机15-30次
set /a "N=%random% %% 16 + 15"

for /l %%i in (1,1,%N%) do (
    :: 随机时间 09:00:00 - 17:59:59
    set /a "H=%random% %% 9 + 9"
    set /a "M=%random% %% 60"
    set /a "S=%random% %% 60"
    if !H! LSS 10 set "H=0!H!"
    if !M! LSS 10 set "M=0!M!"
    if !S! LSS 10 set "S=0!S!"
    
    set "T=!CURRENT_DATE!T!H!:!M!:!S!+08:00"
    
    :: 创建文件
    echo. > "f!random!.txt"
    
    :: 极速提交（使用环境变量，避免参数解析）
    set "GIT_AUTHOR_DATE=!T!"
    set "GIT_COMMITTER_DATE=!T!"
    git add . >nul
    git commit -m "update !random!" --no-verify --quiet >nul
    
    set /a "COMMIT_COUNT+=1"
    <nul set /p "=."
)

echo  %CURRENT_DATE%: %N% commits
call :NEXT_DAY %CURRENT_DATE% CURRENT_DATE
goto DATE_LOOP

:DONE
echo.
echo 完成！共 %COMMIT_COUNT% 次提交
pause
goto :eof

:NEXT_DAY
set "D=%~1"
set /a "Y=%D:~0,4%, M=1%D:~5,2%-100, D=1%D:~8,2%-100"
set /a "D+=1, DIM=30+((M+M/8)%%2), DIM-=(M==2)*2, DIM+=(M==2)*(!(Y%%4)-!(Y%%100)+!(Y%%400))"
if %D% GTR %DIM% set "D=1" & set /a "M+=1"
if %M% GTR 12 set "M=1" & set /a "Y+=1"
if %M% LSS 10 set "M=0%M%"
if %D% LSS 10 set "D=0%D%"
set "%~2=%Y%-%M%-%D%"
goto :eof

:DATE_CMP
set "A=%~1"
set "B=%~2"
set "A=%A:~0,4%%A:~5,2%%A:~8,2%"
set "B=%B:~0,4%%B:~5,2%%B:~8,2%"
if %A% LSS %B% exit /b -1
if %A% GTR %B% exit /b 1
exit /b 0