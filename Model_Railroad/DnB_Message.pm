# ============================================================================
# FILE: DnB_Message.pm                                              8/05/2020
#
# SERVICES:  DnB MESSAGE AND UTILITY FUNCTIONS
#
# DESCRIPTION:
#    This perl module provides message and utility functions used by the DnB
#    model railroad control program. A number of these functions are present
#    for possible future use.
#
# PERL VERSION: 5.24.1
#
# =============================================================================
use strict;
# -----------------------------------------------------------------------------
# Package Declaration
# -----------------------------------------------------------------------------
package DnB_Message;
require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
   OpenSerialPort
   ShutdownRequest
   PlaySound
   Ctrl_C
   ReadFile
   ReadBin
   ReadFileHandle
   WriteFile
   WriteFileAppend
   DisplayMessage
   DisplayError
   DisplayWarning
   DisplayDebug
   Trim
   TrimArray
   SplitIt
   HexToAscii
   DateTime
   DelDirTree
   GrepFile
   ShuffleArray
);

use Time::HiRes qw(gettimeofday sleep);

# =============================================================================
# FUNCTION:  OpenSerialPort
#
# DESCRIPTION:
#    This routine opens the Raspberry serial port using the specified device
#    and baud rate and returns the object to the caller. The serial port is
#    used to communicate message information to a monitoring terminal.
#
# CALLING SYNTAX:
#    $result = &OpenSerialPort(\$SerialObj, $Device, $Baud);
#
# ARGUMENTS:
#    $SerialObj      Pointer to serial object variable
#    $Device         Serial device to associated to object
#    $Baud           Communication baud rate.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#    $SerialObj = Set to object reference
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub OpenSerialPort {

   my($SerialObj, $Device, $Baud) = @_;

   &DisplayDebug(2, "OpenSerialPort, Device: $Device   Baud: $Baud");
   undef($$SerialObj);

   $$SerialObj = RPi::Serial->new($Device, $Baud);
   unless ($$SerialObj) {
      &DisplayError("OpenSerialPort, Serial device not accessable: $Device");
      return 1;
   }
   return 0;
}

# =============================================================================
# FUNCTION:  ShutdownRequest
#
# DESCRIPTION:
#    This routine is called to check and process a user requested shutdown. This
#    state sequence uses a dedicated shutdown button and is called as part of 
#    main program loop. Once initiated, another button press during timeout will 
#    abort the shutdown. The shutdown button reads 0 when pressed and 1 when
#    released due to GPIO21 configured with pullup.
#
# CALLING SYNTAX:
#    $result = &ShutdownRequest($Button, \%ButtonData, \%GpioData);
#
# ARGUMENTS:
#    $Button                Button index in %ButtonData hash.
#    $ButtonData            Pointer to %ButtonData hash.
#    $GpioData              Pointer to %GpioData hash.
#
# RETURNED VALUES:
#    0 = Run,  1 = Shutdown.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ShutdownRequest {
   my($Button, $ButtonData, $GpioData) = @_;
   my($buttonPress, @tones, $tone);

   $buttonPress = $$GpioData{ $$ButtonData{$Button}{'Gpio'} }{'Obj'}->read;

   # State 2
   if ($$ButtonData{$Button}{'Wait'} == 1) {  # Waiting for button release?
      if ($buttonPress == 1) {                     # Is button now released?
         $$ButtonData{$Button}{'Wait'} = 0;
         $$ButtonData{$Button}{'Shutdown'} = 1;    # Start shutdown timeout
         &DisplayMessage("ShutdownRequest, RPi shutdown initiated. " .
                         "Press button again to abort.");
      }
   }

   # State 4
   elsif ($$ButtonData{$Button}{'Wait'} == 2) {    # Waiting final release?
      if ($buttonPress == 1) {                     # Is button now released?
         $$ButtonData{$Button}{'Wait'} = 0;
         &DisplayMessage("ShutdownRequest, RPi shutdown aborted.");
         sleep 0.1                        ;        # Button debounce.
      }
   }

   # State 1 and 3
   elsif ($buttonPress == 0) {                       # Is button pressed?
      if ($$ButtonData{$Button}{'Shutdown'} == 1) {  # Timeout inprogress?
         $$ButtonData{$Button}{'Shutdown'} = 0;      # Abort shutdown.
         $$ButtonData{$Button}{'Step'} = 0;          # Reset step position.
         $$ButtonData{$Button}{'Wait'} = 2;       # Wait for button release.
         &PlaySound("Unlock.wav");
      }
      else {
         $$ButtonData{$Button}{'Wait'} = 1;       # Wait for button release.
      }      
   }

   # State 3
   elsif ($$ButtonData{$Button}{'Shutdown'} == 1) {   # Timeout inprogress?
      if (gettimeofday > $$ButtonData{$Button}{'Time'}) {
         $$ButtonData{$Button}{'Time'} = gettimeofday + 1;
         @tones = split(",", $$ButtonData{$Button}{'Tones'});
         $tone = $tones[$$ButtonData{$Button}{'Step'}++];
         &PlaySound("${tone}.wav");
         if ($$ButtonData{$Button}{'Step'} > $#tones) {
            sleep 2;                                  # Time for last tone.
            $$ButtonData{$Button}{'Time'} = 0;        # Reset for testing.
            $$ButtonData{$Button}{'Shutdown'} = 0;
            $$ButtonData{$Button}{'Step'} = 0;
            return 1;                                           # Shutdown
         }
      }      
   }
   return 0;
}

