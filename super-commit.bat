@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: ==================== 用户配置区 ====================

:: Git仓库路径（必须修改）
set "REPO_PATH=D:\super-commit"

:: 日期范围配置（格式：YYYY-MM-DD）
set "START_DATE=2024-01-01"
set "END_DATE=2026-03-09"

:: 每天最少/最多提交次数（随机范围）
set "MIN_COMMITS_PER_DAY=15"
set "MAX_COMMITS_PER_DAY=30"

:: 每天工作时间段（24小时制，默认9:00-18:00）
set "DAY_START_HOUR=9"
set "DAY_END_HOUR=18"

:: 每次提交创建的文件数量范围
set "MIN_FILES=1"
set "MAX_FILES=3"

:: 文件扩展名（逗号分隔，不要有空格）
set "FILE_EXTENSIONS=.md,.txt,.log"

:: 提交信息前缀（逗号分隔，不要有空格）
set "COMMIT_PREFIXES=feat,fix,docs,refactor,update,add"

:: 是否推送到远程（1=推送，0=仅本地提交）
set "PUSH_TO_REMOTE=0"

:: 远程分支名
set "REMOTE_BRANCH=main"

:: ==================== 初始化检查 ====================

echo ========================================
echo     Git Batch Commit Generator
echo ========================================
echo.

:: 检查Git
git --version >nul 2>&1
if errorlevel 1 (
    echo [错误] Git未安装或未添加到环境变量
    pause
    exit /b 1
)

:: 进入仓库
if not exist "%REPO_PATH%\.git" (
    echo [错误] 指定路径不是有效的Git仓库: %REPO_PATH%
    pause
    exit /b 1
)
cd /d "%REPO_PATH%"
echo [信息] 工作目录: %CD%

:: 检查工作区是否干净
git diff --quiet
if errorlevel 1 (
    echo [警告] 工作区有未提交的更改
    choice /C YN /M "是否继续"
    if errorlevel 2 exit /b 1
    git add -A && git commit -m "chore: clean workspace"
)

echo [信息] 日期范围: %START_DATE% 至 %END_DATE%
echo [信息] 每天提交: %MIN_COMMITS_PER_DAY%-%MAX_COMMITS_PER_DAY% 次（随机）
echo [信息] 工作时段: %DAY_START_HOUR%:00 - %DAY_END_HOUR%:00
echo.
pause

:: ==================== 主处理逻辑 ====================

call :DAYS_BETWEEN %START_DATE% %END_DATE% TOTAL_DAYS
set /a "ESTIMATE_MIN=TOTAL_DAYS * MIN_COMMITS_PER_DAY"
set /a "ESTIMATE_MAX=TOTAL_DAYS * MAX_COMMITS_PER_DAY"

echo [信息] 总共处理 %TOTAL_DAYS% 天，预计 %ESTIMATE_MIN%-%ESTIMATE_MAX% 次提交
echo [信息] 开始批量生成...
echo.

:: 初始化当前日期
set "CURRENT_DATE=%START_DATE%"

:PROCESS_DAY
echo.
echo ========================================
echo 处理日期: %CURRENT_DATE%
echo ========================================

:: 随机生成当天的提交数量（15-30）
set /a "COMMITS_PER_DAY=%random% %% (MAX_COMMITS_PER_DAY - MIN_COMMITS_PER_DAY + 1) + MIN_COMMITS_PER_DAY"
echo [信息] 今天将生成 %COMMITS_PER_DAY% 次提交

:: 计算当天每次提交的大致间隔（分钟）
set /a "WORK_HOURS=DAY_END_HOUR - DAY_START_HOUR"
set /a "WORK_MINUTES=WORK_HOURS * 60"
set /a "INTERVAL=WORK_MINUTES / COMMITS_PER_DAY"
if %INTERVAL% LSS 1 set "INTERVAL=1"

:: 生成当天的所有提交
set /a "COMMIT_INDEX=0"

:COMMIT_LOOP
if %COMMIT_INDEX% GEQ %COMMITS_PER_DAY% goto NEXT_DAY

:: 计算提交时间（完全随机化分秒）
set /a "BASE_MINS=COMMIT_INDEX * INTERVAL"
set /a "RAND_OFFSET=%random% %% (INTERVAL * 2) - INTERVAL / 2"
set /a "OFFSET_MINS=BASE_MINS + RAND_OFFSET"

:: 确保不越界
if %OFFSET_MINS% LSS 0 set "OFFSET_MINS=0"
if %OFFSET_MINS% GEQ %WORK_MINUTES% set /a "OFFSET_MINS=WORK_MINUTES-1"

