@echo off
setlocal

rem Manual handoff copy from the active local repo to the shared OneDrive copy.
rem
rem Usage:
rem   backup_to_onedrive.bat
rem   backup_to_onedrive.bat dryrun
rem   backup_to_onedrive.bat full
rem   backup_to_onedrive.bat selected
rem
rem Default mode is "full". Copies are non-destructive: destination-only files,
rem including Marina's *_marina* variants, are not deleted.

set "SRC=C:\Users\wb648862\Documents\Projects\CEMAC"
set "DST=C:\Users\wb648862\OneDrive - WBG\Marina Ngoma Mavungu's files - CEMAC jobs analytics"

set "COMMON_OPTS=/E /R:2 /W:2 /FFT /Z /XA:SH"
set "EXCLUDE_DIRS=/XD .git .codex .codex_tmp .codex_tmp_docx logs scratch tmp"
set "EXCLUDE_FILES=/XF *_marina* *.log *.smcl *.tmp *.done *.failed *.aux *.bbl *.bcf *.blg *.fdb_latexmk *.fls *.nav *.out *.run.xml *.snm *.synctex.gz *.toc desktop.ini Thumbs.db"

if "%~1"=="" (
    set "MODE=full"
) else (
    set "MODE=%~1"
)

if /I "%MODE%"=="dryrun" goto DRYRUN
if /I "%MODE%"=="full" goto FULL
if /I "%MODE%"=="selected" goto SELECTED

echo Invalid mode. Use "dryrun", "full", or "selected".
exit /b 1

:DRYRUN
echo Running DRYRUN backup preview...
call :SHOW_MARINA_FILES
robocopy "%SRC%" "%DST%" %COMMON_OPTS% %EXCLUDE_DIRS% %EXCLUDE_FILES% /L
call :FINISH %ERRORLEVEL%
exit /b %ERRORLEVEL%

:FULL
echo Running FULL non-destructive backup...
call :SHOW_MARINA_FILES
robocopy "%SRC%" "%DST%" %COMMON_OPTS% %EXCLUDE_DIRS% %EXCLUDE_FILES%
call :FINISH %ERRORLEVEL%
exit /b %ERRORLEVEL%

:SELECTED
echo Running SELECTED non-destructive backup...
call :SHOW_MARINA_FILES
robocopy "%SRC%\code" "%DST%\code" %COMMON_OPTS% %EXCLUDE_FILES%
call :CHECK_ROBOCOPY %ERRORLEVEL%
if %ERRORLEVEL% GEQ 8 exit /b %ERRORLEVEL%
robocopy "%SRC%\docs" "%DST%\docs" %COMMON_OPTS% %EXCLUDE_FILES%
call :CHECK_ROBOCOPY %ERRORLEVEL%
if %ERRORLEVEL% GEQ 8 exit /b %ERRORLEVEL%
robocopy "%SRC%\manuscript" "%DST%\manuscript" %COMMON_OPTS% %EXCLUDE_FILES%
call :CHECK_ROBOCOPY %ERRORLEVEL%
if %ERRORLEVEL% GEQ 8 exit /b %ERRORLEVEL%
robocopy "%SRC%\slides" "%DST%\slides" %COMMON_OPTS% %EXCLUDE_FILES%
call :CHECK_ROBOCOPY %ERRORLEVEL%
if %ERRORLEVEL% GEQ 8 exit /b %ERRORLEVEL%
robocopy "%SRC%" "%DST%" 00_master.do 01_setup.do README.md SESSIONS.md TASKS.md .gitignore backup_to_onedrive.bat config_local_paths_template.do /R:2 /W:2 /FFT /Z
call :FINISH %ERRORLEVEL%
exit /b %ERRORLEVEL%

:SHOW_MARINA_FILES
echo Destination files matching *_marina* are preserved by this script:
dir /B /S "%DST%\*_marina*" 2>nul
exit /b 0

:CHECK_ROBOCOPY
set "ROBO_RC=%~1"
if %ROBO_RC% GEQ 8 (
    echo Robocopy failed with exit code %ROBO_RC%.
    exit /b %ROBO_RC%
)
exit /b 0

:FINISH
set "ROBO_RC=%~1"
if %ROBO_RC% GEQ 8 (
    echo Backup failed with robocopy exit code %ROBO_RC%.
    endlocal
    exit /b %ROBO_RC%
)

echo Backup finished with robocopy exit code %ROBO_RC%.
echo Robocopy exit codes 0 through 7 are nonfatal success or warning states.
echo Review the copied folders before treating the backup as final.
endlocal
exit /b 0
