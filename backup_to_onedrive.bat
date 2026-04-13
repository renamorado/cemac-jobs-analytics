@echo off
setlocal

rem Manual backup from the active local repo to the OneDrive archive copy.
rem Usage:
rem   backup_to_onedrive.bat
rem   backup_to_onedrive.bat selected
rem   backup_to_onedrive.bat full

set "SRC=C:\Users\wb648862\Documents\Projects\CEMAC"
set "DST=C:\Users\wb648862\OneDrive - WBG\Marina Ngoma Mavungu's files - CEMAC jobs analytics"

if "%~1"=="" (
    set "MODE=selected"
) else (
    set "MODE=%~1"
)

if /I "%MODE%"=="selected" goto SELECTED
if /I "%MODE%"=="full" goto FULL

echo Invalid mode. Use "selected" or "full".
exit /b 1

:SELECTED
echo Running SELECTED backup...
robocopy "%SRC%\code" "%DST%\code" /MIR /R:2 /W:2 /FFT /Z
robocopy "%SRC%\docs" "%DST%\docs" /MIR /R:2 /W:2 /FFT /Z
robocopy "%SRC%\manuscript" "%DST%\manuscript" /MIR /R:2 /W:2 /FFT /Z /XF *.aux *.bbl *.bcf *.blg *.fdb_latexmk *.fls *.log *.nav *.out *.run.xml *.snm *.synctex.gz *.toc
robocopy "%SRC%\slides" "%DST%\slides" /MIR /R:2 /W:2 /FFT /Z /XF *.aux *.bbl *.bcf *.blg *.fdb_latexmk *.fls *.log *.nav *.out *.run.xml *.snm *.synctex.gz *.toc
robocopy "%SRC%\output" "%DST%\output" /MIR /R:2 /W:2 /FFT /Z /XD tables figures slides
robocopy "%SRC%" "%DST%" 00_master.do 01_setup.do README.md SESSIONS.md TASKS.md .gitignore backup_to_onedrive.bat config_local_paths_template.do /R:2 /W:2 /FFT /Z
goto END

:FULL
echo Running FULL backup...
robocopy "%SRC%" "%DST%" /MIR /R:2 /W:2 /FFT /Z /XA:SH ^
  /XD .git .codex_tmp .codex_tmp_docx logs scratch tmp ^
  /XF *.log *.smcl *.tmp *.done *.failed
goto END

:END
echo Backup finished with robocopy exit code %ERRORLEVEL%.
echo Review the copied folders before treating the backup as final.
endlocal
exit /b %ERRORLEVEL%
