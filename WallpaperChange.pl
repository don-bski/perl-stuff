#!/usr/bin/perl
# ==============================================================================
# FILE: WallpaperChange.pl                                            4-11-2025
#
# SERVICES: Stay Awake and Wallpaper Changer.  
#
# DESCRIPTION:
#   This program is written for the RPi4 and is used to change the desktop
#   image (wallpaper) as specified by the -i and -f options. It also keeps
#   the screen display active by performing a periodic mouse pointer movement
#   in the corner of the screen.
#
#   Use the following to add a desktop GUI menu item for launching the program.
#   When started by the GUI, the user's home directory is set as the working
#   directory. e.g. /home/pi
#
#   1. In GUI menu bar select: Raspberry -> Preferences -> Main Menu Editor
#   2. In left pane, select the desired group. e.g. Programming
#   3. In right pane, select: New Item.
#   4. Enter menu item Name. e.g. Wallpaper Change
#   5. Enter the following into the Command box. It should be a single line
#      with no extra spaces or # characters. Adjust the program directory
#      path for actual location as needed.
#  
#      lxterminal --geometry=50x5 -t 'Wallpaper Change' -l -e '/usr/bin/pe
#      rl /home/pi/perl5/WallpaperChange.pl -n'
#
#   For XFCE use:
#      xfce4-terminal --geometry=50x5 -T 'Wallpaper Change' -e '/usr/bin/pe
#      rl /home/don/perl/WallpaperChange.pl -n -x'
#
#   6. Click OK. Highlight the new entry and use the Up/Down controls to 
#      position entry as desired, and then click OK. Close menu editor.
#   7. In user's home directory, e.g. /home/pi, use a text editor to create
#      .WallpaperChange.images file as detailed in program help.
#
#   To autostart the program at GUI launch, the file WallpaperChange.desktop
#   is created in /home/pi/.config/autostart. One of the two Exec statements
#   must be uncommented. The Exec containing 'lxterminal' launches the program
#   in a small terminal that is accessible via the task bar. When selected, the
#   keyboard arrow key image positioning functions can be used. The other Exec
#   command just runs the program in the background.
# 
#   The WallpaperChange.desktop file contains the following.
#
#   [Desktop Entry]
#   Name=Wallpaper Change
#   Comment=Perl based desktop wallpaper changer written by Don
#   Categories=GNOME;GTK;Utility;
#   #Exec=/usr/bin/perl /home/pi/perl5/WallpaperChange.pl
#   #Exec=lxterminal --geometry=50x5 -t 'Wallpaper Change' -l -e '/usr/bin/perl 
#         /home/pi/perl5/WallpaperChange.pl -n'
#   Terminal=false
#   Type=Application
#   StartupNotify=false
#
#   For XFCE autostart, use the 'Settings -> Sessions and Startup ->
#   Application Autostart panel.
#
#   Important perl module issue:
#   After adding Term::ReadKey, this program failed to locate the module when
#   the desktop GUI menu was used for launch. The program launched successfully
#   from a desktop opened terminal session. Term::ReadKey was installed using
#   cpanm. Found that the path to the Term::ReadKey perl module was not present
#   in @INC for the menu bar launch. To correct this, the Term::ReadKey module
#   was installed with 'sudo apt install libterm-readkey-perl'. This install 
#   placed the module in /usr/lib/aarch64-linux-gnu/perl5/ instead of a user 
#   account local directory.
#
# PERL VERSION:  5.28.1
# ==============================================================================
use Getopt::Std;
use Term::ANSIColor;
use Term::ReadKey;
use Time::HiRes qw(sleep);

BEGIN {
   use Cwd;
   our ($ExecutableName) = ($0 =~ /([^\/\\]*)$/);
   our $WorkingDir = cwd();
   if (length($ExecutableName) != length($0)) {
      $WorkingDir = substr($0, 0, rindex($0, "/"));
   }
   unshift (@INC, $WorkingDir);
}

# ==============================================================================
# Global Variables
$Pcmanfm = '/usr/bin/pcmanfm';      # Utility tool to set desktop image.
$Xfconf = '/usr/bin/xfconf-query';  # XFCE tool to set desktop image.
$Xdotool = '/usr/bin/xdotool';      # Utility tool for moving mouse pointer.
$Mpstat = '/usr/bin/mpstat';        # Utility tool for CPU usage.
$Interval = 30;                     # -i image change interval in seconds.
$MouseInterval = 180;               # -t mouse move interval in seconds.
$CpuIdle = 50;                      # Default CPU idle for image change.
$ImageFiles = "WallpaperChange.images";     # Image configuration file.
$LastImageNameFile = ".WallpaperChange";    # File holding last image used.
$LastImageName = '';                # Last image used.
@ImageNameArray = ();               # Image name working list.
$ImageStep = -1;                    # Location in image list.
%DisplayGeometry = ();              # Display geometry working hash.
$MousePosX = 0;                     # Current mouse X screen position.
$MousePosY = 0;                     # Current mouse Y screen position.

