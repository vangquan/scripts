:: Version 20231028

@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

REM Prompt the user to input text
set /p "sometext=Enter citation text: "

REM Escape delimiters and quotes in the input text
set "citationtext=!sometext:\=\\!"
set "citationtext=!citationtext::=\\\:!"

REM Extract the directory path from the input video file
for %%I in ("%~1") do (
    set "output_dir=%%~dpI"
    set "output_filename=%%~nI_Vi.mp4"
)

REM Run FFmpeg with the specified filter and font, saving the output in the same directory
cd %~dp0
ffmpeg -i "%~1" -vf "delogo=x=85:y=47:w=245:h=40:show=0,drawtext=text='!citationtext!':fontfile=NotoSans-Bold.ttf:fontcolor=white:fontsize=30:x=93:y=53:alpha=0.9" "!output_dir!!output_filename!"

REM Check if FFmpeg command was successful
if %errorlevel% eq 0 (
    echo Video processing complete. Output saved as !output_dir!!output_filename!
) else (
    echo Video processing failed. Check the input file and FFmpeg command.
)

pause