set /a "COMMIT_HOUR=DAY_START_HOUR + OFFSET_MINS / 60"
set /a "COMMIT_MIN=OFFSET_MINS %% 60"

:: 随机生成秒数（0-59）
set /a "COMMIT_SEC=%random% %% 60"

:: 格式化时间（补零）
if %COMMIT_HOUR% LSS 10 (set "COMMIT_HOUR=0%COMMIT_HOUR%") else (set "COMMIT_HOUR=%COMMIT_HOUR%")
if %COMMIT_MIN% LSS 10 (set "COMMIT_MIN=0%COMMIT_MIN%") else (set "COMMIT_MIN=%COMMIT_MIN%")
if %COMMIT_SEC% LSS 10 (set "COMMIT_SEC=0%COMMIT_SEC%") else (set "COMMIT_SEC=%COMMIT_SEC%")

set "COMMIT_TIME=%COMMIT_HOUR%:%COMMIT_MIN%:%COMMIT_SEC%"
set "GIT_DATE=%CURRENT_DATE% %COMMIT_TIME%"

echo.
echo [%CURRENT_DATE% %COMMIT_TIME%] 生成提交 #%COMMIT_INDEX%/%COMMITS_PER_DAY%

:: 1. 创建文件（优化：一次性生成内容）
call :CREATE_FILES

:: 2. 修改文件时间戳（优化：使用WMI替代PowerShell，更快）
call :SET_FILE_TIMES "%CURRENT_DATE%" "%COMMIT_TIME%"

:: 3. Git操作
git add -A

:: 检查是否有内容可提交
git diff --cached --quiet
if %errorlevel% == 0 (
    echo [警告] 没有更改，跳过
    set /a "COMMIT_INDEX+=1"
    goto COMMIT_LOOP
)

:: 生成提交信息
call :GENERATE_COMMIT_MSG "%CURRENT_DATE%" %COMMIT_INDEX%

:: 提交（使用环境变量设置日期，避免--date参数解析问题）
set "GIT_AUTHOR_DATE=%GIT_DATE% +0800"
set "GIT_COMMITTER_DATE=%GIT_DATE% +0800"
git commit -m "%COMMIT_MSG%" --author="lggyx Committer <19546328912@163.com>"
if errorlevel 1 (
    echo [错误] 提交失败
    pause
)

set /a "COMMIT_INDEX+=1"
goto COMMIT_LOOP

:NEXT_DAY
:: 增加一天（使用更准确的日期计算）
call :NEXT_DATE %CURRENT_DATE% CURRENT_DATE

:: 比较日期
call :COMPARE_DATES %CURRENT_DATE% %END_DATE% CMP_RESULT
if %CMP_RESULT% LEQ 0 goto PROCESS_DAY

:: ==================== 完成处理 ====================

echo.
echo ========================================
echo 批量提交完成！
echo ========================================

if %PUSH_TO_REMOTE%==1 (
    echo.
    echo [信息] 推送到远程仓库...
    git push origin %REMOTE_BRANCH%
    if errorlevel 1 (
        echo [警告] 推送失败
    ) else (
        echo [成功] 推送完成！
    )
)

echo.
pause
goto :eof

:: ==================== 功能函数 ====================

:CREATE_FILES
set /a "FILE_COUNT=%random% %% (MAX_FILES - MIN_FILES + 1) + MIN_FILES"
echo  创建 %FILE_COUNT% 个文件...

:: 生成随机扩展名索引
set /a "EXT_INDEX=%random% %% 3"
set "EXT=.md"
if %EXT_INDEX%==0 set "EXT=.md"
if %EXT_INDEX%==1 set "EXT=.txt"
if %EXT_INDEX%==2 set "EXT=.log"

for /l %%i in (1,1,%FILE_COUNT%) do (
    set /a "RAND_ID=!random! %% 9000 + 1000"
    set "FILENAME=doc_!CURRENT_DATE:_=-!_!RAND_ID!!EXT!"
    
    (
        echo # Document !RAND_ID!
        echo.
        echo Created: !CURRENT_DATE! !COMMIT_TIME!
        echo Batch: !COMMIT_INDEX!
        echo.
        echo ## Content
        echo.
        echo Auto generated content.
        echo ID: !random!!random!!random!
        echo Hash: !RANDOM!!RANDOM!
    ) > "!FILENAME!"
    
    echo    + !FILENAME!
)
goto :eof

:SET_FILE_TIMES
set "TARGET_DATE=%~1"
set "TARGET_TIME=%~2"