$UsageText = (qq(
===== Help for $ExecutableName ================================================

GENERAL DESCRIPTION
   This program is written for the RPi4 and is used to change the desktop
   image (wallpaper). The linux pcmanfm program is called to affect the 
   actual desktop image change. One or more file names or directories are
   specified using the -f option. The -i option specifies the image change
   interval.
   
   Image files are added to a working list in the order specified. When a
   directory of image files is specified, the file names from the directory
   are read, sorted alphabetically, and then added to the working list. The
   working list is then accessed sequentially. Each image file or drectory
   entry should include a directory path.
   
   While running, the program accepts keyboard input to reposition the image
   display point within the working list. The corresponding image will then
   be immediately displayed.
   
      <   left arrow       previous image
      >   right arrow      next image
      ^   up arrow         previous 5th image
      v   down arrow       next 5th image
      <<  page up          previous 10th image
      >>  page down        next 10th image
      |<  home             1st image in working list
      >|  end              last image in working list
          keypad 5         pause/resume image changes
          keypad 0         Reload image names into working list
          keypad .         Redisplay current image
          keypad /         Display current image name
          keypad +         Increase change interval 5 seconds
          keypad -         Deccrease change interval 5 seconds
          enter            Minimize program window

   If the linux xdotool program is available, auto-minimize and stay-awake
   functions are used to prevent the screen display from entering sleep mode.
   A small mouse movement in the lower right corner of the screen is done
   when no user mouse movement is detected for -m seconds. A -m 0 value can
   be used to disable the stay-awake functionality.
   
   This program can be terminated using the linux taskbar or Ctrl+C in the
   terminal session. When terminated, the current image name is saved in 
   .WallpaperChange file. When this program is next started, the file is
   read to resume the display sequence at the next image.

USAGE:
   $ExecutableName  [-h] [-d] [-n] [-r] [-i <sec>] [-f <file> [,<dir>,<file>]]
                       [-x] [-t] [-m <sec>] [-c <pct>] 

   -h             Displays program usage text.
   
   -d             Run in debug mode.
   
   -n             Displays the image step in the terminal.
   
   -x             Use XFCE desktop background changer instead of pcmanfm.
   
   -t             Use top right corner for mouse pointer movement. Default is
                  lower right corner. 
   
   -i <sec>       Image update interval in seconds. Maximum interval 86400
                  seconds (1 day). Default 30.
   
   -f <file>      File(s) or directory(s) of images to use. Seperate multiple
                  entries with comma. No default.
                 
                  Instead of the -f option, image files or directories can be
                  specified using the container file WallpaperChange.images.
                  Its content must be formatted one image file or directory 
                  per line. If present in the program start directory, it is
                  read during program start when the -f option is not used.
                  
                  WallpaperChange.images file can also be specified using the
                  -f option. This facilitates other container file names and
                  those not located in the program start directory.
   
   -r             Enable directory recursion. Includes image names located in
                  any subdirectories of the specified input directory(s).  
                
   -m <sec>       Stay-awake idle mouse pointer time in seconds. Default 180.
   
   -c <pct>       Image changes are inhibited for the current interval when 
                  the CPU idle percentage drops below the default value of 50.
                  This helps minimize the impact to other running applications.
                  The -c option is used to specify a different value (1-99).
                  The linux mpstat command must be available on the system.
                 
EXAMPLES:
   $ExecutableName
      Run using program defaults. Image file names are obtained from the
      WallpaperChange.images file. Images are changed at 30 second intervals.
      The mouse pointer is moved at 180 second intervals in the lower left
      corner of the screen.

   $ExecutableName -f /home/pi/Pictures/disney -i 20 -t -m 300 -n
      Load images from the specified directory and change every 20 seconds.
      The mouse pointer is moved at 300 second intervals in the upper right
      corner of the screen. The image step is displayed in the terminal 
      session window.

===============================================================================
));

# =============================================================================
# FUNCTION:  ReadFile
#
# DESCRIPTION:
#    This routine reads the specified file into the specified array.
#
# CALLING SYNTAX:
#    $result = &ReadFile($InputFile, \@Array, "noTrim");
#
# ARGUMENTS:
#    $InputFile      File to read.
#    \@Array         Pointer to array for the read records.
#    $Option         'notrim' suppresses input line cleanup.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ReadFile {
   my($InputFile, $ArrayPointer, $Option) = @_;
   my($FileHandle);

   unless (-e $InputFile) {
      &ColorMessage("*** Error: File not found: $InputFile", "BRIGHT_RED");
      return 1;
   }
   unless (open($FileHandle, '<', $InputFile)) {
      &ColorMessage("*** Error: opening file for read: $InputFile - $!",
                    "BRIGHT_RED");
      return 1;
   }
   @$ArrayPointer = <$FileHandle>;
   close($FileHandle);
   unless ($Option =~ m/notrim/i) {
      foreach my $line (@$ArrayPointer) {
         chomp($line);
         $line =~ s/^\s+|\s+$//g;
      }   
   }
   return 0;
}

# =============================================================================
# FUNCTION:  WriteFile
#
# DESCRIPTION:
#    This routine writes the specified array to the specified file. If the file
#    already exists, it is deleted.
#
# CALLING SYNTAX:
#    $result = &WriteFile($OutputFile, \@Array, "Trim");
#
# ARGUMENTS:
#    $OutputFile     File to write.
#    $Array          Pointer to array of records to write.
#    $Trim           Trim records before writing to file.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub WriteFile {
   my($OutputFile, $OutputArrayPointer, $Trim) = @_;
   my($FileHandle);
   
   unlink ($OutputFile) if (-e $OutputFile);

   unless (open($FileHandle, '>', $OutputFile)) {
      &ColorMessage("*** Error: opening file for write: $OutputFile - $!",
                    "BRIGHT_RED");
      return 1;
   }
   foreach my $line (@$OutputArrayPointer) {
      if ($Trim ne '') {
         chomp($line);
         $line =~ s/^\s+|\s+$//g;
      }   
      unless (print $FileHandle $line, "\n") {
         &ColorMessage("*** Error: writing file: $OutputFile - $!", "BRIGHT_RED");
         close($FileHandle);
         return 1;
      }
   }
   close($FileHandle);
   return 0;
}