# =============================================================================
# FUNCTION:  PlaySound
#
# DESCRIPTION:
#    This routine plays the specified sound file using the player application
#    defined by global variable $main::SoundPlayer. Sound file playback is done 
#    asynchronously without waiting for playback to complete.
#
# CALLING SYNTAX:
#    $result = &PlaySound($SoundFile, $Volume);
#
# ARGUMENTS:
#    $SoundFile          File to be played.
#    $Volume             Optional; volume level.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::SoundPlayer, $main::AudioVolume
# =============================================================================
sub PlaySound {
   my($SoundFile, $Volume) = @_;
   my($vol);
   my($filePath) = substr($main::SoundPlayer, rindex($main::SoundPlayer, " ")+1);

   &DisplayDebug(2, "PlaySound, entry.  filePath: $filePath  SoundFile: $SoundFile");

   if (-e "${filePath}/${SoundFile}") {
      if ($Volume =~ m/^(\d+)/) {
         $vol = $1;
      }
      else {
         $vol = $main::AudioVolume;
      }
      system("/usr/bin/amixer set PCM ${vol}% >/dev/null");
      system("${main::SoundPlayer}/$SoundFile &");
   }
   else {
      &DisplayError("PlaySound, Sound file not found: ${filePath}/${SoundFile}");
      return 1;
   }
   return 0;
}

# =============================================================================
# FUNCTION:  Ctrl_C
#
# DESCRIPTION:
#    This routine is used to handle console entered ctrl+c input. When entered,
#    the INT signal is sent to all child processes. Each child process will run 
#    this routine in their forked context and terminate. The ChildName variable,
#    set by each child process when it starts, serves to identify the exiting 
#    child process.
#
#    The main program performs an orderly shutdown of the turnout servo driver 
#    boards to prevent lockups that require a power cycle to correct. It then 
#    saves the current turnout position data if running at operations level,
#    $main:: MainRun == 2.  
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
#    $main::MainRun, $main::ChildName, $main::$Opt{q}, %main::ServoBoardAddress

