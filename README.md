# perl-stuff
This repository contains some perl based programs that, at the time, were written to address a general need or function as a learning tool. While not written to the highest of perl coding standards and best practices, they might be useful in one form or another. The larger programs have a fair amount of documentation included in the code. The programs should work with most perl versions. Linux distributions generally include a useable perl version.<br/><br/>
Place the code in a convenient location on your system and use **perl pgm.pl** at the operating system command line to run. Use **cpanm** or **MCPAN** at your OS command line to install any needed perl modules. Use each program's **-h** option to display it's usage text. All programs are provided as-is and function as described. You may need to modify them for the needs of your operating environment.

### OS: Windows
**Mp4ToMp3.pl** - This program extracts the audio track in an MP4 file and converts it to MP3 using ffmpeg. The audio level can be normalized. A seperate install of ffmpeg is needed if not already part of another windows program. Change the $FFmpeg definition in the program to point to the ffmpeg executable.<br/>
**recursiveCopy.pl** - This program was written to load MP3 files to an older USB SanDisk MP3 player. By erasing and reloading all MP3 files on the player each time, it ensures an alphabetical folder/file order when the SanDisk 'Folder' selection is used. As implied by the program name, the code recursively walks the specified staring folder. The -p option creates a playlist in each folder for files with a .mp3 extention.

### OS: Linux
**WallpaperChange.pl** - A program written for RPi4 and Mint to periodically change the desktop image. The program calls the linux pcmanfm file manager to change the image at the CLI specified interval. See the WallpaperChange internal comments for details about program autostart during linux boot. WallpaperChange can also keep the screen display active by using xdotool, if available, to perform a periodic mouse pointer movement in the corner of the screen. One or more picture directories are specified on the startup CLI. With the launch terminal selected, keypad input can be used to manually move between the images.<br/><br/>
**learnReadkey.pl** - This program was written as a learning tool for keyboard input handling and ANSI color/control sequences in general. Term::ReadKey is used to process keyboard input since perl **$resp \= \<STDIN\>** does not handle the keypad escape sequences. Downside is the program must periodically check for user keyboard input. The up and down arrow keys recall previous/next strings from input history. The left and right arrow keys position the cursor for line editing. The backspace and delete keys remove the character at the cursor position. Typing inserts characters at the cursor position. The enter key commits the input for processing and adds it to the input history.<br/><br/>
**WledLibrarian.pl** - A WLED preset librarian used to import, store, and export WLED presets as individual entities in a database. See the dedicated folder for info.

### OS: Linux and Windows
**env.pl** - Displays the %ENV hash environment variables/values that were inherited from the operating system as part of perl program start.<br/>
**bin2hex.pl** - Dumps the specified file contents to the console. Hex and its ASCII equivalent characters are displayed.<br/><br/>
**wled-tool.pl** - This program is used to send and receive data with WLED using its json api interface. Available functions include backup and restore of WLED user settings (configuration, presets, custom palettes), an interactive preset audition function, and a preset data reformatter. The reformat function rearranges and selectively indents the preset data to simplify text editing of a preset backup file. The desired function is specified using one of the program's CLI options. This tool is useful in cases where the WLED GUI is not available.<br/>
**wled-tool-v1.zip** - wled-tool standalone Windows executable, built with perl PAR::Packer. `md5:ad07437f2880481e0bff7f81e8a807ee`<br/><br/>
<img src="wled-screencap.png" alt="screenshot" width="500"/><br/>