# =============================================================================
# FUNCTION:  ColorMessage
#
# DESCRIPTION:
#    Displays a message to the user. If specified, an input parameter provides
#    coloring the message text. Specify 'use Term::ANSIColor' in the perl script
#    to define the ANSIcolor constants.
#
#    Color constants defined by Term::ANSIColor include:
#
#    CLEAR            RESET              BOLD             DARK
#    FAINT            ITALIC             UNDERLINE        UNDERSCORE
#    BLINK            REVERSE            CONCEALED
#  
#    BLACK            RED                GREEN            YELLOW
#    BLUE             MAGENTA            CYAN             WHITE
#    BRIGHT_BLACK     BRIGHT_RED         BRIGHT_GREEN     BRIGHT_YELLOW
#    BRIGHT_BLUE      BRIGHT_MAGENTA     BRIGHT_CYAN      BRIGHT_WHITE
#  
#    ON_BLACK         ON_RED             ON_GREEN         ON_YELLOW
#    ON_BLUE          ON_MAGENTA         ON_CYAN          ON_WHITE
#    ON_BRIGHT_BLACK  ON_BRIGHT_RED      ON_BRIGHT_GREEN  ON_BRIGHT_YELLOW
#    ON_BRIGHT_BLUE   ON_BRIGHT_MAGENTA  ON_BRIGHT_CYAN   ON_BRIGHT_WHITE
#
#    Space seperate multiple constants. e.g. BOLD BLUE ON_WHITE
#  
# CALLING SYNTAX:
#    $result = &ColorMessage($Message, $Color);
#
# ARGUMENTS:
#    $Message         Message to be output.
#    $Color           Optional color attributes to apply.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub ColorMessage {
   my($Message, $Color) = @_;

   if ($Color ne '') {
      print STDOUT colored($Message . "\n", $Color);
   }
   else {
      print STDOUT $Message, "\n";
   }
   return 0;
}

# =============================================================================
# FUNCTION:  Ctrl_C
#
# DESCRIPTION:
#    This routine is used to perform final functions at program termination. 
#    The main code sets mutiple linux signal events to run this handler. 
#
#    For WallpaperChange.pl, this handler saves the currently displayed image
#    name to a file. The file is read on subsequent program startup to resume 
#    image display at the previous position.  
#
# CALLING SYNTAX:
#    None.
#
# ARGUMENTS:
#    None.
#
# RETURNED VALUES:
#    None.
#
# ACCESSED GLOBAL VARIABLES:
#    $opt_n, $LastImageNameFile, $LastImageName
# =============================================================================
sub Ctrl_C {
   my(@array) = $LastImageName;
   my($result) = &WriteFile($LastImageNameFile, \@array, "Trim");
   print "\n" if (defined($opt_n));   # Cleanup terminal output.
   ReadMode('normal');                # Restore normal terminal input.
   sleep .5;
   exit(0);
}

# =============================================================================
# FUNCTION:  PromptExit
#
# DESCRIPTION:
#    This routine prompts the user for exit confirmation. It is used in
#    situations where preceeding message text might not be seen by the user.
#    For example, a terminal opened by the desktop menu bar.
#
# CALLING SYNTAX:
#    &PromptExit($Exitcode);
#
# ARGUMENTS:
#    $Exitcode        Optional program exit code.
#
# RETURNED VALUES:
#    None
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub PromptExit {
   my($Exitcode) = @_;
   $Exitcode = 0 unless ($Exitcode);
   
   ReadMode('normal');           # Restore normal terminal input.
   print STDOUT "\nPress ENTER key to exit. ";
   STDOUT->autoflush(1);
   <STDIN>;
   exit($Exitcode);
}

# =============================================================================
# FUNCTION:  GetCpuUsage
#
# DESCRIPTION:
#    This routine is a wrapper for the mpstat command. It returns the requested
#    CPU usage value to the caller. This subroutine uses the mpstat command to 
#    get the CPU usage data. This command must be manually installed using 
#    apt-get on most linux distributions. Any error returns a value of zero (0).
#
#    The following usage percentages are available:
#
#    USER        Running at the user (application) level.
#    NICE        Rrunning at the nice priority.
#    SYSTEM      Running at the system (kernel) level.
#    IOWAIT      Waiting for outstanding disk I/O.
#    IRQ         Servicing hardware interrupts.
#    SOFT        Servicing software interrupts.
#    STEAL       Waiting for hypervisor (virtual CPU environment).
#    GUEST       Running a virtual CPU processor.
#    GNICE       Running as a niced guest.
#    IDLE        Idle. 
#
# CALLING SYNTAX:
#    $result = &GetCpuUsage($Mpstat, $Attribute);
#
# ARGUMENTS:
#    $Mpstat         mpstat program.
#    $Attribute      Requested usage value.
#
# RETURNED VALUES:
#    -1 = No mpstat command, <value> = New Input.
#
# ACCESSED GLOBAL VARIABLES:
#    $opt_d
# =============================================================================
sub GetCpuUsage {
   my($Mpstat, $Attribute) = @_;
   my($result, $attr, @mpstats);
   my($value) = 0;
   my (%attrColumn) = (
      'user' => 2, 'nice' => 3, 'system' => 4, 'iowait' => 5, 'irq' => 6,
      'soft' => 7, 'steal' => 8, 'guest' => 9, gnice => 10, 'idle' => 11
   );
   
   $attr = lc $Attribute;
   &ColorMessage("GetCpuUsage - $Mpstat '$attr'", "CYAN") if (defined($opt_d));
   if (exists $attrColumn{$attr}) {
      if ($Mpstat ne '') {
         $result = `$Mpstat --dec=0 1 1| tail -1`;   # No decimals in value
         chomp($result);
         $result =~ s/\s+/ /g;
         @mpstats = split(' ', $result);
         $value = $mpstats[$attrColumn{$attr}];
         &ColorMessage("GetCpuUsage - mpstats: @mpstats   column: $attrColumn{$attr}" .
                       "   value: $value", "CYAN") if (defined($opt_d));
      }
      else {
         &ColorMessage("*** GetCpuUsage mpstat unspecified.", "BRIGHT_RED");
      }
   }
   else {
      &ColorMessage("*** GetCpuUsage unsupported: $attr", "BRIGHT_RED");
   }
   return $value;
}   