# =============================================================================
sub Ctrl_C {
   my($driver, $I2C_Address);
   my(%PCA9685) = ('ModeReg1' => 0x00, 'ModeReg2' => 0x01, 'AllLedOffH' => 0xFD,
                   'PreScale' => 0xFE);

   undef ($main::Opt{q});                      # Ensure console messages are on.
   if ($main::ChildName eq 'Main') {
      foreach my $key (sort keys(%main::ServoBoardAddress)) {
         $I2C_Address = $main::ServoBoardAddress{$key};
         $driver = RPi::I2C->new($I2C_Address);
         unless ($driver->check_device($I2C_Address)) {
            &DisplayError("Ctrl_C, Failed to instantiate I2C address: " . 
                          sprintf("0x%.2x",$I2C_Address));
            next;
         }
         $driver->write_byte(0x10, $PCA9685{'AllLedOffH'});  # Orderly shutdown.
         undef($driver);
      }
      $main::MainRun = 0;      # Stop the main loop.
      return;
   }
   &DisplayMessage("$main::ChildName, ctrl+c initiated stop.");
   exit(0);
}

# =============================================================================
# FUNCTION:  ReadFile
#
# DESCRIPTION:
#    This routine reads the specified file into the specified array.
#
# CALLING SYNTAX:
#    $result = &ReadFile($InputFile, \@Array, "NoTrim");
#
# ARGUMENTS:
#    $InputFile      File to read.
#    \@Array         Pointer to array for output records.
#    $NoTrim         Suppress record trim following read.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ReadFile {

   my($InputFile, $OutputArrayPointer, $NoTrim) = @_;
   my($FileHandle, $ntry);
   
   &DisplayDebug(2, "ReadFile, Loading from $InputFile ...");

   unless (open($FileHandle, '<', $InputFile)) {
      &DisplayError("ReadFile, opening file for read: $InputFile - $!");
      return 1;
   }
   @$OutputArrayPointer = <$FileHandle>;
   close($FileHandle);
   
   unless ($NoTrim) {
      foreach my $ntry (@$OutputArrayPointer) {
         $ntry = Trim($ntry);
      }   
   }
   return 0;
}

# =============================================================================
# FUNCTION:  ReadBin
#
# DESCRIPTION:
#    This routine reads the specified binary file into the specified variable.
#
# CALLING SYNTAX:
#    $result = &ReadBin($Filename, \$BufferPntr);
#
# ARGUMENTS:
#    $Filename       File to read.
#    $BufferPntr     Pointer to variable.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ReadBin {
   my($Filename, $BufferPntr) = @_;
   my($FileHandle);
   
   &DisplayDebug(2, "ReadBin, Filename: $Filename");

   unless (open($FileHandle, '<', $Filename)) {
      &DisplayError("ReadBin, opening file for read: $Filename - $!");
      return 1;
   }
   binmode($FileHandle);
   local $/ = undef;
   $$BufferPntr = <$FileHandle>;
   close($FileHandle);
   &DisplayDebug(2, "ReadBin, length read: " . length($$BufferPntr));

   return 0;
}

