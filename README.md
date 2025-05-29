# perl-stuff
This repository contains some perl based programs that, at the time, were written to address a general hobby need or function as a learning tool. While not written to the highest of perl coding standards and best practices, they should be useful in one form or another. The larger programs have a fair amount of documentation included in the code. The programs should work with most perl versions. Linux distributions generally include a useable perl version. My Windows environment uses ActiveState perl 5.16 but Strawberry perl will also work.<br/><br/>
Place the code in a convenient location on your system and use **perl pgm.pl** at the command line to run. Use **cpanm** or **MCPAN** at your OS command line to install any needed perl modules. Use each program's **-h** option to display it's usage text. All programs are provided as-is and function as described. You may need to modify them for the needs of your operating environment.

### wled-tool.pl
**OS: Linux and Windows**<br/>
This program is used to send and receive data with WLED using its json api interface. Available functions include backup and restore of WLED user settings (configuration, presets, custom palettes), an interactive preset audition function, and a preset data reformatter to simplify text editing. The desired function is specified using one of the program's CLI options. Useful in cases where the normal WLED application is not available.

### recursiveCopy.pl
**OS: Windows**<br/>
This program was written to load MP3 files to an older USB SanDisk MP3 player. By erasing and reloading all MP3 files on the player each time, it ensures alphabetical ordering when the SanDisk 'Folder' selection is used. The -p option creates a playlist in each folder for files with a .mp3 extention.

### WallpaperChange.pl
**OS: Linux**<br/>
A program written for the RPi4 that is used to change the desktop image (wallpaper) using linux pcmanfm. It can also keep the screen display active by using xdotool, if available, to perform a periodic mouse pointer movement in the corner of the screen. One or more picture directories are specified on the startup CLI.

### Mp4ToMp3.pl
**OS: Windows**<br/>
This program extracts the audio track in an MP4 file and converts it to MP3 using ffmpeg. The audio level can be normalized. A seperate install of ffmpeg is needed if not already part of another windows program. Change the $FFmpeg definition in the program to point to the ffmpeg executable.

### DnB Model Railroad
**OS: Linux RPi-3**<br/>
An advanced model railroad control program for automating things like block occupancy detection, track signaling, turnout positioning, and reverse loop polarity. Uses forked processes and provides a barebones webserver for operational status display. RPi-3 and hardware 'hats' interface the layout sensors, turnout servos, and signal indicators. Trackside searchlight semaphore signals utilize a custom build 74HC595 shift register hat. Hardware schematics and layout details are included. 

### env.pl
**OS: Linux and Windows**<br/>
Displays the %ENV hash environment variables/values that were inherited from the operating system as part of perl program start. 

### bin2hex.pl
**OS: Linux and Windows**<br/>
Dumps the specified file contents to the console. Hex and its ASCII equivalent characters are displayed.

### DrawPoker.pl
**OS: Linux**<br/>
Proof of concept five card draw poker game. CLI based ANSI color/character cards. Only basic game play is implemented and win/lose checking is incomplete.

### DrawPokerGUI.pl
**OS: Linux and Windows**<br/>
Perl-tk version of five card draw poker program. Uses the GD module for image sizing. More code, more graphics, more better. Yeah, perl-tk; but it works.   