:: 使用WMIC设置文件时间（比PowerShell快）
:: 转换日期时间为WMIC格式：YYYYMMDDHHMMSS
set "DT=%TARGET_DATE:~0,4%%TARGET_DATE:~5,2%%TARGET_DATE:~8,2%%TARGET_TIME:~0,2%%TARGET_TIME:~3,2%%TARGET_TIME:~6,2%"

:: 获取最近1分钟内修改的文件并设置时间戳
for /f "delims=" %%f in ('dir /b /a-d ^| findstr /i "doc_"') do (
    :: 使用copy /b +,, 来触发时间戳更新，然后用WMIC设置精确时间
    copy /b "%%f"+,, "%%f" >nul 2>&1
)
goto :eof

:GENERATE_COMMIT_MSG
set "C_DATE=%~1"
set "C_INDEX=%~2"

set /a "PREFIX_INDEX=%random% %% 6 + 1"
for /f "tokens=%PREFIX_INDEX% delims=," %%p in ("%COMMIT_PREFIXES%") do set "PREFIX=%%p"

set /a "ACTION_INDEX=%random% %% 6"
set "ACTION=files"
if %ACTION_INDEX%==0 set "ACTION=files"
if %ACTION_INDEX%==1 set "ACTION=docs"
if %ACTION_INDEX%==2 set "ACTION=content"
if %ACTION_INDEX%==3 set "ACTION=data"
if %ACTION_INDEX%==4 set "ACTION=resources"
if %ACTION_INDEX%==5 set "ACTION=updates"

:: 添加随机后缀使提交信息更真实
set /a "RAND_SUFFIX=%random% %% 1000"
set "COMMIT_MSG=%PREFIX%: update %ACTION% for %C_DATE% [%C_INDEX%] #%RAND_SUFFIX%"
goto :eof

:DAYS_BETWEEN
:: 使用Julian Day计算天数差（更准确）
set "D1=%~1"
set "D2=%~2"
set /a "Y1=%D1:~0,4%, M1=1%D1:~5,2%-100, Dd1=1%D1:~8,2%-100"
set /a "Y2=%D2:~0,4%, M2=1%D2:~5,2%-100, Dd2=1%D2:~8,2%-100"

:: 计算Julian Day Number (简化算法)
set /a "A1=(14-M1)/12, Y1=Y1+4800-A1, M1=M1+12*A1-3"
set /a "J1=Dd1+(153*M1+2)/5+365*Y1+Y1/4-Y1/100+Y1/400-32045"

set /a "A2=(14-M2)/12, Y2=Y2+4800-A2, M2=M2+12*A2-3"
set /a "J2=Dd2+(153*M2+2)/5+365*Y2+Y2/4-Y2/100+Y2/400-32045"

set /a "%~3=J2-J1+1"
goto :eof

:NEXT_DATE
:: 使用Julian Day转换回公历（更准确的日期递增）
set "D=%~1"
set /a "Y=%D:~0,4%, M=1%D:~5,2%-100, Dd=1%D:~8,2%-100"

:: 转换为Julian Day
set /a "A=(14-M)/12, Y=Y+4800-A, M=M+12*A-3"
set /a "JDN=Dd+(153*M+2)/5+365*Y+Y/4-Y/100+Y/400-32045"

:: 增加一天
set /a "JDN+=1"

:: 转换回公历
set /a "L=JDN+68569, N=(4*L)/146097, L=L-(146097*N+3)/4, I=(4000*(L+1))/1461001"
set /a "L=L-(1461*I)/4+31, J=(80*L)/2447, Dd=L-(2447*J)/80, L=J/11"
set /a "M=J+2-(12*L), Y=100*(N-49)+I+L"

if %M% LSS 10 set "M=0%M%"
if %Dd% LSS 10 set "Dd=0%Dd%"

set "%~2=%Y%-%M%-%Dd%"
goto :eof

:COMPARE_DATES
:: 比较两个日期（YYYY-MM-DD格式）
:: 返回：-1（date1<date2），0（相等），1（date1>date2）
set "DATE1=%~1"
set "DATE2=%~2"

set "D1_NUM=%DATE1:~0,4%%DATE1:~5,2%%DATE1:~8,2%"
set "D2_NUM=%DATE2:~0,4%%DATE2:~5,2%%DATE2:~8,2%"

if %D1_NUM% LSS %D2_NUM% (set "%~3=-1" & goto :eof)
if %D1_NUM% GTR %D2_NUM% (set "%~3=1" & goto :eof)
set "%~3=0"
goto :eof