# ===========================================================================
# FUNCTION:  ReadFileHandle
#
# DESCRIPTION:
#    This routine is used to perform sysread's of the specified number of
#    bytes from the specified file handle. The data is unpacked into a 
#    character string; two characters per byte in hexidecimal format. The
#    returned length will always be the requested size times 2 plus the
#    length of the input $data contents. Any input $data from a previous
#    ReadBin call is prepended to the current data read.
#
# CALLING SYNTAX:
#    ($length, $data) = &ReadFileHandle($FileHandle, $size, $data);
#
# ARGUMENTS:
#    $FileHandle     Filehandle of input data.
#    $Size           Number of bytes to read from FileHandle.
#    $Data           Input $data contents, if any.
#
# RETURNED VALUES:
#    -1 = EOF,  length of data.
#    unpacked bytes read.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# ===========================================================================
sub ReadFileHandle {

   my($FileHandle, $Size, $Data) = @_;
   my($sizeread, $newdata);

   &DisplayDebug(2, "ReadFileHandle, entry ...   Size: $Size");

   if ($Size > 0) {
      undef $/;
      $sizeread = sysread($FileHandle, $newdata, $Size);
      $/ = "\n";
      &DisplayDebug(2, "ReadFileHandle, sizeread: $sizeread");
      if ($sizeread > 0) {
         $newdata = unpack("H*", $newdata);
         $newdata = join("", $Data, $newdata);
         return (length($Data), $newdata);
      }
      else {
         return (-1, $Data);
      }
   }
   return (length($Data), $Data);
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
#    $Array          Pointer to array for output records.
#    $Trim           Trim records before writing to file.
#
# RETURNED VALUES:
#    0 = Success,  exit code on Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub WriteFile {

   my($OutputFile, $OutputArrayPointer, $Trim) = @_;
   my($FileHandle);
   
   &DisplayDebug(2, "WriteFile, Creating $OutputFile ...");

   unlink ($OutputFile) if (-e $OutputFile);

   unless (open($FileHandle, '>', $OutputFile)) {
      &DisplayError("WriteFile, opening file for write: $OutputFile - $!");
      return 1;
   }
   foreach my $ntry (@$OutputArrayPointer) {
      $ntry = Trim($ntry) if ($Trim);
      unless (print $FileHandle $ntry, "\n") {
         &DisplayError("WriteFile, writing file: $OutputFile - $!");
         close($FileHandle);
         return 1;
      }
   }
   close($FileHandle);
   return 0;
}

# =============================================================================
# FUNCTION:  WriteFileAppend
#
# DESCRIPTION:
#    This routine writes the specified array to the specified file. If the file
#    already exists, the new data is appended to the current data.
#
# CALLING SYNTAX:
#    $result = &WriteFileAppend($OutputFile, \@Array, "Trim");
#
# ARGUMENTS:
#    $OutputFile     File to write.
#    $Array          Pointer to array for output records.
#    $Trim           Trim records before writing to file.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub WriteFileAppend {

   my($OutputFile, $OutputArrayPointer, $Trim) = @_;
   my($FileHandle);
   
   if (-e $OutputFile) {
      &DisplayDebug(2, "WriteFileAppend, Updating $OutputFile ...");
      unless (open($FileHandle, '>>', $OutputFile)) {
         &DisplayError("WriteFileAppend, opening file for append: " .
                       "$OutputFile - $!");
         return 1;
      }
   }
   else {
      &DisplayDebug(2, "WriteFileAppend: Creating $OutputFile ...");
      unless (open($FileHandle, '>', $OutputFile)) {
         &DisplayError("WriteFileAppend, opening file for write: $OutputFile - $!");
         return 1;
      }
   }
   foreach my $ntry (@$OutputArrayPointer) {
      $ntry = Trim($ntry) if ($Trim);
      unless (print $FileHandle $ntry, "\n") {
         &DisplayError("WriteFileAppend, writing file: $OutputFile - $!");
         close($FileHandle);
         return 1;
      }
   }
   close($FileHandle);
   return 0;
}

# =============================================================================
# FUNCTION:  DisplayMessage
#
# DESCRIPTION:
#    Displays a message to the user. If variable $main::SerialPort is set, 
#    the message is directed to the Raspberry Pi serial port.
#
# CALLING SYNTAX:
#    $result = &DisplayMessage($Message);
#
# ARGUMENTS:
#    $Message         Message to be output.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::SerialPort, $main::Opt{q}
# =============================================================================
sub DisplayMessage {

   my($Message) = @_;
   my($time) = &DateTime('', '', '-');

   if ($main::SerialPort > 0) {
      $main::SerialPort->puts("$$ $time $Message\n");
   }
   else {
      print STDOUT "$$ $time $Message\n" unless (defined($main::Opt{q}));
   }
   return 0;
}

