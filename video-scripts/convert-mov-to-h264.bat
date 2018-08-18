set /P dir=Enter sub-directory: %=%
set /P ext=Enter file extension (.xxx): %=%
set newdir=lossless-mp4
mkdir %newdir%
for %%a in ("%dir%\*.%ext%") do ffmpeg -i %%a -pix_fmt "yuv422p" -vcodec libx264 -preset veryslow -qp 0 -an "%newdir%\%%~na.yuv422p.720x480.lossless.mp4"