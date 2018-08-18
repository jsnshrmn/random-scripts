set /P file=Enter filename: %=%
set /P strtmin=Enter frame time minutes: %=%
set /P strtsec=Enter frame time in seconds: %=%
set /a strtmin1=%strtmin%*60
set /a strt=%strtmin1%+%strtsec%
set /a end=%strt%+3
set loc=%CD%
mkdir %loc%\%file%-stills


"C:\Program Files (x86)\VideoLAN\VLC\vlc.exe"  "%loc%\%file%" --video-filter=scene --vout=dummy --start-time=%strt% --stop-time=%end% --scene-ratio=1 --scene-prefix=%file%-%strt%- --scene-path=%loc%\%file%-stills\ vlc://quit