# =============================================================================
# FUNCTION:  DisplayError
#
# DESCRIPTION:
#    Displays an error message to the user. If variable $main::SerialPort
#    is set, the message is directed to the Raspberry Pi serial port.
#
# CALLING SYNTAX:
#    $result = &DisplayError($Message, $Stdout);
#
# ARGUMENTS:
#    $Message         Message to be output.
#    $Stdout          Sends message to STDOUT if set.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::SerialPort, $main::Opt{q}
# =============================================================================
sub DisplayError {

   my($Message, $Stdout) = @_;
   my($time) = &DateTime('', '', '-');
   my($result);

   if ($main::SerialPort > 0) {
      $main::SerialPort->puts("$$ $time *** error: $Message\n");
   }
   else {
      unless (defined($main::Opt{q})) {
         if ($Stdout) {
            return (print STDOUT "$$ $time *** error: $Message\n");
         }
         else {
            return (print STDERR "$$ $time *** error: $Message\n");
         }
      }
      &PlaySound("A.wav",80);  # Sound error tone.
   }
   return 0;
}

# ===========================================================================
# FUNCTION:  DisplayWarning
#
# DESCRIPTION:
#    Displays a warning message to the user. If variable $main::SerialPort
#    is set, the message is directed to the Raspberry Pi serial port.
#
# CALLING SYNTAX:
#    $result = &DisplayWarning($Message, $Stdout);
#
# ARGUMENTS:
#    $Message       Message to be output.
#    $Stdout        Sends message to STDOUT if set.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::SerialPort, $main::Opt{q}
# ===========================================================================
sub DisplayWarning {

   my($Message, $Stdout) = @_;
   my($time) = &DateTime('', '', '-');

   if ($main::SerialPort > 0 and $main::WiringApiObj ne "") {
      $main::SerialPort->puts("$$ $time --> error: $Message\n");
   }
   else {
      unless (defined($main::Opt{q})) {
         if ($Stdout) {
            return (print STDOUT "$$ $time --> warning: $Message\n");
         }
         else {
            return (print STDERR "$$ $time --> warning: $Message\n");
         }
      }
   }
   return 0;   
}

# =============================================================================
# FUNCTION:  DisplayDebug
#
# DESCRIPTION:
#    Displays a debug message to the user if the current program $DebugLevel 
#    is >= to the message debug level. If variable $main::SerialPort is set, 
#    the message is directed to the Raspberry Pi serial port.
#
# CALLING SYNTAX:
#    $result = &DisplayDebug($Level, $Message);
#
# ARGUMENTS:
#    $Level                Message debug level.
#    $Message              Message to be output.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::SerialPort, $main::DebugLevel, $main::Opt{q}
# =============================================================================
sub DisplayDebug {

   my($Level, $Message) = @_; 
   my($time) = &DateTime('', '', '-');

   if ($main::DebugLevel >= $Level) {
      if ($main::SerialPort > 0) {
         $main::SerialPort->puts("$$ $time debug${Level}: $Message\n");
      }
      else {
         unless (defined($main::Opt{q})) {
            print STDOUT "$$ $time debug${Level}: $Message\n";
         }
      }
   }
   return 0;
}

# =============================================================================
# FUNCTION:  Trim
#
# DESCRIPTION:
#    Removes newline, leading, and trailing spaces from specified input. Input
#    string is returned.
#
# CALLING SYNTAX:
#    $String = &Trim($String);
#
# ARGUMENTS:
#    $String        String to trim.
#
# RETURNED VALUES:
#    Trimmed and chomped string.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub Trim {

   my($String) = @_;
   
   chomp($String);                         # Remove trailing newline.
   $String =~ s/^\s+//;                    # Remove leading whitespace.
   $String =~ s/\s+$//;                    # Remove trailing whitespace.
   return($String);
}

