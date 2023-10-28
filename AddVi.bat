@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

REM Check if FFmpeg is available in the system path
where ffmpeg > nul 2>&1
if %errorlevel% neq 0 (
    echo FFmpeg is not found in the system path. Please install FFmpeg and make sure it's accessible.
    pause
    exit /b 1
)

REM Prompt the user to input text
set /p "sometext=Enter citation text: "

REM Escape delimiters and quotes in the input text
set "citationtext=!sometext:\=\\!"
set "citationtext=!citationtext::=\\\:!"

REM Check if the input video file is provided
if "%~1"=="" (
    echo Please provide the input video file as an argument.
    pause
    exit /b 1
)

REM Extract the directory path from the input video file
for %%I in ("%~1") do (
    set "output_dir=%%~dpI"
    set "output_filename=%%~nI_Vi.mp4"
)

REM Run FFmpeg with the specified filter and font, saving the output in the same directory
cd %LocalAppData%\Microsoft\Windows\Fonts
ffmpeg -i "%~1" -vf "delogo=x=85:y=47:w=245:h=40:show=0,drawtext=text='!citationtext!':fontfile=NotoSans-Bold.ttf:fontcolor=white:fontsize=30:x=93:y=53:alpha=1" "!output_dir!!output_filename!"

REM Check if FFmpeg command was successful
if %errorlevel% eq 0 (
    echo Video processing complete. Output saved as !output_dir!!output_filename!
) else (
    echo Video processing failed. Check the input file and FFmpeg command.
)

pause
