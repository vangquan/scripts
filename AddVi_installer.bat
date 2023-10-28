:: Version 20231028

@echo off
setlocal enabledelayedexpansion

:: Suggested installation path
set "suggested_install_path=%userprofile%\AddVi"

:: Ask the user where to install
set /p "install_path=Enter installation path [%suggested_install_path%] (press Enter to accept): "
if "!install_path!"=="" set "install_path=!suggested_install_path!"
set "install_path=!install_path!"

:: Check if the specified directory exists; create it if it doesn't
if not exist "!install_path!" (
    echo Directory does not exist. Creating the directory...
    mkdir "!install_path!"
)

:: Download AddVi.bat
echo Downloading AddVi.bat...
curl -o "!install_path!\AddVi.bat" "https://raw.githubusercontent.com/vangquan/scripts/main/AddVi.bat"

:: Check if the download was successful
if %errorlevel% neq 0 (
    echo Failed to download AddVi.bat. Please check the URL and try again.
    pause
    exit /b 1
)

:: Download NotoSans-Bold.ttf
set "fontPath=%LocalAppData%\Microsoft\Windows\Fonts\NotoSans-Bold.ttf"
if not exist "%fontPath%" (
    echo Downloading NotoSans-Bold.ttf...
    curl -o "%LocalAppData%\Microsoft\Windows\Fonts\NotoSans-Bold.ttf" "https://b.jw-cdn.org/fonts/noto-sans/2.007-edcd458/hinted/NotoSans-Bold.ttf"
) else (
    echo Font NotoSans-Bold.ttf is available in %LocalAppData%\Microsoft\Windows\Fonts.
)

:: Inform the user
echo AddVi.bat has been downloaded to "!install_path!" and NotoSans-Bold.ttf has been installed.

:: Define the temporary directory and FFmpeg download URL
set "temp_dir=%temp%\ffmpeg_temp"
set "ffmpeg_url=https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-essentials.7z"

:: Check if ffmpeg.exe is available
where ffmpeg > nul 2>&1
if %errorlevel% neq 0 (
    echo FFmpeg is not available. Downloading and installing...
    
    :: Create the temporary directory if it doesn't exist
    if not exist "%temp_dir%" mkdir "%temp_dir%"

    :: Download FFmpeg 7z archive
    curl -L -o "%temp_dir%\ffmpeg-git-essentials.7z" "%ffmpeg_url%"
    
    :: Check if the download was successful
    if exist "%temp_dir%\ffmpeg-git-essentials.7z" (
        :: Extract FFmpeg executables from the 7z archive to the temporary directory
        tar -xf "%temp_dir%\ffmpeg-git-essentials.7z" -C "%temp_dir%"
        
        :: Find and copy ffmpeg.exe to the specified installation path
        for /r "%temp_dir%" %%F in (*) do (
            if "%%~nxF"=="ffmpeg.exe" (
                copy "%%F" "%install_path%"
            )
        )
        
        echo FFmpeg has been downloaded and installed to %install_path%
    ) else (
        echo Failed to download FFmpeg.
    )
) else (
    echo FFmpeg.exe is available and ready to run.
)

:: Create a shortcut of AddVi.bat in %APPDATA%\Microsoft\Windows\SendTo
set "sourceFile=%install_path%\AddVi.bat"
set "sendToDir=%APPDATA%\Microsoft\Windows\SendTo"

:: Define the shortcut name
set "shortcutName=AddVi.lnk"

:: Check if the shortcut exists
if exist "!target!" (
    echo Shortcut already exists: "!target!"
    pause
    exit /b 1
)

:: Create the shortcut
set "target=%sendToDir%\!shortcutName!"
echo Set oWS = WScript.CreateObject("WScript.Shell") > "%temp%\CreateShortcut.vbs"
echo sLinkFile = "!target!" >> "%temp%\CreateShortcut.vbs"
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> "%temp%\CreateShortcut.vbs"
echo oLink.TargetPath = "!sourceFile!" >> "%temp%\CreateShortcut.vbs"
echo oLink.Save >> "%temp%\CreateShortcut.vbs"
cscript /nologo "%temp%\CreateShortcut.vbs"
del "%temp%\CreateShortcut.vbs"

:: Inform the user
echo Shortcut created: "!target!"

:: End of the script
pause