# =============================================================================
# FUNCTION:  TrimArray
#
# DESCRIPTION:
#    Removes leading and trailing blank lines from the specified array. The
#    array is specified by reference.
#
# CALLING SYNTAX:
#    $result = &TrimArray(\@array);
#
# ARGUMENTS:
#    \@array        Pointer reference to the array to be processed.
#
# RETURNED VALUES:
#    0 = Success,  1 = Array is empty.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub TrimArray {

   my($arrayRef) = @_;
   
   splice(@$arrayRef, 0, 1) while ($#$arrayRef > 0 and $$arrayRef[0] =~ m/^\s*$/);
   splice(@$arrayRef, $#$arrayRef, 1) while ($#$arrayRef > 0 and 
                                             $$arrayRef[$#$arrayRef] =~ m/^\s*$/);
   return 0;
}

# =============================================================================
# FUNCTION: SplitIt
#
# DESCRIPTION:
#    This function is called to split the supplied string into parts using the
#    specified character as the separator character. The results are trimmed
#    of leading and trailing whitespace and returned in an array.
#
# CALLING SYNTAX:
#    @Array = &SplitIt($Char, $Rec);
#
# ARGUMENTS:
#    $Char        The separator character.
#    $Rec         The one-line record to be split.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub SplitIt {

   my($Char, $Rec) = @_;
   my(@temp, $i);
   
   if (($Char) and ($Rec)) {
      $Rec = &Trim($Rec);
      @temp = split($Char,$Rec);
      for ($i = 0; $i <= $#temp; $i++) {
         @temp[$i] = &Trim(@temp[$i]);
      }
      return @temp;
   }
   else {
      return $Rec;
   }      
}

# =============================================================================
# FUNCTION:  HexToAscii
#
# DESCRIPTION:
#    This routine is used to convert a hex data string to its equivalent
#    ASCII characters. Two characters from the input data stream are used
#    for each output character.
#
# CALLING SYNTAX:
#    $AsciiStr = &HexToAscii($HexData);
#
# ARGUMENTS:
#    $HexData            Input hex data to convert.
#
# RETURNED VALUES:
#    ASCII character string
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub HexToAscii {

   my($HexData) = @_;
   my($x, $chr);  my($AsciiStr) = "";
   
   for ($x = 0; $x < length($HexData); $x += 2) {
      $chr = chr(hex(substr($HexData, $x, 2)));
      $AsciiStr = join("", $AsciiStr, $chr);
   }
   return $AsciiStr;
}

# =============================================================================
# FUNCTION: DateTime
#
# DESCRIPTION:
#    This function, when called, returns a formatted date/time string for the
#    specified $Time. The current server time is used if not specified. The 
#    arguments are used to affect how the date and time components are joined 
#    into the result string. For example:
#
#    For $DateJoin = "-", $TimeJoin = ":", and $DatetimeJoin = "_", the returned
#    string would be: '2007-06-13_08:15:41'
#
# CALLING SYNTAX:
#    $datetime = DateTime($DateJoin, $TimeJoin, $DatetimeJoin, $Time);
#
# ARGUMENTS:
#    $DateJoin        Character string to join date components 
#    $TimeJoin        Character string to join time components
#    $DatetimeJoin    Character string to join date and time components
#    $Time            Optional time to be converted
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub DateTime {
   my($DateJoin, $TimeJoin, $DatetimeJoin, $Time) = @_;
   my($date, $time, $sec, $min, $hour, $day, $month, $year);

   if ($Time eq "") {
      ($sec, $min, $hour, $day, $month, $year) = localtime;
   }
   else {   
      ($sec, $min, $hour, $day, $month, $year) = localtime($Time);
   }

   $month = $month+1;
   $month = "0".$month if (length($month) == 1);
   $day = "0".$day if (length($day) == 1);
   $year = $year + 1900;
   $hour = "0".$hour if (length($hour) == 1);
   $min = "0".$min if (length($min) == 1);
   $sec = "0".$sec if (length($sec) == 1);

   $date = join($DateJoin, $year, $month, $day);
   $time = join($TimeJoin, $hour, $min, $sec); 
   return join($DatetimeJoin, $date, $time);
}

# =============================================================================
# FUNCTION: DelDirTree
#
# DESCRIPTION:
#    This function recursively deletes directories and files in the specified 
#    directory. The specified directory is then deleted.
#
# CALLING SYNTAX:
#    $result = DelDirTree($Dir);
#
# ARGUMENTS:
#    $Dir              Directory tree to be deleted.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub DelDirTree {
   my($Dir) = @_;
   my($file);      my(@list) = ();   

   &DisplayDebug(2, "DelDirTree, Entry ...   Dir: $Dir");

   unless (opendir(DIR, $Dir)) {
      &DisplayError("DelDirTree, opening directory: $Dir - $!");
      return 1;
   }
   @list = readdir(DIR);
   closedir(DIR);

   foreach my $ntry (@list) {
      next if (($ntry eq ".") or ($ntry eq ".."));  # Skip . and .. directories
      $file = join("\\", $Dir, $ntry);
      if (-d $file) {
         return 1 if (&DelDirTree($file));          # Recursion into directory
      }
      else {
         unless (unlink $file) {
            &DisplayError("DelDirTree, removing file: $file - $!");
            return 1;
         }
      }
   }
   unless (rmdir $Dir) {
      &DisplayError("DelDirTree, can't remove directory: $Dir - $!");
      return 1;  
   }
   return 0;
}

