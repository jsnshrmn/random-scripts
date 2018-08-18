set /P dir=Enter sub-directory: %=%
set /P ext=Enter file extension (.xxx): %=%
mkdir rgb
for %%a in ("%dir%\*.%ext%") do ffmpeg -i %%a -map 0:0 -vcodec qtrle -pix_fmt rgb24  rgb\%%~na-rgb.mov
pause