# =============================================================================
# FUNCTION:  GetKeypadInput
#
# DESCRIPTION:
#    This routine is used to check for and read keypad related user input. 
#    Keypad input is any keyboard key that returns a byte sequence that starts
#    with the value 27. Refer to the ProcessKeyInput subroutine for a description
#    of these sequences.
#
#    This subroutine uses the Term::ReadKey module to read keyboard input. Use
#    ReadMode('cbreak') in the main code to enable processing. This setting is
#    applied to the terminal session that was used to launched this program. 
#    Use ReadMode('normal') to restore default settings at program exit or
#    abnormal termination.
#
# CALLING SYNTAX:
#    $result = &GetKeypadInput($CharSeqPtr);
#
# ARGUMENTS:
#    $CharSeqPtr      Pointer to character sequence variable.
#
# RETURNED VALUES:
#    0 = No input,  1 = Error, 2 = New Input.
#
# ACCESSED GLOBAL VARIABLES:
#    $opt_d
# =============================================================================
sub GetKeypadInput {
   my($CharSeqPtr) = @_;

   my $char = ReadKey(-1);
   
   # Accepted single keys; Enter / + - 
   if (ord($char) == 10 or ord($char) == 47 or ord($char) == 43 or
       ord($char) == 45) {
      $$CharSeqPtr = ord($char);
      &ColorMessage("GetKeypadInput: $$CharSeqPtr", "CYAN") if (defined($opt_d));
      return 2;
   }
   
   # Escape sequence keys.
   if (ord($char) == 27) {
      my(@charBuf) = ord($char);
      while (defined($char = ReadKey(-1))) {    # Get remaining bytes.
         push (@charBuf, ord($char));
      }
      if ($#charBuf >= 2 and $#charBuf <= 3) {   # Expected sequence length?
         $$CharSeqPtr = join('', @charBuf);
         &ColorMessage("GetKeypadInput: $$CharSeqPtr", "CYAN") if (defined($opt_d));
         return 2;
      }
   }
   
   # Discard any other keys
   while (defined($char = ReadKey(-1))) {};
   $$CharSeqPtr = '';
   return 0;
}

# =============================================================================
# FUNCTION:  ProcessKeyInput
#
# DESCRIPTION:
#    This routine is used to process user keyboard input to change position
#    within the working list. Since &DisplayNextImage increments ImageStep
#    prior to use, the adjustment value takes this into account.
#
#    The following keys are processed. Reload image names, keypad 0, enter
#    are handled by the caller.
#
#       Key              Action                      Bytes
#       ---------        ---------------             --------  
#       up arrow         previous 5th image          27 91 65
#       down arrow       next 5th image              27 91 66
#       right arrow      next image                  27 91 67
#       left arrow       previous image              27 91 68
#       end              last image in list          27 91 70
#       home             1st image in list           27 91 72
#       page up          previous 10th image         27 91 53 126
#       page down        next 10th image             27 91 54 126
#       keypad 5         pause/resume                27 91 69
#       keypad 0 (ins)   Reload image names          27 91 50 126
#       keypad . (del)   Redisplay current image     27 91 51 126
#       enter            Minimize program window     10
#       /                Display current image name  47
#       +                Interval time +5 seconds    43
#       -                Interval time -5 seconds    45
#
# CALLING SYNTAX:
#    $result = &ProcessKeyInput($CharSeq, \$RunModePtr, \$ImageStepPtr, 
#                               \@ImageNameArray);
#
# ARGUMENTS:
#    $CharSeq          Keypress byte sequence.
#    $RunModePtr       Pointer to program runMode variable.
#    $ImageStepPtr     Pointer to current image step.     
#    $ImageNameArray   Pointer to ImageNameArray.
#
# RETURNED VALUES:
#    0 = ImageStep updated,  1 = Error,  2 = Keypad 0,  3 = Ignore
#
# ACCESSED GLOBAL VARIABLES:
#    $opt_d
# =============================================================================
sub ProcessKeyInput {
   my($CharSeq, $RunModePtr, $ImageStepPtr, $ImageNameArray) = @_;

   # Keys handled by main: Enter, Keypad 0.
   return 2 if ($CharSeq eq '10' or $CharSeq eq '279150126' or $CharSeq eq '47' or
                $CharSeq eq '43' or $CharSeq eq '45');  

   # Pause/resume (keypad 5) processing.
   if ($CharSeq eq '279169') {   # pause/resume keypad 5 ?
      STDOUT->autoflush(1);
      if ($$RunModePtr eq 'paused') {   # if currently paused
         $$RunModePtr = 'run';
         print "\b" x 30 . " " x 30 . "\b" x 30;
      }
      else {
         $$RunModePtr = 'paused';
         print " \033[5m* paused *\033[0m Keypad 5 to resume";
      }
      STDOUT->autoflush(0);
      return 3;                  # Don't change desktop image.
   }
      
   # Create new ImageStep value relative to the current. The hash key is the
   # concatenation of the CharSeq bytes. The 'home' and 'end' sequences set
   # an absolute start/end value for @ImageNameArray. 
   my(%decode) = (
      '279165' => $$ImageStepPtr -6, '279166' => $$ImageStepPtr +4,
      '279167' => $$ImageStepPtr, '279168' => $$ImageStepPtr -2,
      '279172' => -1, '279170' => $#$ImageNameArray -1,
      '279153126' => $$ImageStepPtr -11, '279154126' => $$ImageStepPtr +9,
      '279151126' => $$ImageStepPtr -1
   );
      
   if (exists($decode{$CharSeq})) {
      $$ImageStepPtr = $decode{$CharSeq};

      # Handle wrap around conditions.
      if ($$ImageStepPtr < -1) {
         $$ImageStepPtr = $#$ImageNameArray + $$ImageStepPtr + 1;
      }
      elsif ($$ImageStepPtr > $#$ImageNameArray) {
         $$ImageStepPtr = $$ImageStepPtr - $#$ImageNameArray;
      }
      &ColorMessage("ProcessKeyInput: $$ImageStepPtr", "CYAN") if (defined($opt_d));
   }
   else {
      &ColorMessage("*** ProcessKeyInput unsupported key: $CharSeq", "BRIGHT_RED");
      return 3;
   }
   return 0;
}   

