set /P dir=Enter sub-directory: %=%
set /P ext=Enter file extension (.xxx): %=%
set newdir=rgb-mp4
set pixfmt=yuv444p
mkdir %newdir%
for %%a in ("%dir%\*.%ext%") do ffmpeg -i %%a -vcodec libx264 -pix_fmt %pixfmt% -preset veryslow -qp 0 -an "%newdir%\%%~na-.mp4
pause