# =============================================================================
# FUNCTION:  GrepFile
#
# DESCRIPTION:
#   Grep the specified file for the specified strings. This routine used instead
#   of a backtick/system command for platform portability.
#
#   The $Option specifies how the search string is used.
#      'single' - The string is used as specified. Default if not specified.
#      'multi'  - String is a space separated list of words. Any word matches. 
#
# CALLING SYNTAX:
#   $result = &GrepFile($String, $File, $Option);
#
# ARGUMENTS:
#   $String        The string to search for.
#   $File          The file to search.
#   $Option        Search option.
#
# RETURNED VALUES:
#   Success: Matched line or "" if no match.
#
# ACCESSED GLOBAL VARIABLES:
#   None.
# =============================================================================
sub GrepFile {
   my($String, $File, $Option) = @_;
   my($FileHandle);
   my($grepResult, $prevLine) = ("","");
   
   &DisplayDebug(2,"GrepFile, String: '$String'  File: '$File'  Option: '$Option'");

   if (-e $File) {
      if (open($FileHandle, '<', $File)) {
         if ($Option =~ m/^m/) {
            $String =~ s#\s+#|#g;
            &DisplayDebug(2,"GrepFile, String: '$String'");
         }
         while (<$FileHandle>) {               
            if ($_ =~ m/$String/) {
               $grepResult = $_;
               &DisplayDebug(2,"GrepFile, Matched: '$String'   " .
                               "grepResult: $grepResult");
               last;
            }
         }
         close($FileHandle);       
      }
   } 
   else {
      &DisplayError("GrepFile, file to grep not found: $File");
   }
   return Trim($grepResult);
}

# =============================================================================
# FUNCTION:  ShuffleArray
#
# DESCRIPTION:
#    This routine shuffles the specified array using the Fisher-Yates shuffle 
#    algorithm. In plain terms, the algorithm randomly shuffles the sequence.
#
# CALLING SYNTAX:
#    $result = &ShuffleArray(\@Array);
#
# ARGUMENTS:
#    \@Array         Pointer to array to be shuffled.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ShuffleArray {
   my($Array) = @_;
   
   if ($#$Array > -1) {
      &DisplayDebug(3, "ShuffleArray, pre-shuffle : @$Array");
      my $i = @$Array;
      while (--$i) {
         my $j = int rand ($i + 1);
         @$Array[$i,$j] = @$Array[$j,$i];
      }
      &DisplayDebug(3, "ShuffleArray, post-shuffle : @$Array");
   }
   return 0;
}

return 1;