# =============================================================================
# FUNCTION:  GetDisplayGeometry
#
# DESCRIPTION:
#    Loads the display geometry into the specified hash. ScreenWidthMax and
#    ScreenHeightMax are used by the MoveMousePointer routine.
#
# CALLING SYNTAX:
#    $result = &GetDisplayGeometry($Xdotool, \%DisplayGeometry);
#
# ARGUMENTS:
#    $Xdotool             xdotool program.
#    $DisplayGeometry     Pointer to working hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    $opt_d
# =============================================================================
sub GetDisplayGeometry {
   
   my($Xdoltool, $DisplayGeometry) = @_;

   my($result) = `$Xdotool getdisplaygeometry`;
   if ($result =~ m/(\d+)\s(\d+)/) {
      $$DisplayGeometry{ScreenWidthMax} = $1;
      $$DisplayGeometry{ScreenHeightMax} = $2;
   }
   else {
      &ColorMessage("*** Error: Can't determine screen size from: $result",
                    "BRIGHT_RED");
      return 1;
   }
   return 0;
}

# =============================================================================
# FUNCTION: FilenamesFromDir
#
# DESCRIPTION:
#    This function retrieves file names from the specified directory that match
#    the specified file name extension(s). Multiple file name extensions must
#    be seperated by the verticle bar character. |
#
#    Subdirectories are processed if the 'recursive' option is specified.
#
# CALLING SYNTAX:
#    $result = &FilenamesFromDir($Directory, $Extension, \@Array, $Option);
#
# ARGUMENTS:
#    $Directory        Directory to be processed.
#    $Extension        File name extensions. e.g. jpg|png
#    $ArrayPtr         Pointer to array for output records.
#    $Option           Not null = recursive
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub FilenamesFromDir {
   my($Directory, $Extension, $ArrayPtr, $Option) = @_;
   my($dh, $result, $subdir, @subdirList);

   # Get matching file names from directory.
   push (@$ArrayPtr, sort grep {/\.($Extension)$/i} glob ("$Directory/*"));
   
   # If recursive, check for subdirectories and process.
   if ($Option ne '') {  
      unless (opendir($dh, $Directory)) {
         &ColorMessage("*** Error: opening directory: $Directory - $!", "BRIGHT_RED");
         return 1;
      }
      @subdirList = grep {-d "$Directory/$_" && ! /^\.{1,2}$/} readdir($dh);
      closedir($dh);
      if ($#subdirList >= 0) {    # Process subdirectories.
         foreach my $dir (@subdirList) {
            $subdir = join("/", $Directory, $dir);
            return 1 if (&FilenamesFromDir($subdir, $Extension, $ArrayPtr, $Option));
         }
      }
   }
   return 0;
}

# =============================================================================
# FUNCTION:  LoadFilenames
#
# DESCRIPTION:
#    Loads the image file names into the specified array. If directory(s) are
#    specified, the image file names, determined by filename extension, in each 
#    directory are loaded.
#
#    Global variable $opt_r is used to set the $Options parameter in the call
#    to FilenamesFromDir.
#
#    Image file names may contain characters that are meaningful to the linux
#    shell. This will cause unintended results when used by the &DisplayNextImage
#    subroutine. The most commonly encountered special characters are escaped. 
#
# CALLING SYNTAX:
#    $result = &LoadFilenames($ImageFiles, \@ImageNameArray);
#
# ARGUMENTS:
#    $ImageFiles       Filename(s) and Directory(s) to process.
#    $ImageNameArray   Pointer to working array to load.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    $opt_d, $opt_r
# =============================================================================
sub LoadFilenames {
   my($ImageFiles, $ImageNameArray) = @_;
   my(@fileNames, @entryList);
   my($returnCode) = 0;

   # Get list of files and/or directories to process.
   if ($ImageFiles =~ m/^WallpaperChange.images$/) {
      return 1 if (&ReadFile($ImageFiles, \@entryList, ''));
   }
   else {
      @entryList = split(",", $ImageFiles);
   }

   # Load working array.
   @$ImageNameArray = ();
   foreach my $entry (@entryList) {
      $entry =~ s/^\s+|\s+$//g;
      next if ($entry eq '' or $entry =~ m/^#/);
      if (-e $entry) {
         if (-d $entry) {
            return 1 if (&FilenamesFromDir($entry, 'jpg|jpeg|png', 
                         $ImageNameArray, $opt_r));
         }
         else {
            push (@$ImageNameArray, $entry);
         }
      }
      else {
         &ColorMessage("*** Error: '$entry' not found.", "BRIGHT_RED");
         $returnCode = 1;
      }
   }

   # Adjust file names that contain special characters. Preceed each
   # occurance with the escape character \.   
   foreach my $entry (@$ImageNameArray) {
      &ColorMessage("LoadFilenames: $entry", "CYAN") if (defined($opt_d));
      $entry =~ s/([ "'`<>\+\*\?\$\|\(\)])/\\$1/g;
   }       
   return $returnCode;
}

# =============================================================================
# FUNCTION:  DisplayNextImage
#
# DESCRIPTION:
#    Changes the desktop to the next sequential image. The $ImageStep variable
#    is updated to the new @ImageNameArray position. The -x option ($opt_x) 
#    specifies which image tool is referenced by $Imagetool.
#
#    If the potential next image file does not exist, e.g. user deleted while
#    WallpaperChange.pl program is running, the entry will be removed from
#    the current @ImageNameArray contents.
#
# CALLING SYNTAX:
#    $result = &DisplayNextImage($Imagetool $ImageFiles, \$ImageStepPtr,
#                                \@ImageNameArray);
#
# ARGUMENTS:
#    $Imagetool        Program to use. pcmanfm or xfconf-query.
#    $ImageFiles       Image file list, used for reload.
#    $ImageStepPtr     Pointer to current image step.     
#    $ImageNameArray   Pointer to ImageNameArray.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    $opt_d, $opt_n, $opt_x
# =============================================================================
sub DisplayNextImage {
   my($Imagetool, $ImageFiles, $ImageStepPtr, $ImageNameArray) = @_;
   my($size, $step, $end, $args);
   my($nextImage) = '';
      
   # Update step to next image. Reload image names to pickup any that were added 
   # while running if we've looped around to the beginning.
   $$ImageStepPtr += 1;
   if ($$ImageStepPtr > $#$ImageNameArray) {
      $$ImageStepPtr = 0;
      return 1 if (&LoadFilenames($ImageFiles, $ImageNameArray));
   }

   # Get the next image file name. Remove entry if file doesn't exist.
   while ($nextImage eq '') {         
      if (-e $$ImageNameArray[$$ImageStepPtr]) {
         $nextImage = $$ImageNameArray[$$ImageStepPtr];
      }
      else {
         splice(@$ImageNameArray, $$ImageStepPtr, 1);
         if (scalar(@$ImageNameArray) == 0) {
            &ColorMessage("*** DisplayNextImage no ImageNameEntries after splice.",
                          "BRIGHT_RED");
            return 1;
         }
         $$ImageStepPtr = 0 if ($$ImageStepPtr > $#$ImageNameArray);
      }
   }
   &ColorMessage("DisplayNextImage: $nextImage", "CYAN") if (defined($opt_d));
   
   # Display the current step number on the terminal if enabled.
   if (defined($opt_n)) {
      $end = scalar @$ImageNameArray;
      $size = length($end);
      $step = $$ImageStepPtr +1;
      STDOUT->autoflush(1);
      printf("\rStep %${size}d of $end", $step);
      STDOUT->autoflush(0);
   }

   # Display the new image.
   if (defined($opt_x)) {     # XFCE environment?
	  $args = join(' ', '-c', 'xfce4-desktop', '-p', 
	               '/backdrop/screen0/monitorLVDS/workspace0/last-image', '-s');
      my($result) = `$Imagetool $args $nextImage`;
   }
   else {
      my($result) = `$Imagetool -w $nextImage`;
   }
   
   if (($? >> 8) != 0) {
      &ColorMessage("*** DisplayNextImage $Imagetool error. $result" .
                    "  Suppressed image: $nextImage", "BRIGHT_RED");
      splice(@$ImageNameArray, $$ImageStepPtr, 1);  # Remove from working list.
   }
   
   return 0;
}

# =============================================================================
# FUNCTION:  MoveMousePointer
#
# DESCRIPTION:
#    This routine is called to move the mouse pointer. Pointer movement will
#    reset the OS sleep timeout associated with the display screen. Positioning
#    is performed only if the pointer position has not changed since last check.
#    This helps prevent interference with other inprogress user activities.
#    Positioning is confined to the lower right corner of the screen. 
#
# CALLING SYNTAX:
#    $result = &MoveMousePointer($Xdotool, \$MousePosX, \$MousePosY, 
#                                \%DisplayGeometry);
#
# ARGUMENTS:
#    $Xdotool           xdotool program.
#    $MousePosX         Pointer to last known X position.     
#    $MousePosY         Pointer to last known Y position.
#    $DisplayGeometry   Pointer to DisplayGeometry hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    $opt_t
# =============================================================================
sub MoveMousePointer {
   my($Xdotool, $MousePosX, $MousePosY, $DisplayGeometry) = @_;
   my($result, $posX, $posY);

   # Get the current position. Pointer may have been moved by the user.
   $result = `$Xdotool getmouselocation`;
   if ($result =~ m/x:(\d+) y:(\d+) screen/) {
      $posX = $1;
      $posY = $2;
   }
   
   # If same pointer position, move to a new position.
   if ($$MousePosX == $posX and $$MousePosY == $posY) {
      if ($$DisplayGeometry{ScreenWidthMax} == $posX) {
         $posX = $$DisplayGeometry{ScreenWidthMax} -1;
         if (defined($opt_t)) {
            $posY = $$DisplayGeometry{ScreenHeightMin};
         } 
         else {
            $posY = $$DisplayGeometry{ScreenHeightMax} -1;
         }
      }
      else {
         $posX = $$DisplayGeometry{ScreenWidthMax};
         if (defined($opt_t)) {
            $posY = $$DisplayGeometry{ScreenHeightMin} +1;
         } 
         else {
            $posY = $$DisplayGeometry{ScreenHeightMax};
         }
      }
      $result = `$Xdotool mousemove $posX $posY`;
   }
   
   # Save the current position.
   $$MousePosX = $posX;
   $$MousePosY = $posY;
   return 0;
}

# =============================================================================
# MAIN PROGRAM
# =============================================================================
# Process user specified CLI options.
getopts("hdnrxti:f:m:c:");

# ==========
# Display program help if -h specified.
if (defined($opt_h)) {
	 print"$UsageText\n";
	 exit(0);  
}

# ==========
# Check if already running.
$result = `ps -o pid,cmd -C perl`;
@count = $result =~ m/$ExecutableName/g;
if ($#count > 0) {
   &ColorMessage("$ExecutableName is already running.", "BRIGHT_RED");
   &PromptExit(1);
}

# ==========
# Check if tools are accessible.
$result = `which $Xdotool`;
chomp($result);
if ($Xdotool ne $result or $ENV{'XDG_SESSION_TYPE'} =~ m/wayland/i) {
   &ColorMessage("*** Error: $Xdotool not found. Stay awake funtionality " .
                 "disabled.", "BRIGHT_RED");
   $Xdotool = '';
}
else {
   $result = `$Xdotool getactivewindow 2>&1`;
   if (($? >> 8) != 0) {
      $Xdotool = '';        # Disable if tool fails.
   }
}
# -----
$result = `which $Mpstat`;
chomp($result);
if ($Mpstat ne $result) {
   &ColorMessage("*** Error: $Mpstat not found. -c functionality " .
                 "disabled.", "BRIGHT_RED");
   $Mpstat = '';
}
else {
   $result = &GetCpuUsage($Mpstat, 'idle');
   $Mpstat = '' if ($result == 0);
}
# -----
if (defined($opt_x)) {
   $result = `which $Xfconf`;
   chomp($result);
   if ($Xfconf ne $result) {
      &ColorMessage("*** Error: Required $Xfconf program not found. Program " .
                    "run aborted.", "BRIGHT_RED");
      &PromptExit(1);
   }
   $Imagetool = $Xfconf;
}
else {
   $result = `which $Pcmanfm`;
   chomp($result);
   if ($Pcmanfm ne $result) {
      &ColorMessage("*** Error: Required $Pcmanfm program not found. Program " .
                    "run aborted.", "BRIGHT_RED");
      &PromptExit(1);
   }
   $Imagetool = $Pcmanfm;
}   

# ==========
# Validate/set user specified options.
if (defined($opt_i)) {
   if ($opt_i >= 1 and $opt_i <= 86400) {
      $Interval = int($opt_i);
      $Interval-- if ($Mpstat ne '' and $Interval > 1);  # mpstat time adjust
   }
   else {
      &ColorMessage("*** Error: Invalid -i value $opt_i", "BRIGHT_RED");
   }
}
# &ColorMessage("main: Image update interval: $Interval seconds.");

if (defined($opt_m)) {
   if ($opt_m >= 0 and $opt_m <= 86400) {
      $MouseInterval = int($opt_m);
      $Xdotool = '' if ($MouseInterval == 0);
   }
   else {
      &ColorMessage("*** Error: Invalid -m value $opt_m", "BRIGHT_RED");
   }
}
# &ColorMessage("main: Mouse move interval: $MouseInterval seconds.");

if (defined($opt_c) and $Mpstat ne '') {
   if ($opt_c < 1 or $opt_c > 99) {
      &ColorMessage("*** Error: Invalid -c value $opt_c", "BRIGHT_RED");
   } 
   else {
      $CpuIdle = $opt_c;
   }
}

# The -r option is referenced by LoadFilenames and passed to FilenamesFromDir.
if (defined($opt_r)) {      
   $opt_r = 'recursive';
}
else {
   $opt_r = '';
}

# ==========
# Load the image filenames into the working array.
if (defined($opt_f)) {
   $ImageFiles = $opt_f;
   &PromptExit(1) if (&LoadFilenames($ImageFiles, \@ImageNameArray));
}
elsif (-e $ImageFiles) {   # Default variable value WallpaperChange.images
   &PromptExit(1) if (&LoadFilenames($ImageFiles, \@ImageNameArray));
} 
else {
   &ColorMessage("No images specified.", "BRIGHT_RED");
   &PromptExit(1);
}
if (defined($opt_d)) {
   &ColorMessage("Image names loaded: " . scalar @ImageNameArray, "CYAN");
}
if (scalar @ImageNameArray == 0) {
   &ColorMessage("No images found.", "BRIGHT_RED");
   &PromptExit(1);
}

# ==========
# Load the last image used if the save file exists. Then locate its
# array position and save in $ImageStep. $ImageStep is unchanged if
# no $LastImageName file or $LastImageName not found.
if (-e $LastImageNameFile) {
   unless (&ReadFile($LastImageNameFile, \@array, '')) {
      $LastImageName = $array[0];                # Last image used.
      for (0 .. $#ImageNameArray) {
         if ($ImageNameArray[$_] =~ m/$LastImageName/) {
            $ImageStep = $_;
            last;
         }
      }
   }
}

# ==========
# Setup for processing termination signals. Provides for save of the most 
# recent image name to a file by the Ctrl_C subroutine.                              
foreach my $sig ('INT','QUIT','TERM','ABRT','STOP','KILL','HUP') {
   $SIG{$sig} = \&Ctrl_C;
}

# ==========
# If stay-awake function is enabled, perform initializations.
if ($Xdotool ne '') {

   # Get the screen size and set working variables.
   &PromptExit(1) if (&GetDisplayGeometry($Xdotool, \%DisplayGeometry));

   # Minimize the program window to lower right corner if not in debug mode.
   $actWindow = `$Xdotool getactivewindow 2>&1`;
   chomp($actWindow);
   $geometry = `$Xdotool getwindowgeometry $actWindow 2>&1`;
   if ($geometry =~ m/Geometry: (\d+)x(\d+)/m) {
      $movePos = join(" ", $DisplayGeometry{ScreenWidthMax} - $1 - 10,
                           $DisplayGeometry{ScreenHeightMax} - $2 - 60);
      $result = `$Xdotool windowmove $actWindow $movePos 2>&1`;
   }
   $result = `$Xdotool windowminimize $actWindow 2>&1` unless (defined($opt_d));

   # Unconditional initial pointer move to the corner of screen.
   $MousePosX = $DisplayGeometry{ScreenWidthMax};
   if (defined($opt_t)) {
      $MousePosY = $DisplayGeometry{ScreenHeightMin} +1;
   }
   else {
      $MousePosY = $DisplayGeometry{ScreenHeightMax};
   }
   $result = `$Xdotool mousemove $MousePosX $MousePosY 2>&1`;
}

# ==========
# Run until program termination.
$imageCheckTime = time + $Interval;  # Initilize for image change.
$mouseCheckTime = $imageCheckTime + $MouseInterval;
$runMode = 'run';                    # 'run' or 'paused'
$idlePct = 100;                      # Default idle percent when no mpstat
ReadMode('cbreak');                  # Enable processing of terminal arrow keys.

while (1) {
   $cTime = time;
   if ($cTime >= $imageCheckTime and $runMode eq 'run') {
      $imageCheckTime = $cTime + $Interval;
      
      # If mpstat is available, get the current CPU idle percentage.
      # Display the next image only if CPU idle is greater than the 
      # $CpuIdle target value. $CpuIdle can be changed with -c option.
      $idlePct = &GetCpuUsage($Mpstat, 'idle') if ($Mpstat ne '');
      if ($idlePct > $CpuIdle) {
         if (&DisplayNextImage($Imagetool, $ImageFiles, \$ImageStep, 
                               \@ImageNameArray)) {
            &PromptExit(1);
         }
         $LastImageName = $ImageNameArray[$ImageStep];
         $LastImageName = substr($LastImageName, rindex($LastImageName,'/') +1);
      }
   }
   
   # Check/move mouse pointer if enabled.
   if ($Xdotool ne '' and $cTime >= $mouseCheckTime) {
      $mouseCheckTime = $cTime + $MouseInterval;  
      $result = &MoveMousePointer($Xdotool, \$MousePosX, \$MousePosY,
                                  \%DisplayGeometry);
   }
   
   # Check for user keypad input. Each keypad key is a sequence of 3 or 4
   # bytes beginning with the escape character (27). The enter key is also
   # supported. All other keys/sequences are discarded.
   if (&GetKeypadInput(\$charSeq) == 2) {   # Process new key press.
      $result = &ProcessKeyInput($charSeq, \$runMode, \$ImageStep, \@ImageNameArray);
      if ($result == 2) {    
         if ($charSeq eq '10') {              # Minimize program window (enter)
            $result = `$Xdotool windowminimize $actWindow` if ($Xdotool ne '');
         }
         elsif ($charSeq eq '47') {           # Show current image name (/)
            $name = $ImageNameArray[$ImageStep];
            $name = substr($name, rindex($name, '/') +1);
            STDOUT->autoflush(1);
            print "  $name";
            sleep 10;
            $size = length($name) +2;
            print "\b" x $size . " " x $size . "\b" x $size;
            STDOUT->autoflush(0);
         }
         elsif ($charSeq eq '43') {           # Change interval  +5 seconds (+)
            $Interval += 5 if ($Interval < 86395);
            STDOUT->autoflush(1);
            print "  $Interval";
            sleep 1;
            $size = length($Interval) +2;
            print "\b" x $size . " " x $size . "\b" x $size;
            STDOUT->autoflush(0);
         }
         elsif ($charSeq eq '45') {           # Change interval  -5 seconds (-)
            $Interval -= 5 if ($Interval > 6);
            STDOUT->autoflush(1);
            print "  $Interval";
            sleep 1;
            $size = length($Interval) +2;
            print "\b" x $size . " " x $size . "\b" x $size;
            STDOUT->autoflush(0);
         }
         elsif ($charSeq eq '279150126') {    # Reload image names (keypad 0) 
            $name = $ImageNameArray[$ImageStep];
            $name = substr($name, rindex($name, '/') +1);  # Save current image name.
            $pre = scalar @ImageNameArray;
            if (&LoadFilenames($ImageFiles, \@ImageNameArray)) {
               &ColorMessage("*** LoadFilenames error.", "BRIGHT_RED");
            }
            else {
               $chg = scalar @ImageNameArray - $pre;
               STDOUT->autoflush(1);
               print " Image names loaded.  $chg";
               sleep 2;
               if (defined($opt_n)) {
                  $end = scalar @ImageNameArray;
                  $size = length($end);
                  printf("\rStep %${size}d of $end" . " "x30 . "\b"x30, $ImageStep +1);
               }
               else {
                  print "\b" x 30 . " " x 30 . "\b" x 30;
               }
               # Set ImageStep to saved image since position may have changed.
               for (0 .. $#ImageNameArray) {
                  if ($ImageNameArray[$_] =~ m/$name/) {
                     $ImageStep = $_;
                     last;
                  }
               }
            }
            STDOUT->autoflush(0);
         }
      }
      elsif ($result == 0) {
         # Display the image at the new position.
         &DisplayNextImage($Imagetool, $ImageFiles, \$ImageStep, \@ImageNameArray);
         
         # The DisplayNextImage subroutine will update the displayed image 
         # position count when -n is specified  If paused, we need to 
         # reposition the terminal cursor to the end of the pause message.
         if (defined($opt_n) and $runMode eq 'paused') {
            STDOUT->autoflush(1);
            print "\e[C" x 30;
            STDOUT->autoflush(0);
         }
         $imageCheckTime = $cTime + $Interval;  # Update image change time.
      }
   }
   sleep 1;
}

# Normally won't get here but set ReadMode('normal') as a precaution.
ReadMode('normal');
exit(0);
