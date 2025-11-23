#!/usr/bin/perl
# ==============================================================================
# FILE: wled-tool.pl                                                 11-23-2025
#
# SERVICES: Access WLED using JSON API  
#
# DESCRIPTION:
#   This program is used to send and receive data to WLED using its json-api
#   interface. See https://kno.wled.ge/interfaces/json-api/ for details about
#   the WLED json-api interface. This program requires additional perl modules
#   that may not be included by the standard perl installer for your OS. Use 
#   the help option 'wled.pl -h' to show the available functionality. Required 
#   perl modules that are missing will be identified. Use cpanm (linux) or 
#   ppm (windows) to install the needed perl modules.
#
#   This program attempts to be OS independent. It has been tested on linux 
#   (Raspberry Pi 4 and 5, linuxmint) and Windows 7.
#
#   The LWP::UserAgent module provides the GET/POST related web functions. The 
#   JSON module is used to perform validity checks on the JSON message content
#   and trigger error processing. The JSON module imports decode_json which is
#   used by &AuditionPresets to create working data hashes. The ANSI related
#   modules are used to color console messages. The Win32::Console::ANSI module
#   is only needed by the Windows OS and is conditionally loaded. 
#
#   This CLI based program was created to simplify some of the WLED related 
#   maintenance tasks. This is primarily the backup/restore of the WLED cfg, 
#   preset, and palette data. The WLED GUI does have backup/restore/restart 
#   functionality but as of WLED 15.0 lacks a custom palette backup function.
#
#   WLED configuration, presets and custom palettes are initially created 
#   using the WLED GUI. Once saved by this program, they are easily restored.
#   In particular, a backup/restore function that incorporates cfg, presets,
#   and palettes into a single operation is provided; the -a and -A options.
#   Each backup type can also be done individually using seperate options. 
#
#   This code has been tested as a standalone Windows executable using the
#   Strawberry perl PAR::Packer module. Use the following command to build
#   the windows executable.  pp -o wled-tools.exe wled-tools.pl
#
# PERL VERSION:  5.28.1
# ==============================================================================
use Getopt::Std;
use Term::ANSIColor;
require Win32::Console::ANSI if ($^O =~ m/Win/i);
use LWP::UserAgent;
use JSON;
use File::Copy;
use Data::Dumper;
# use warnings;

# ==============================================================================
# Global Variables
our ($ExecutableName) = ($0 =~ /([^\/\\]*)$/);

# --- Add start directory to @INC for executable included perl modules.
use Cwd;
our $WorkingDir = cwd();
if (length($ExecutableName) != length($0)) {
   $WorkingDir = substr($0, 0, rindex($0, "/"));
}
unshift (@INC, $WorkingDir);

our %cliOpts = ();           # CLI options working hash
getopts('hdilre:f:v:w:x:a:A:c:C:g:G:p:P:m:M:', \%cliOpts);  # Load CLI options hash

our $WledIp = '4.3.2.1';     # WLED endpoint IP
our %Sections = ('configuration' => 'cfg.json', 'presets' => 'presets.json');

our $UsageText = (qq(
===== Help for $ExecutableName ================================================

GENERAL DESCRIPTION
   This program is used to send and receive data to WLED using its json api
   interface. The WLED at the default IP $WledIp or the -e specified IP, is 
   used. The desired program function is specified using one of the program 
   CLI options. Use a single option for each run of this program with excep-
   tion of the -P option which permits the -r and -C options. General validity
   checks of the json WLED data format is performed. 

   Windows note: For options with a file path, use the / character for the
   folder separator, not \\.  
   
   Custom palettes are uploaded using the -G option. The file name identifies
   the custom palette location, e.g. palette0.json. Multiple files may be
   specified; either by * or ? wildcard character 'palette?.json' or seperated
   by comma (palette0.json,palette1.json). Note that with linux, quotes are
   needed when a wildcard character is used. The uploaded file content replaces
   any existing content for the custom palette location.
   
   The options -c -C and -p -P accept the single character - for <file>. This
   results in the default file name 'cfg.json' and 'presets.json' respectively. 
   
   Caution: When using a backup option (-a, -c, -p, -g, -m), if the specified 
   file exists, it will be overwritten without warning.
      
   To backup working data prior to a WLED software upgrade, use the -a option.
   After upgrade, connect to WLED using a browser. Use the GUI 'WIFI SETTINGS'
   control to set and save the AP SSID and AP password. (The AP password is not
   backed up by WLED for security reasons.) Power cycle the WLED ESP32 module.
   Then use the -A option to restore the working data.
   
   The -f option is used to reformat a WLED configuration or preset file for
   easier use in a text editor. Extraneous whitespace is removed, newlines are 
   added, and some JSON data pairs are indented for better readability. The 
   changes made are compatible with subsequent use by WLED. A backup copy of
   the input file is created. It is then overwritten with the new reformatted 
   content. If the -d option is also specified, the reformatted content is
   only displayed on the console.
    
   The -x option is used to send json formatted data to WLED. See the WLED
   json-api webpage at https://kno.wled.ge/interfaces/json-api/ for details.
   Comment lines, beginning with the # character, may be included in the file 
   data for documentation purposes. Comment data is not sent to WLED. Multiple 
   comma seperated files or a file name wildcard character may be specified.

   The -i option provides interactive preset audition and test functionality.
   The available preset Ids are read from WLED and displayed for user selection; 
   green colored entries signify playlists. WLED is instructed to activate the 
   selected preset using its JSON API. Other user commands, as noted below, are
   also available. Except as noted, audition activity does not change the current
   WLED settings established by the WLED configuration files. 
   
   The following commands are available while running in preset audition mode.
   Brackets [] identify optional command arguments.
   
   Numeric value: <n>
      Activate the specified WLED preset or playlist Id.
     
   Custom playlist: p [<n> <n> [d <s>]]
      Activate the specified playlist on WLED where 'p' is followed by one or 
      more preset Ids. Optional 'd' is followed by a time duration in seconds
      (0-3600). Duration defaults to 15 seconds if not specified. 'p' alone 
      displays the current active preset.
   
   LED brightness: b [[+|-]<n>]
      Activate the specified WLED master LED brightness level where <n> is a
      value 1-255. 'b' alone displays the current master brightness. Use + 
      or - to specify a relative value. e.g. -50 

   LED frame rate and power usage: f
      Shows the frame rate and power usage for the active WLED preset.
      
   WLED reboot: r
      Reboots WLED. Wait ~15 seconds for reboot and WIFI reconnect.
      
   WLED default brightness: db [<n>]    (Persistent setting)
      Sets the specified WLED default brightness (1-255). The current WLED 
      default brightness value is displayed if not specified. This value is 
      used on subsequent WLED reboots and overwritten by restore of the WLED
      configuration from a backup.
      
   WLED power on preset: dp [<n>]       (Persistent setting)
      Sets the specified WLED power on preset Id (1-250). The current WLED 
      value is displayed if not specified. This preset will be activated 
      when WLED reboots. Overwritten by a WLED configuration restore.
      
   Active preset effect speed: s [<seg> [+|-]<n>]
      Sets the effect speed (sx) for the specified segment of the active
      preset (0-255). 's' alone displays all segments of the active preset.
      Use + or - to specify a relative value. e.g. +10 
   
   Active preset effect intensity: i [<seg> [+|-]<n>]
      Sets the effect intensity (ix) for the specified segment of the active
      preset (0-255). 'i' alone displays all segments of the active preset.
      Use + or - to specify a relative value. e.g. -10 
   
   Heading data: h
      Displays the audition mode heading text which includes WLED version
      information, available presets, and interactive command summary.
   
USAGE:
   $ExecutableName  [-h] [-d] [-i] [-l] [-r] [-e <url>] [-a <file>] [-A <file>]
      [-c <file>] [-C <file>] [-g <dir>] [-G <file>[,<file>,...]] [-p <file]
      [-P <file>] [-f <file>] [-v <file>] [-w <file>] [-x <file>] [-m <dir>]
      [-M <file>[,<file>,...]]

   -h           Displays program usage text.
   -d           Run in debug mode.

   -e <ip>      Use the specified WLED IP address. Default: $WledIp
   -i           Run interactive preset audition loop. Enter 0 to exit.
   -r           Reset WLED. Used standalone or with -p option.
    
   -l           Dump all WLED data to the console.
   -w <file>    Dump all WLED data to the specified file.

   -a <file>    Backup WLED cfg, presets, and palettes to a single file.
   -c <file>    Backup WLED cfg data to file. - for <file> = cfg.json
   -p <file>    Backup WLED preset data to file. - for <file> = presets.json
   -g <dir>     Backup custom palettes to the specified directory.
   -m <dir>     Backup custom ledmaps to the specified directory.

   -A <file>    Restore WLED cfg, presets, and palettes from a file previously
                created by the -a option.
   -C <file>    Restore WLED configuration data from file. 
   -P <file>    Restore WLED preset data from file. Use -r option to activate
                the restored presets.
   -G <file>    Restore specified custom palette file(s) content to WLED. 
   -M <file>    Restore specified custom ledmap file(s) content to WLED. 
                  
   -f <file>    Format the specified preset file for text editor.
   -v <file>    Validate json formatted content of <file>.
   -x <file>    Validate and send the specified json data to WLED. 
                  
EXAMPLES:
   $ExecutableName -l
      Display on the console all available data for the WLED at $WledIp.

   $ExecutableName -g .
      Backup custom palettes to the current working directory. Files 
      palette0.json, ... are created or overwritten if present.

   $ExecutableName -G 'palette*.json'
      Restore all palette files in current working directory to the WLED at
      IP $WledIp.
      
   $ExecutableName -e 192.168.0.100 -a myBackup.dat
      Backup the WLED at IP address 192.168.0.100. Save the configuration, 
      preset, and palette data to the specified file.
       
   $ExecutableName -A ./wled/myBackup.dat
      Restore the WLED at IP address 4.3.2.1 with the configuration, preset,
      and palette data that is contained in the specified file. WLED will be
      automatically restarted following restore.
       
   $ExecutableName -c myConfig.json
      Backup the WLED configuration at IP address 4.3.2.1 to the specified file.
       
   $ExecutableName -C myConfig.json
      Restore configuration data to the WLED at 4.3.2.1 using the specified
      file content. WLED will be automatically restarted.
        
   $ExecutableName -p myPresets.json
      Backup the WLED presets at IP address 4.3.2.1 to the specified file.
       
   $ExecutableName -r -P myPresets.json
      Restore preset data to the WLED at IP address 4.3.2.1 using the specified
      file content. Then restart WLED to activate the restored preset data.
       
   $ExecutableName -P myPresets.json -C myConfig.json
      Restore preset and configuration data to the WLED at IP address 4.3.2.1 
      from the specified files. WLED automatic restart activates the data.

===============================================================================
));

# =============================================================================
# FUNCTION:  ReadFile
#
# DESCRIPTION:
#    This routine reads the specified file into the specified array.
#
# CALLING SYNTAX:
#    $result = &ReadFile($InputFile, \@Array, $Option);
#
# ARGUMENTS:
#    $InputFile      File to read.
#    \@Array         Pointer to array for the read records.
#    $Option         'trim' input records.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub ReadFile {
   my($InputFile, $ArrayPointer, $Option) = @_;
   my($FileHandle);

   unless (-e $InputFile) {
      &ColorMessage("*** Error: File not found: $InputFile", "BRIGHT_RED", '');
      return 1;
   }
   unless (open($FileHandle, '<', $InputFile)) {
      &ColorMessage("*** Error: opening file for read: $InputFile - $!",
                    "BRIGHT_RED", '');
      return 1;
   }
   @$ArrayPointer = <$FileHandle>;
   close($FileHandle);
   if ($Option =~ m/trim/i) {
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
#    $result = &WriteFile($OutputFile, \@Array, $Option);
#
# ARGUMENTS:
#    $OutputFile     File to write.
#    $Array          Pointer to array of records to write.
#    $Option         'trim' records before writing to file.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub WriteFile {
   my($OutputFile, $OutputArrayPointer, $Option) = @_;
   my($FileHandle);
   
   unlink ($OutputFile) if (-e $OutputFile);

   unless (open($FileHandle, '>', $OutputFile)) {
      &ColorMessage("*** Error: opening file for write: $OutputFile - $!",
                    "BRIGHT_RED", '');
      return 1;
   }
   foreach my $line (@$OutputArrayPointer) {
      if ($Option =~ m/trim/i) {
         chomp($line);
         $line =~ s/^\s+|\s+$//g;
      }
      unless (print $FileHandle $line, "\n") {
         &ColorMessage("*** Error: writing file: $OutputFile - $!", "BRIGHT_RED", '');
         close($FileHandle);
         return 1;
      }
   }
   close($FileHandle);
   return 0;
}

# =============================================================================
# FUNCTION:  GetTmpDir
#
# DESCRIPTION:
#    This routine returns a path to the temporary directory on Linux and 
#    Windows by examining environment variables. If not resolved, an OS 
#    specific default is returned.
#
# CALLING SYNTAX:
#    $path = &GetTmpDir();
#
# ARGUMENTS:
#    None.
#
# RETURNED VALUES:
#    <path> = Success,  '' = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub GetTmpDir {
   my($path, $os) = ('','');

   # Check for an environment varible specified tempdir.
   foreach my $dir ('TMP','TEMP','TMPDIR','TEMPDIR') {
      if (exists($ENV{$dir})) {
         $path = $ENV{$dir};
         last;
      }
   }

   # Use a default if tempdir not specified.
   if ($^O =~ m/Win/i) {
      $os = 'win';
      $path = cwd() if ($path eq '');
   }
   else {
      $os = 'linux';
      $path = '/tmp' if ($path eq '');
   }
   chomp($path);
   $path =~ s/^\s+|\s+$//g;
   &DisplayDebug("GetTmpDir: os: $os   path: '$path'");
   unless (-d $path) {
      &ColorMessage("   Can't get temp directory: $path", "BRIGHT_RED", '');
      return '';
   }
   return $path;
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
#    $result = &ColorMessage($Message, $Color, $Nocr);
#
# ARGUMENTS:
#    $Message         Message to be output.
#    $Color           Optional color attributes to apply.
#    $Nocr            Suppress message newline if set. 
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub ColorMessage {
   my($Message, $Color, $Nocr) = @_;
   my($cr) = "\n";
   
   $cr = '' if ($Nocr ne '');
   if ($Color ne '') {
      if ($^O =~ m/Win/i) {            # Windows environment?
         print STDOUT color("$Color"), $Message, color("reset"), "$cr";
      }
      else {
         print STDOUT colored($Message . "$cr", $Color);
      }
   }
   else {
      print STDOUT $Message, "$cr";
   }
   return 0;
}

# =============================================================================
# FUNCTION:  DisplayDebug
#
# DESCRIPTION:
#    Displays a debug message to the user. The message is colored for easier
#    identification on the console.
#
# CALLING SYNTAX:
#    $result = &DisplayDebug($Message);
#
# ARGUMENTS:
#    $Message              Message to be output.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $cliOpts{d}
# =============================================================================
sub DisplayDebug {
   my($Message) = @_;
   
   &ColorMessage($Message, 'BRIGHT_CYAN', '') if (defined( $cliOpts{d} ));
   return 0;
}

# =============================================================================
# FUNCTION:  ValidateJson
#
# DESCRIPTION:
#    This routine optionally removes multiple spaces from the specified array
#    or string. Only one of Array or String should be specified. The resulting
#    data is validated using decode_json. The cleaned array or string replaces
#    the input if clean is specified.
#
# CALLING SYNTAX:
#    $result = &ValidateJson(\@Array, \$String, $Clean, $Quiet);
#
# ARGUMENTS:
#    $Array          Pointer to array of json records.
#    $String         Pointer to string of json data.
#    $Clean          Multi-space removal if set.
#    $Quiet          No error message. Just return error.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub ValidateJson {
   my($ArrayPointer, $StringPointer, $Clean, $Quiet) = @_;
   my (@array, $check);

   if ($ArrayPointer ne '') {
      @array = @$ArrayPointer;                         # Local working copy
      if ($Clean ne '') {
         s/\x20{2,}//g foreach @array;              # Remove multiple spaces  
      } 
      $check = join('', @array);
      return 1 if (&chkJson(\$check));
      @$ArrayPointer = @array if ($Clean ne '');    # Replace with cleaned data.
   }
   elsif ($StringPointer ne '') {
      $check = $$StringPointer;
      $check =~ s/\x20{2,}//g if ($Clean ne '');       # Remove multiple spaces
      return 1 if (&chkJson(\$check));
      $StringPointer = $check if ($Clean ne '');    # Replace with cleaned data.
   }
   else {
      &ColorMessage("ValidateJson - No json specified.", "BRIGHT_RED", '');
      return 1;
   }
   return 0;

   # ----------
   # This private sub performs the json validation.   
   sub chkJson {
      my($Pntr) = @_;
      eval { JSON->new->decode($$Pntr) };      # Validate json data formatting.
      if ($@) {
         unless ($Quiet) {
            &ColorMessage("ValidateJson - Invalid json.", "BRIGHT_RED", '');
            &ColorMessage("ValidateJson - $@", "CYAN", '');
         }
         return 1;
      }
      return 0;
   }
}

# =============================================================================
# FUNCTION:  FormatPreset
#
# DESCRIPTION:
#    This routine reformats the specified WLED JSON preset data for readability
#    and use in a text editor. The serialized output is returned to the caller. 
#
#    The keys for each level of the preset data structure are read and stored
#    in a working hash. As the individual keys are processed, using the ordering
#    arrays, the key in the working hash is marked 'done'. Once the processing
#    of known keys is complete for the level, any not 'done' working hash keys
#    are processed. This helps to minimize future code changes when new preset 
#    keys are added.
#
# CALLING SYNTAX:
#    $result = &FormatPreset(\%Preset, $Pid);
#
# ARGUMENTS:
#    $Preset        Pointer to decoded_json data hash.
#    $Pid           Pid being processed.
#
# RETURNED VALUES:
#    <str> = Serialized data string,  '' = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub FormatPreset {
   my($JsonRef, $Pid) = @_;
   my($tab) = ' ' x 3;
   my(@order);
   my($segCount) = 32;                  # Segment down counter.
   my($spData) = '"' . $Pid . '":{';    # Start serealized preset data.
   
   # -------------------------------------------------
   if (exists($$JsonRef{'playlist'})) {
      # Get all of the playlist level 1 keys that are present in the input hash.
      # Used this to process unknown key:value pairs (not in @order). Also used
      # to indicate we've processed the key:value pair; set to 'done'. 
      my(%done1) = ();
      $done1{$_} = '' foreach (keys( %{$JsonRef} ));  # Initialize working hash.
      @order = ('on','n','ql','playlist');            # Key process order.
      
      # Process playlist data level 1. Last key checked must be 'playlist'. Then
      # add any unknown keys at this level.
      foreach my $key (@order) {   
         if (exists($$JsonRef{$key})) {
            if ($key eq 'playlist') {
               $done1{$key} = 'done';
               foreach my $udn (keys(%done1)) {          # Check/process undone keys.
                  next if ($done1{$udn} ne '');
                  my $value = &CheckVarType('p', $udn, $$JsonRef{$udn});
                  $spData .= join('', '"', $udn, '":', $value, ',');
                  $done1{$udn} = 'done';
               }
               $spData .= join('', '"', $key, '":{');
               last;
            }
            else {
               my $value = &CheckVarType('p', $key, $$JsonRef{$key});
               $spData .= join('', '"', $key, '":', $value, ',');
               $done1{$key} = 'done';
            }
         }
         else {
            $done1{$key} = 'ignore';
         }
      }
      # Process playlist data level 2.
      $playref = $$JsonRef{'playlist'};                    # playlist array reference
      %done2 = ();
      $done2{$_} = '' foreach (keys( %{$playref} ));       # Initialize working hash.
      @order = ('ps','dur','transition','r','repeat','end'); 
      foreach my $key (@order) {
         if (exists($playref->{$key})) {
            if (($key eq 'transition' or $key eq 'dur' or $key eq 'ps') and 
                ref($playref->{$key}) eq 'ARRAY') {
               $spData .= join('', "\n$tab", '"', $key, '":[');
               $spData .= join(',', @{$playref->{$key}});
               $spData .= '],';
               $done2{$key} = 'done';
            }
            else {
               my $value = &CheckVarType('p', $key, $playref->{$key});
               if ($key eq 'r') {
                  $spData .= join('', "\n$tab", '"', $key, '":', $value, ',');
               } 
               else {
                  $spData .= join('', '"', $key, '":', $value, ',');
               }
               $done2{$key} = 'done';
            }
         }
         else {
            $done2{$key} = 'ignore';
         }
      }
      foreach my $key (keys(%done2)) {             # Check/process undone keys.
         next if ($done2{$key} ne '');
         my $value = &CheckVarType('p', $key, $playref->{$key});
         $spData .= join('', '"', $key, '":', $value, ',');
         $done2{$key} = 'done';
      }
      $spData =~ s/,$//;
      # Playlist complete!
      $spData .= "}" if (exists($$JsonRef{'playlist'}));  # close playlist
      $spData .= "}";                                     # close json
   }
   else {
      # -------------------------------------------------
      # Get all of the preset level 1 keys that are present in the input hash.
      # Used to process unknown key:value pairs (not in @order1). Also used
      # to indicate we've processed the key:value pair; set to 'done'. 
      my(%done1) = ();
      $done1{$_} = '' foreach (keys( %{$JsonRef} ));  # Initialize working hash.
      @order = ('on','n','ql','bri','transition','mainseg','ledmap','seg');   
      
      # Process preset data level 1. Last key checked must be 'seg'. Then add
      # any unknown keys at this level.
      foreach my $key (@order) {                      # 1st line keys
         if (exists($$JsonRef{$key})) {
            if ($key eq 'seg') {
               $done1{$key} = 'done';
               foreach my $udn (keys(%done1)) {       # Check/process undone keys.
                  next if ($done1{$udn} ne '');
                  my $value = &CheckVarType('p', $udn, $$JsonRef{$udn});
                  $spData .= join('', '"', $udn, '":', $value, ',');
                  $done1{$udn} = 'done';
               }
               $spData .= join('', '"', $key, '":[', "\n");
               last;
            }
            else {
               if (exists($$JsonRef{$key})) {
                  my $value = &CheckVarType('p', $key, $$JsonRef{$key});
                  $spData .= join('', '"', $key, '":', $value, ',');
               }
               $done1{$key} = 'done';
            }
         }
         else {
            $done1{$key} = 'ignore';
         }
      }
      
      # Process preset data level 2 if input has 'seg'.
      if (exists($$JsonRef{'seg'})) {
         foreach my $segref (@{ $$JsonRef{'seg'} }) {     # Process each segment.
            %done2 = ();
            $done2{$_} = '' foreach (keys(%{$segref}));   # Initialize working hash.
            # Ignore segments with 'stop' and no 'id'. We'll add them later.  
            next if (exists($done2{'stop'}) and not exists($done2{'id'}));
            
            $spData .= "$tab\{";
            @order = ('id','start','stop','grp','spc','of','on','bri','frz');
            foreach my $key (@order) {                    # 2nd line keys
               if (exists($segref->{$key})) {
                  my $value = &CheckVarType('p', $key, $segref->{$key});
                  $spData .= join('', '"', $key, '":', $value, ',');
                  $done2{$key} = 'done';
               }
               else {
                  $done2{$key} = 'ignore';
               }
            }
            $spData .= "\n$tab";
            @order = ('col','fx','sx','ix','pal','rev','c1','c2','c3','sel');
            foreach my $key (@order) {                     # 3rd line keys
               if (exists($segref->{$key})) {
                  if ($key eq 'col') {                     # col is array of arrays
                     $spData .= join('', '"', $key, '":[');
                     foreach my $colref (@{ $segref->{'col'} }) { # Each color group.
                        $spData .= join('', "[", join(',', @{$colref}), "],");
                     }
                     $spData =~ s/,\n*\s*$//;
                     $spData .= '],';
                     $done2{$key} = 'done';
                  }
                  else {
                     my $value = &CheckVarType('p', $key, $segref->{$key});
                     $spData .= join('', '"', $key, '":', $value, ',');
                     $done2{$key} = 'done';
                  }
               }
               else {
                  $done2{$key} = 'ignore';
               }
            }
            $spData .= "\n$tab";
            @order = ('set','n','o1','o2','o3','si','m12','mi','cct'); 
            foreach my $key (@order) {                         # 4th line keys
               if (exists($segref->{$key})) {
                  my $value = &CheckVarType('p', $key, $segref->{$key});
                  $spData .= join('', '"', $key, '":', $value, ',');
                  $done2{$key} = 'done';
               }
               else {
                  $done2{$key} = 'ignore';
               }               
            }
               
            foreach my $key (keys(%done2)) {      # Check/process undone keys.
               next if ($done2{$key} ne '');
               my $value = &CheckVarType('p', $key, $segref->{$key});
               $spData .= join('', '"', $key, '":', $value, ',');
               # Don't mark these done so next segment gets them added too.
            }
            $spData =~ s/,\n*\s*$//;   # This segment is done!
            $spData .= "},\n";
            $segCount--;             # Decrement the segment down counter.
         }
         
         # Add {"stop":0} for all remaining unused segments. Unsure why this
         # is needed by WLED. Skip this step if no segments.
         if (exists($$JsonRef{'seg'})) {
            my $stopCnt = 10;        # Number of stops per line.
            $spData .= $tab;         # Indent 1st line.
            while ($segCount > 0) {
               if ($stopCnt == 0) {
                  $stopCnt = 9;
                  $spData .= "\n$tab" . '{"stop":0},';
               }
               else {
                  $spData .= '{"stop":0},';
                  $stopCnt--;
               }
               $segCount--;
            }
         }
         # All segments are done!
         $spData =~ s/,\n*\s*$//;
         $spData .= ']';      # close the segments array.
      }
      $spData =~ s/,\n*\s*$//;
      $spData .= '}';         # close the preset definition.
   }
   # Make sure the formatted JSON is valid. We need to wrap the string with {}
   # for the validity check.
   my $check = join('', '{' ,$spData, '}');
   return '' if (&ValidateJson('', \$check, '', ''));
   return $spData;
}
   
# =============================================================================
# FUNCTION:  CheckVarType
#
# DESCRIPTION:
#    This routine returns boolean values as 'true'/'false' and encloses strings
#    in double quotes. Any undefined key is returned as a string.  
#
# CALLING SYNTAX:
#    $var = &CheckVarType($Group, $Key, $Value);
#
# ARGUMENTS:
#    $Group       'c' (config) or 'p' (preset).
#    $Key         Key being processed.
#    $Value       Value being processed.   
#
# RETURNED VALUES:
#    Processed value.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub CheckVarType {
   my($Group, $Key, $Value) = @_;
   
   if ($Group =~ m/p/i) {
      my(%bool) = ('on'=>1,'rev'=>1,'frz'=>1,'r'=>1,'sel'=>1,'mi'=>1,'nl.on'=>1,
         'rY'=>1,'mY'=>1,'tp'=>1,'send'=>1,'sgrp'=>1,'rgrp'=>1,'nn'=>1,'live'=>1);
      my(%nmbr) = ('id'=>1,'start'=>1,'stop'=>1,'grp'=>1,'spc'=>1,'of'=>1,'bri'=>1,
         'col'=>1,'fx'=>1,'sx'=>1,'ix'=>1,'pal'=>1,'c1'=>1,'c2'=>1,'c3'=>1,'set'=>1,
         'o1'=>1,'o2'=>1,'o3'=>1,'si'=>1,'m12'=>1,'cct'=>1,'transition'=>1,'tt'=>1,
         'tb'=>1,'ps'=>1,'psave'=>1,'pl'=>1,'pdel'=>1,'nl.dur'=>1,'nl.mode'=>1,
         'nl.tbri'=>1,'lor'=>1,'rnd'=>1,'rpt'=>1,'mainseg'=>1,'startY'=>1,'stopY'=>1,
         'rem'=>1,'recv'=>1,'w'=>1,'h'=>1,'lc'=>1,'rgbw'=>1,'wv'=>1, 'ledmap'=>1);
      my(%str) = ('n'=>1,'ql'=>1,'ver'=>1,'vid'=>1,'cn'=>1,'release'=>1);
      if (exists($bool{$Key})) {
         return 'true' if ($Value > 0);
         return 'false';
      }
      elsif (exists($nmbr{$Key})) {
         return $Value;
      }
      else {
         return join('', '"', $Value, '"');
      }
   }
   elsif ($Group =~ m/c/i) {
   }
   return $Value;
}

# =============================================================================
# FUNCTION:  PostJson
#
# DESCRIPTION:
#    This routine is used to POST the JSON formatted data specified by $Json
#    to the specified URL; typically http://<wled-ip>/json/state. 
#
#    my($agent) defines the POST user agent string. decode_json is used to 
#    validate the json payload. The POST is retried up to 3 times before 
#    returning error.
#
# CALLING SYNTAX:
#    $result = &PostJson($Url, $Json);
#
# ARGUMENTS:
#    $Url            Endpoint URL.
#    $Json           Json formatted data to POST
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub PostJson {
   my($Url, $Json, $Resp) = @_;
   my($request, $response, @data);
   my($agent) = "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, " .
                "like Gecko) Chrome/89.0.4389.114 Safari/537.36";
   my($retry) = 3;
   my($exitCode) = 0;
   &DisplayDebug("PostJson: $Url   Json: '$Json'");

   my $userAgent = LWP::UserAgent->new(
      timeout => 5, agent => $agent, protocols_allowed => ['http',]);
   if ($Json ne '') {
      if (&ValidateJson('', \$Json, '', '')) {
         $exitCode = 1;
      }
      else {
         while ($retry > 0) {
            $response = $userAgent->post($Url,
               Content_Type => 'application/json',
               Content => "$Json"
            );
            last if ($response->is_success);
            $retry--;
            if ($retry == 0) {
               &ColorMessage("HTTP POST $Url", "BRIGHT_RED", '');
               &ColorMessage("HTTP POST error: " . $response->code, "BRIGHT_RED", '');
               &ColorMessage("HTTP POST error: " . $response->message .
                             "\n","BRIGHT_RED", '');
               $exitCode = 1;
            }
            else {
               &ColorMessage("PostJson - POST retry ...", "CYAN", '');
               sleep 1;       # Wait a bit for network stabilization.
            }
         }
      }
   }
   else {
      &ColorMessage("PostJson - No JSON data specified.", "BRIGHT_RED", '');
      $exitCode = 1;
   }
   undef($userAgent);
   return $exitCode;
}

# =============================================================================
# FUNCTION:  PostUrl
#
# DESCRIPTION:
#    This routine is used to POST the JSON formatted data specified by $File 
#    to the specified URL; typically http://<wled-ip>/upload.
#
#    Note that WLED parses the file name in the POST header to know how to 
#    handle the incoming data. The caller must ensure the specified file is 
#    correctly named; cfg.json, presets.json, or or palette<d>.json where
#    <d> = 0-9.
#
#    my($agent) defines the POST user agent string. decode_json is used to 
#    validate the json payload. The POST is retried up to 3 times before 
#    returning error.
#
# CALLING SYNTAX:
#    $result = &PostUrl($Url, $File);
#
# ARGUMENTS:
#    $Url            Endpoint URL.
#    $File           File to POST
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub PostUrl {
   my($Url, $File) = @_;
   my($request, $response, @data);
   my($agent) = "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, " .
                "like Gecko) Chrome/89.0.4389.114 Safari/537.36";
   my($retry) = 3;
   my($exitCode) = 0;
   &DisplayDebug("PostUrl: $Url   File: '$File'");

   my $userAgent = LWP::UserAgent->new(
      timeout => 10, agent => $agent, protocols_allowed => ['http',]);
   if (-e $File) {
      return 1 if (&ReadFile($File, \@data, 'trim'));
      if (&ValidateJson(\@data, '', '', '')) {
         $exitCode = 1;
      }
      else {
         &DisplayDebug("HTTP POST data: '@data'");
         
         # If a palette, check syntax and color codes.
         if ($check =~ m/"palette":\[(.+)\]/s) {
            $check =~ s/\s//g;
            my @codes = split(',', $1);
            for (my $x = 0; $x <= $#codes; $x++) {
               if (($x % 2) == 0) {
                  $exitCode = 1 unless ($codes[$x] =~ m/^\d+$/);
                  $exitCode = 1 if ($codes[$x] < 0 or $codes[$x] > 255);
               }
               else {
                  $exitCode = 1 unless ($codes[$x] =~ m/^"[0123456789abcdefABCDEF]{6}"$/);
               }
               last if ($exitCode == 1);
            }
            # All entries must be paired; offset and color code.
            $exitCode = 1 if ((scalar(@codes) % 2) == 1);
            if ($exitCode == 1) {
               &ColorMessage("PostUrl - Invalid palette: $check", "BRIGHT_RED", '');
               return $exitCode;
            }
         }
         
         # Send the data to WLED.
         while ($retry > 0) {
            $response = $userAgent->post($Url,
               Content_Type => 'form-data',
               Content => [ data => [ $File ],],
            );
            last if ($response->is_success);
            $retry--;
            if ($retry == 0) {
               &ColorMessage("HTTP POST $Url", "BRIGHT_RED", '');
               &ColorMessage("HTTP POST error: " . $response->code, "BRIGHT_RED", '');
               &ColorMessage("HTTP POST error: " . $response->message .
                             "\n","BRIGHT_RED", '');
               $exitCode = 1;
            }
            else {
               &ColorMessage("PostUrl - POST retry ...", "CYAN", '');
               sleep 1;       # Wait a bit for network stabilization.
            }
         }
      }
   }
   else {
      &ColorMessage("PostUrl - File not found: $File", "BRIGHT_RED", '');
      $exitCode = 1;
   }
   undef($userAgent);
   return $exitCode;
}

# =============================================================================
# FUNCTION:  GetUrl
#
# DESCRIPTION:
#    This routine performs a GET using the specified URL and returns the 
#    response data in the specified array.
# 
#    my($agent) defines the GET user agent string. decode_json is used to 
#    validate the response data. The GET is retried up to 3 times before 
#    returning error.
#
# CALLING SYNTAX:
#    $result = &GetUrl($Url, $Resp);
#
# ARGUMENTS:
#    $Url            Endpoint URL.
#    $Resp           Pointer to response array.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error, 2 = Palette not found.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::cliOpts{r}
# =============================================================================
sub GetUrl {
   my($Url, $Resp) = @_;
   my($request, $response, @data);
   my($agent) = "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, " .
                "like Gecko) Chrome/89.0.4389.114 Safari/537.36";
   my($retry) = 3;
   my($exitCode) = 0;
   &DisplayDebug("GetUrl: $Url");
   
   my $userAgent = LWP::UserAgent->new(
      timeout => 10, agent => $agent, protocols_allowed => ['http',]);
   while ($retry > 0) {
      $response = $userAgent->get($Url,
         Content_Type => 'application/json'
      );
      last if (exists( $main::cliOpts{r} ));    # Done if WLED API reset.
      
      # Process response.
      @$Resp = ();                         # Clear previous response.
      if ($response->is_success) {
         @data = $response->decoded_content;
         s/[^\x00-\x7f]/\./g foreach (@data);  # Replace 'wide' chars with .
         if (&ValidateJson(\@data, '', 'clean', '')) {
            &ColorMessage("GetUrl - Invalid json data. Retry Get ...", "CYAN", '');
            $retry--;
            if ($retry == 0) { 
               &ColorMessage("GetUrl - $@", "WHITE", '');
#               &ColorMessage("GetUrl - '$check'", "WHITE", '');
               $exitCode = 1;
            }
            else {
               sleep 1;       # Wait a bit for network stabilization.
            }
         }
         else {
            push (@$Resp, @data);
            last;
         }
      }
      else {
         # Request for a palette.json or ledmap.json beyond the last 
         # available will return 404 status. In this case, suppress 
         # error report and return 2.
         my $code = $response->code; 
         if (($Url =~ m/palette\d\.json$/ or $Url =~ m/ledmap\d\.json$/) 
             and $code == 404) {
            $exitCode = 2;
            last;
         }
         else {  
            $retry--;
            if ($retry == 0) { 
               &ColorMessage("HTTP GET $Url", "BRIGHT_RED", '');
               &ColorMessage("HTTP GET error code: " . $response->code, "BRIGHT_RED", '');
               &ColorMessage("HTTP GET error message: " . $response->message .
                             "\n","BRIGHT_RED", '');
               $exitCode = 1;
            }
            else {
               &ColorMessage("GetUrl - GET retry ...", "CYAN", '');
               sleep 1;       # Wait a bit for network stabilization.
            }
         }
      }
   }
   undef($userAgent);
   return $exitCode;
}

# =============================================================================
# FUNCTION:  ShowPreset
#
# DESCRIPTION:
#    This routine is called by AuditionPresets to display the current WLED 
#    active preset and playlist to the user. The PresetIds hash is used to
#    add the preset/playlist name to the output.
#
# CALLING SYNTAX:
#    $result = &ShowPreset($WledUrl, \%PresetIds, $Color, $Nocr);
#
# ARGUMENTS:
#    $WledUrl        URL of WLED.
#    $PresetIds      Pointer to preset id hash.
#    $Color          Message color; default 'WHITE'.
#    $Nocr           Optional; suppress final message cr.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ShowPreset {
   my($WledUrl, $PresetIds, $Color, $Nocr) = @_;
   my(@resp) = ();
   $Color = 'WHITE' if ($Color eq '');
   
   return 1 if (&GetUrl(join("/", $WledUrl, 'json', 'state'), \@resp));
   my $s_ref = decode_json(join('', @resp));
   my $ps = $s_ref->{'ps'};
   my $pl = $s_ref->{'pl'};
   if ($ps > 0) {
      my $pname = $$PresetIds{$ps}{'name'};
      if ($pl <= 1) {
         &ColorMessage("Active preset: $ps '$pname'", $Color, "$Nocr");
      }
      else {
         &ColorMessage("Active preset: $ps '$pname'", $Color, 'nocr');
         $pname = $$PresetIds{$pl}{'name'};
         &ColorMessage("of playlist: $pl '$pname'", $Color, "$Nocr");
      }
   }
   else {
      &ColorMessage("Active preset: 0 'default'", $Color, "$Nocr");
   }
   return 0;
}

# =============================================================================
# FUNCTION:  AuditionHead
#
# DESCRIPTION:
#    This routine is called by AuditionPresets to display the heading text.
#    Called during startup of audition mode and in response to user entry of
#    the 'h' command.
#
# CALLING SYNTAX:
#    $result = &AuditionHead($WledUrl, \%PresetIds);
#
# ARGUMENTS:
#    $WledUrl        URL of WLED.
#    $PresetIds      Pointer to preset id hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub AuditionHead {
   my($WledUrl, $PresetIds) = @_;
   my(@resp) = ();
   
   # Get WLED info from WLED. Selected parts are displayed in the header.
   return 1 if (&GetUrl(join("/", $WledUrl, , 'json', 'info'), \@resp));
   my $i_ref = decode_json(join('', @resp));
   my $ver = $i_ref->{'ver'};
   my $vid = $i_ref->{'vid'};
   my $rev = $i_ref->{'release'};
   my $heap = $i_ref->{'freeheap'};
   my $fsu = $i_ref->{'fs'}{'u'};
   my $fst = $i_ref->{'fs'}{'t'};
   my $cap = sprintf("%.0f%", ($fsu/$fst)*100);
   my $chan = $i_ref->{'wifi'}{'channel'};
   my $sig = $i_ref->{'wifi'}{'signal'};
   my $mpwr = $i_ref->{'leds'}{'maxpwr'};

   # Show user the available presets and associated Id.
   my $col = 0;   my $cols = 3;
   my $line = '=' x 75;
   &ColorMessage("\n$line", "WHITE", '');
   &ColorMessage("WLED version: $ver   build: $vid   $rev", "WHITE", '');
   &ColorMessage("WLED Filesystem: $fsu/$fst kB ($cap)   Free heap: $heap kB"
                 , "WHITE", '');
   &ColorMessage("Wifi chan: $chan   Wifi signal: $sig%     ", "WHITE", 'nocr');
   if ($mpwr > 0) {
      &ColorMessage("Max LED current: $mpwr mA", "WHITE", '');
   }
   else {
      &ColorMessage("Max LED current: unlimited", "WHITE", '');
   }

   if (%$PresetIds) {
      &ColorMessage("\nWLED presets available for audition:", "WHITE", '');
      foreach my $id (sort {$a <=> $b} keys(%$PresetIds)) {
         next if ($id == 0);
         &ColorMessage('  ' . substr("  $id", -3) . " ", "WHITE", 'nocr');
         &ColorMessage(substr($$PresetIds{$id}{'name'} . ' ' x 20, 0, 20), 
                              $$PresetIds{$id}{'color'}, 'nocr');
         $col++;
         if ($col == $cols) {
            &ColorMessage("", "CYAN", '');
            $col = 0;
         }
      }
      &ColorMessage("", "WHITE", '') if ($col != 0);
   }
   else {
      &ColorMessage("\nNo presets found.", "YELLOW", '');
   }
   &ColorMessage("\nFor a custom playlist enter: p <n>,<n> d <s>", "WHITE", '');
   &ColorMessage("Default brightness: db <n> (1-255)", "WHITE", '');
   &ColorMessage("Power-on-preset: dp <n> (1-250)", "WHITE", '');
   &ColorMessage("LED brightness: b <n> (1-255) or b +/-<n>", "WHITE", '');
   &ColorMessage("Effect speed: s <seg> <n> (0-255) or s <seg> +/-<n>", "WHITE", '');
   &ColorMessage("Effect intensity: i <seg> <n> (0-255) or i <seg> +/-<n>", "WHITE", '');
   &ColorMessage("Active fps and power: f", "WHITE", '');
   &ColorMessage("Reboot WLED: r", "WHITE", '');
   &ColorMessage("Help: h", "WHITE", '');
   &ColorMessage("$line", "WHITE", '');
   return 0;
}

# =============================================================================
# FUNCTION:  AuditionCmd
#
# DESCRIPTION:
#    This routine is called to process some user entered audition mode (-i)
#    commands. These are commands which support numeric value input such as
#    brightness (b), effect speed (s), and effect intensity (i). 
#
#    For a command with no value specified, the current WLED setting for the
#    command will be displayed. A command with a value with set the specified
#    absolute value. Command with value preceeded by + or - applies the value
#    as a relative change to the current value.
#    
# CALLING SYNTAX:
#    $result = &AuditionCmd($WledUrl, $PresetIds, $Cmd);
#
# ARGUMENTS:
#    $WledUrl        URL of WLED.
#    $PresetIds      Pointer to %presetIds hash. (for preset names).
#    $Cmd            Command to be processed.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error, 2 = No command found.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub AuditionCmd {
   my($WledUrl, $PresetIds, $Cmd) = @_;
   my(@resp) = ();

   if ($Cmd =~ m/^b/ or $Cmd =~ m/^s/ or $Cmd =~ m/^i/) {
      # Get WLED state data with current values.
      return 1 if (&GetUrl(join("/", $WledUrl, 'json', 'state'), \@resp));
      my $s_ref = decode_json(join('', @resp));
      # $Data::Dumper::Sortkeys = 1;
      # print Dumper $s_ref;
         
      # Get valid preset segment numbers.
      my @validSeg = ();
      foreach my $segref (@{ $s_ref->{'seg'} }) {
         push (@validSeg, $segref->{'id'});
      }
      &DisplayDebug("Valid segment ids: '@validSeg'");

      # ==========
      if ($Cmd =~ m/^b$/i) {           # b with no value
         &ColorMessage("LED brightness is: $s_ref->{'bri'}", "CYAN", '');
         return 0;
      }
      elsif ($Cmd =~ m/^b\s*([\+|\-]*[0-9]+)/i) {   # User wants brightness change.
         my $bri = $s_ref->{'bri'};
         my $val = $1;
         if ($val =~ m/^[\+|\-]/) {        # relative value?
            $bri += $val;
         }
         else {
            $bri = $val;
         }
         $bri = 1 if ($bri < 1);
         $bri = 255 if ($bri > 255);
         $s_ref->{'bri'} = $bri;
         return 1 if (&PostJson(join("/", $WledUrl, "json/state"), 
                      qq({"on":true,"bri": $bri})));
         &ColorMessage("LED brightness set to: $bri", "CYAN", '');
         return 0;
      }
      # ==========
      elsif ($Cmd =~ m/^s$/i or $Cmd =~ m/^i$/i) {      # s or i with no value
         foreach my $segref (@{ $s_ref->{'seg'} }) {    # Show user current values.
            &ColorMessage("  seg: $segref->{'id'}   sx: $segref->{'sx'}   " .
                          "ix: $segref->{'ix'}", "CYAN", '');
         }
         return 0;
      }
      elsif ($Cmd =~ m/^s\s*([0-9]+)\s([\+|\-]*[0-9]+)/i) {  # User wants s change.
         my $seg = $1;   my $val = $2;
         if (grep /$seg/, @validSeg) {
            my $segref = @{ $s_ref->{'seg'} }[$seg];
            my $sx = $segref->{'sx'};                      # current value
            &DisplayDebug("seg: $seg   val: '$val'   sx: '$sx'");
            if ($val =~ m/^[\+|\-]/) {        # relative value?
               $sx += $val;
            }
            else {
               $sx = $val;
            }
            $sx = 255 if ($sx > 255);
            $sx = 0 if ($sx < 0);
            $segref->{'sx'} = $sx;
            last if (&PostJson(join("/", $WledUrl, "json/state"), 
                        qq({"seg":[{"id":$seg,"sx":$sx}]})));
            &ColorMessage("Segment $seg sx set to: $sx", "CYAN", '');
            return 0;
         }
         else {
            &ColorMessage("Invalid segment: $seg   ", "BRIGHT_RED", 'nocr');
            return 2;
         }
      }
      elsif ($Cmd =~ m/^i\s*([0-9]+)\s([\+|\-]*[0-9]+)/i) {  # User wants s change.
         my $seg = $1;   my $val = $2;
         if (grep /$seg/, @validSeg) {
            my $segref = @{ $s_ref->{'seg'} }[$seg];
            my $ix = $segref->{'ix'};                      # current value
            &DisplayDebug("seg: $seg   val: '$val'   ix: '$ix'");
            if ($val =~ m/^[\+|\-]/) {        # relative value?
               $ix += $val;
            }
            else {
               $ix = $val;
            }
            $ix = 255 if ($ix > 255);
            $ix = 0 if ($ix < 0);
            $segref->{'ix'} = $ix;
            last if (&PostJson(join("/", $WledUrl, "json/state"), 
                        qq({"seg":[{"id":$seg,"ix":$ix}]})));
            &ColorMessage("Segment $seg ix set to: $ix", "CYAN", '');
            return 0;
         }
         else {
            &ColorMessage("Invalid segment: $seg   ", "BRIGHT_RED", 'nocr');
            return 2;
         }
      }
   }
   elsif ($Cmd =~ m/^db/ or $Cmd =~ m/^dp/) {
      # Get the WLED configuration data.
      return 1 if (&GetUrl(join("/", $WledUrl, 'cfg.json'), \@resp));
      my $c_ref = decode_json(join('', @resp));
      # $Data::Dumper::Sortkeys = 1;
      # print Dumper $c_ref;

      # ==========
      if ($Cmd =~ m/^db$/i) {            # db with no value
         &ColorMessage("Default LED brightness is: $c_ref->{'def'}{'bri'}", "CYAN", '');
         return 0;
      }
      elsif ($Cmd =~ m/^db\s*([0-9]+)/i) {  # User wants default brightness change.
         my $val = $1;
         $val = 1 if ($val < 1);
         $val = 255 if ($val > 255);
         return 1 if (&PostJson(join("/", $WledUrl, "json/cfg"), 
                      qq({"def":{"on":true,"bri":$val}})));
         &ColorMessage("Set default LED brightness to: $val", "CYAN", '');
         return 0;
      }
      # ==========
      elsif ($Cmd =~ m/^dp$/i) {            # dp with no value
         my $ps = $c_ref->{'def'}{'ps'};
         my $pname = $$PresetIds{$ps}{'name'};
         &ColorMessage("Power-on-preset is: $ps '$pname'", "CYAN", '');
         return 0;
      }
      elsif ($Cmd =~ m/^dp\s*([0-9]+)/i) {  # User wants power-on-preset change.
         my $val = $1;
         $val = 1 if ($val < 1);
         $val = 255 if ($val > 255);
         return 1 if (&PostJson(join("/", $WledUrl, "json/cfg"), 
                      qq({"def":{"on":true,"ps":$val}})));
         my $pname = $$PresetIds{$val}{'name'};
         &ColorMessage("Power-on-preset set to: $val '$pname'", "CYAN", '');
         return 0;
      }
   }
   elsif ($Cmd =~ m/^f$/i) {                # Show user WLED frame rate.
      # Show active preset/playlist.
      return 1 if (&ShowPreset($WledUrl, $PresetIds, 'CYAN', 'nocr'));
      # Get active fps/power usage.
      return 1 if (&GetUrl(join("/", $WledUrl, , 'json', 'info'), \@resp));
      $i_ref = decode_json(join('', @resp));
      my $fps = $i_ref->{'leds'}{'fps'};
      my $pwr = sprintf("%.1f", $i_ref->{'leds'}{'pwr'} / 1000);
      &ColorMessage("  fps: $fps  pwr: $pwr A", "CYAN", '');
      return 0;
   }
   elsif ($Cmd =~ m/^r/i) {                # User wants a WLED reset.
       return 1 if (&PostJson(join("/", $WledUrl, "json/state"), 
                    qq({"on":true,"rb":true})));
      &ColorMessage("Reset sent to WLED. Wait ~15 sec for network reconnect." ,
                    "YELLOW", '');
      return 0;
   }
   return 2;
}

# =============================================================================
# FUNCTION:  AuditionPresets
#
# DESCRIPTION:
#    This routine gets the presets data from WLED and displays the available
#    preset names and associated Id. An interactive loop is then entered that
#    requests a preset Id or other supported sub-command input. 
#
#    A user entered preset Id value, custom playlist (p), or loop termination
#    command (q ord e) are processed by this subroutine. Other sub-command 
#    input is processed by a called subroutine.
#
# CALLING SYNTAX:
#    $result = &AuditionPresets($WledUrl);
#
# ARGUMENTS:
#    $WledUrl        URL of WLED.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub AuditionPresets {
   my($WledUrl) = @_;
   my(@resp) = ();   my(%presetIds) = ();

   # Get available presets from WLED and load the working hash.
   return 1 if (&GetUrl(join("/", $WledUrl, "presets.json"), \@resp));
   my $p_ref = decode_json(join('', @resp));
   # $Data::Dumper::Sortkeys = 1;
   # print Dumper $p_ref;
   
   foreach my $id (keys(%$p_ref)) {
      if ($id == 0) {
         $presetIds{$id}{'name'} = 'default';
         next;
      }
      $presetIds{$id}{'name'} = $p_ref->{$id}{'n'};
      if (exists($p_ref->{$id}{'playlist'})) {
         $presetIds{$id}{'color'} = 'GREEN';
         my $playref = $p_ref->{$id}{'playlist'};
         if (ref($playref->{'ps'}) eq 'ARRAY') {
            $presetIds{$id}{'plist'} = join(',', @{$playref->{'ps'}});
         }
         else {
            $presetIds{$id}{'plist'} = $playref->{'ps'};
         }
         if (ref($playref->{'dur'}) eq 'ARRAY') {
            $presetIds{$id}{'dur'} = join(',', @{$playref->{'dur'}});
         }
         else {
            $presetIds{$id}{'dur'} = $playref->{'dur'};
         }
      }
      else {
         $presetIds{$id}{'color'} = 'CYAN';
      }
   }
   # print Dumper \%presetIds;
   
   # Show heading data.
   return 1 if (&AuditionHead($WledUrl, \%presetIds));

   # Get user input and process.
   while (1) {
      &ColorMessage("Command, preset number, or q to quit. -> ", "WHITE", 'nocr');
      my $preset = <STDIN>;
      chomp($preset);
      next if ($preset eq '');
      last if ($preset =~ m/^q/i or $preset =~ m/^e/i);    # Accept quit or exit.
      if ($preset =~ m/^h/i) {
         return 1 if (&AuditionHead($WledUrl, \%presetIds));
         next;
      }
      
      # ==========
      if ($preset =~ m/^(\d+)$/) {    # User wants a single preset.
         my $id = $1;
         if (exists($presetIds{$id})) {
            if (exists($presetIds{$id}{'plist'})) {
               &ColorMessage("Playlist ids: $presetIds{$id}{'plist'}", "GREEN", '');
               my @durs = split(',', $presetIds{$id}{'dur'});
               my @durSec = ();
               foreach my $dur (@durs) {
                  push (@durSec, sprintf("%.1fs", $dur / 10));
               }
               &ColorMessage("Playlist dur: " . join(',', @durSec), "GREEN", '');
            }
            else {
               my $pname = $presetIds{$id}{'name'};
               &ColorMessage("Set preset: $id '$pname'", "CYAN", '');
            }
            last if (&PostJson(join("/", $WledUrl, "json/state"), qq({"ps": $id})));
         }
         else {
            &ColorMessage("Invalid preset Id: $id", "BRIGHT_RED", '');
         }
      }

      # ==========
      elsif ($preset =~ m/^p/i) {           # User wants a custom playlist.
         my @pset = ();  my $dur = 15;
         # Isolate presets.
         if ($preset =~ m/p\s([0-9,]+)/i) {
            my $list = $1;
            $list =~ s/^,//;
            @pset = split(',', $list);
            # Get duration if specified.
            if ($preset =~ m/\sd\s(\d+)/i) {
               $dur = $1 unless ($1 < 1 or $1 > 3600);
            }
         }
         &DisplayDebug("pset: '@pset'   dur: '$dur'");
         if ($#pset >= 0) {
            # Validate presets.
            my $valid = 1;
            foreach my $id (@pset) {
               unless (exists($presetIds{$id})) {
                  &ColorMessage("Invalid preset Id: $id", "BRIGHT_RED", '');
                  $valid = 0;
                  last;
               }
            }
            # Build JSON and POST it.
            if ($valid) {
               $dur = $dur * 10;     # Duration is in tenths of a second.
               my $json = '{"playlist": {"ps": [' . join(',', @pset) .
                  '],"dur": [' . $dur . '],"transition": 0,"repeat": 0}}';
               last if (&PostJson(join("/", $WledUrl, "json/state"), $json));
               &ColorMessage("Custom playlist ids: " . join(',', @pset), "GREEN", '');
               $durSec = sprintf("%.1fs", $dur / 10);
               &ColorMessage("Playlist duration: $durSec", "GREEN", '');
            }
         }
         else {
            # p only. Show active preset/playlist.
            last if (&ShowPreset($WledUrl, \%presetIds, 'CYAN', ''));
         }
      }
      else {
         # Process audition mode commands.
         my $result = &AuditionCmd($WledUrl, \%presetIds, $preset);
         last if ($result == 1);
         if ($result == 2) {
            &ColorMessage("Invalid entry: '$preset'", "BRIGHT_RED", '');
         }
      }
      sleep 1;
   }
   &ColorMessage("", "WHITE", '');
   return 0;
}

# =============================================================================
# FUNCTION:  JsonData
#
# DESCRIPTION:
#    This routine sends the user specified JSON data to WLED. The JSON data to
#    send is contained in the specified file. Optional comment lines beginning
#    with the # character are permitted and will be removed from the data prior
#    to JSON transmission to WLED. The following examples of WLED JSON data, and
#    other examples, are found at https://kno.wled.ge/interfaces/json-api/. 
#
#    {"seg":{"fx":"r","pal":"r"}}
#       fx = Effect to apply, either a number or r for random.
#      pal = Palette to apply, either a number or r for random.
#
#    {"seg":{"i":["FF0000","00FF00","0000FF"]}}
#       Set segment LEDs to Red, Green, Blue.
#
#    {"seg":{"i":[0,"FF0000",2,"00FF00",4,"0000FF"]}} 
#       Set segment LEDs to Red, blank, Green, Blank, Blue.
#
#    {"seg":{"i":[0,8,"FF0000",10,18,"0000FF"]}} 
#       Set LED range; LEDs 0-7 red, 10-18 blue. 
#
#    {"seg": {"i":[0,"CC0000","00CC00","0000CC","CC0000"...]}} 
#    {"seg": {"i":[256,"CC0000","00CC00","0000CC","CC0000"...]}} 
#    {"seg": {"i":[512,"CC0000","00CC00","0000CC","CC0000"...]}}
#       Set large number of LEDs using multiple 256 parts.
#
# CALLING SYNTAX:
#    $result = &JsonData($Url, $File);
#
# ARGUMENTS:
#    $Url            Endpoint URL.
#    $File           File to POST
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub JsonData {
   my($Url, $File) = @_;

   &ColorMessage("JsonData - unimplimented feature.", "BRIGHT_YELLOW", '');
   return 0;
   
   if (-e $File) {
   }
   else {
      &ColorMessage("JsonData - File not found: $File", "BRIGHT_RED", '');
      return 1;
   }
   return 0;
}

# =============================================================================
# MAIN PROGRAM
# =============================================================================
# Process user specified CLI options.
my $allOpts = '';
foreach my $op (keys(%cliOpts)) {
   $allOpts = join('', $allOpts, $cliOpts{$op});
}

# ==========
# Display program help if -h specified or no other option.
if (exists( $cliOpts{h} ) or $allOpts eq '') {
   &ColorMessage("\nNo program option specified.", "BRIGHT_RED", '') if ($allOpts eq '');
   &ColorMessage("$UsageText", "WHITE", '');
   exit(0);  
}

# ==========
# Validate the json formatted content of the specified file.
if (exists( $cliOpts{v} )) {
   if (-e $cliOpts{v}) {
      my @data = ();
      exit(1) if (&ReadFile($cliOpts{v}, \@data, 'trim'));
      exit(1) if (&ValidateJson(\@data, '', '', ''));
      &ColorMessage("Valid json content in: $cliOpts{v}", "WHITE", '');
      exit(0);
   }
   else {
      &ColorMessage("File not found: $cliOpts{v}", "BRIGHT_RED", '');
      exit(1);
   }
}

# ==========
# Reformat the specified configuration or presets file. If debug -d option is
# is specified, the reformatted data is also output to the console.
if (exists( $cliOpts{f} )) {
   if (-e $cliOpts{f}) {
      my @inputData = ();
      exit(1) if (&ReadFile($cliOpts{f}, \@inputData, 'trim'));
      my $rawJson = join('', @inputData);
      exit(1) if (&ValidateJson('', \$rawJson, 'clean', ''));
      my $jsonRef = JSON->new->decode($rawJson);
      # $Data::Dumper::Sortkeys = 1;
      # print Dumper $jsonRef;
      my @fileData = ();
      if ($rawJson =~ m/wifi/i) {     # WLED cfg file?
         my @cfgKeys = sort keys( %{$jsonRef} );
#         &DisplayDebug("cfgKeys: '" . join(',', @cfgKeys) . "'");
         foreach my $key (@cfgKeys) {
            if (ref($jsonRef->{$key}) eq 'HASH' or ref($jsonRef->{$key}) eq 'ARRAY') {
               $value = JSON->new->canonical->encode($jsonRef->{$key});
            }
            else {
               # No ChkVarType cfg variables defined yet. Use p.
               $value = &CheckVarType('p', $key, $jsonRef->{$key});
            }
            $value = "$value," if ($key ne $cfgKeys[-1]);
            push (@fileData, join(':', qq("$key"), $value));
         }
      }
      else {                          # WLED preset file.
         my @presetIds = sort {$a <=> $b} keys( %{$jsonRef} );
#         &DisplayDebug("presetIds: '" . join(',', @presetIds) . "'");
         foreach my $pid (@presetIds) {
            my $formatted = &FormatPreset($jsonRef->{$pid}, $pid);
            $formatted = "$formatted," if ($pid != $presetIds[-1]);
            push (@fileData, split("\n", $formatted));
         }
      }
      
      # Add JSON container brackets to the data. If running in debug mode, send
      # data only to console. 
      unshift (@fileData, '{');
      push (@fileData, '}');
      if (exists($cliOpts{d})) {
         foreach my $rec (@fileData) {
            &ColorMessage("$rec", "WHITE", '');
         }
      }
      else {
         # Save initial file content in backup.
         my $backup = join('_', $cliOpts{f}, 'bak');
         unless (copy ($cliOpts{f}, $backup)) {
            &ColorMessage("Copy of $cliOpts{f} to $backup failed: $!", "BRIGHT_RED", '');
            exit(1);
         }
         exit(1) if (&WriteFile($cliOpts{f}, \@fileData, 'trim'));
         &ColorMessage("File $cliOpts{f} successfully reformatted.", "WHITE", '');
      }
   }
   else {
      &ColorMessage("File not found: $cliOpts{f}", "BRIGHT_RED", '');
   }
   exit(0);
}

# ==========
# Change WLED endpoint URL.
if (exists( $cliOpts{e} )) {
   if ($cliOpts{e} =~ m/(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/) {
      $WledIp = join('.', $1, $2, $3, $4);
   }
   else {
      &ColorMessage("Invalid IP specified: $cliOpts{e}", "BRIGHT_RED", '');
      exit(1);
   }
}

# ==========
# Verify endpoint is accessible.
if ($^O =~ m/Win/i) {                            # Windows environment?
   my $resp = `ping -w 1000 -n 1 -l 64 $WledIp 2>&1`;   # Windows ping
   unless ($resp =~ m/Reply from $WledIp/m) {
      &ColorMessage("No ping response from IP: $WledIp", "BRIGHT_RED", '');
      exit(1);
   }
}
else {
   my $resp = `ping -w 1 -c 1 -s 64 $WledIp 2>&1`;      # Linux ping
   unless ($resp =~ m/\d+ bytes from $WledIp/m) {
      &ColorMessage("No ping response from IP: $WledIp", "BRIGHT_RED", '');
      exit(1);
   }
}

our $WledUrl = "http://" . $WledIp;             # Working base URL

# ==========
# Run interactive preset audition if -i specified.
exit(&AuditionPresets($WledUrl)) if (exists( $cliOpts{i} ));

# ==========
# Backup WLED presets.
if (exists( $cliOpts{p} )) {
   my @resp = ();
   $cliOpts{p} = $Sections{'presets'} if ($cliOpts{p} eq '-');
   exit(1) if (&GetUrl(join("/", $WledUrl, "presets.json"), \@resp));
   exit(1) if (&ValidateJson(\@resp, '', 'clean','')); # Remove extra whitespace.
         
   # Display custom palette references, if any.
   my $temp = join('', @resp);
   my @pals = $temp =~ m/"pal":(\d{3})/g;
   foreach my $pal (@pals) {
      if ($pal > 245) {
         my $n = 255 - $pal;
         &ColorMessage("Custom palette reference $pal: palette${n}", "YELLOW", '');
      }
   }
         
   exit(1) if (&WriteFile($cliOpts{p}, \@resp, 'trim'));
   &ColorMessage("Preset backup $cliOpts{p} successfully created.", "WHITE", '');
}

# ==========
# Restore WLED presets. WLED parses presets.json. The user specified file is
# copied/renamed to the OS temp directory if named other than presets.json.
if (exists( $cliOpts{P} )) {
   $cliOpts{P} = $Sections{'presets'} if ($cliOpts{P} eq '-');
   if (-e $cliOpts{P}) {
      my $file = $cliOpts{P};
      exit(1) if (&ReadFile($file, \@data, 'trim'));
      unless (grep /"0":\{\},/, @data) {         # Check for preset 0 entry.
         &ColorMessage("File content doesn't look like WLED preset data. " .
                       "Continue? [y/N] -> ", "BRIGHT_YELLOW", 'nocr');
         my $resp = <STDIN>;
         exit(0) unless ($resp =~ m/y/i);
      }
      unless ($file eq 'presets.json') {
         my @data = ();
         my $path = &GetTmpDir();
         exit(1) if (&ReadFile($file, \@data, 'trim'));
         
         # Display custom palette references, if any.
         my $temp = join('', @data);
         my @pals = $temp =~ m/"pal":(\d{3})/g;
         foreach my $pal (@pals) {
            if ($pal > 245) {
               my $n = 255 - $pal;
               &ColorMessage("Custom palette reference $pal: palette${n}", "YELLOW", '');
            }
         }
         
         $file = join('/', $path,'presets.json');
         exit(1) if (&WriteFile($file, \@data, 'trim'));
      }
      exit(1) if (&PostUrl(join("/", $WledUrl, "upload"), $file));
      &ColorMessage("Presets successfully restored from $cliOpts{P}", "WHITE", '');
      unlink $file if ($file ne $cliOpts{P});   # Delete tmp file.
      # If -r or -C options were also specified, don't exit here.
      exit(0) unless ( exists($cliOpts{r}) or exists($cliOpts{C}) );
      sleep 1;    # Give WLED time to process the preset data.
   }
   else {
      &ColorMessage("File not found: $cliOpts{P}", "BRIGHT_RED", '');
      exit(1);
   }
}

# ==========
# Backup WLED configuation.
if (exists( $cliOpts{c} )) {
   my @resp = ();
   $cliOpts{c} = $Sections{'configuration'} if ($cliOpts{c} eq '-');
   exit(1) if (&GetUrl(join("/", $WledUrl, "cfg.json"), \@resp));
   exit(1) if (&WriteFile($cliOpts{c}, \@resp, "trim"));
   &ColorMessage("Configuration backup $cliOpts{c} successfully created.", "WHITE", '');
   exit(0);
}

# ==========
# Restore WLED configuration. WLED parses cfg.json. The user specified file 
# is copied/renamed to the OS temp directory if named other than cfg.json.
if (exists( $cliOpts{C} )) {
   $cliOpts{C} = $Sections{'configuration'} if ($cliOpts{C} eq '-');
   if (-e $cliOpts{C}) {
      my $file = $cliOpts{C};
      exit(1) if (&ReadFile($file, \@data, 'trim'));
      unless (grep /\{"rev":\[\d+,\d+\],/, @data) {   # Check for revision data.
         &ColorMessage("File content doesn't look like WLED configuration data. " .
                       "Continue? [y/N] -> ", "BRIGHT_YELLOW", 'nocr');
         my $resp = <STDIN>;
         exit(0) unless ($resp =~ m/y/i);
      }
      unless ($file eq 'cfg.json') {
         my @data = ();
         my $path = &GetTmpDir();
         exit(1) if (&ReadFile($file, \@data, 'trim'));
         $file = join('/', $path,'cfg.json');
         exit(1) if (&WriteFile($file, \@data, "trim"));
      }
      exit(1) if (&PostUrl(join("/", $WledUrl, "upload"), $file));
      &ColorMessage("Configuration successfully restored from $cliOpts{C}", "WHITE", '');
      unlink $file if ($file ne $cliOpts{C});         # Delete tmp file.
      &ColorMessage("WLED auto-reset. Wait ~15 sec for network reconnect.", "WHITE", '');
      exit(0);
   }
   else {
      &ColorMessage("File not found: $cliOpts{C}", "BRIGHT_RED", '');
      exit(1);
   }
}

# ==========
# Backup WLED configuration, presets, palettes, and ledmaps to the specified 
# file. Have to brute force get of the palette and ledmap data. Currently no 
# way to know which palettes or ledmaps are defined ahead of time.
if (exists( $cliOpts{a} )) {
   my @resp = ();   my @data = ();   my $pStr;
   foreach my $section ("configuration","presets","palettes","ledmaps") {
      if ($section eq 'palettes' or $section eq 'ledmaps') {
         push (@data, "== $section ==");
         &ColorMessage("$section", "WHITE", '');
         for (my $x = 0; $x < 10; $x++) {
            $pStr = join('', 'palette', $x, '.json') if ($section eq 'palettes');
            $pStr = join('', 'ledmap', $x, '.json') if ($section eq 'ledmaps');
            my $url = join("/", $WledUrl, $pStr);
            my $code = &GetUrl($url, \@resp);
            if ($code == 0) {
               push (@data, $pStr, @resp);
               &ColorMessage("   $pStr", "WHITE", '');
            }
         }
         push (@data, '');
      }
      else {
         push (@data, "== $section ==");
         &ColorMessage("$section", "WHITE", '');
         exit(1) if (&GetUrl(join("/", $WledUrl, $Sections{$section}), \@resp));
         push (@data, @resp, '');
      }
   }
   push (@data, '== eof ==');
   exit(1) if (&WriteFile($cliOpts{a}, \@data, 'trim'));
   &ColorMessage("Backup $cliOpts{a} successfully created.", "WHITE", '');
   exit(0);
}

# ==========
# Restore WLED configuration, presets, palettes and ledmaps from specified file.
# File must have the section breaks that were created by the -a backup code. We 
# send the configuration data last due to WLED auto-reboot following load.
if (exists( $cliOpts{A} )) {
   my @data = ();
   exit(1) if (&ReadFile($cliOpts{A}, \@data, 'trim'));
   if (grep /== eof ==/, @data) {
      foreach my $section ('presets','palettes','ledmaps','configuration') {
         # Extract data records for section.
         my @secData = ();  my $beg = -1;
         for (my $x = 0; $x <= $#data; $x++) {
            if ($beg != -1 and $data[$x] =~ m/^== \w+ ==$/i) {
               @secData = splice(@data, $beg, ($x - $beg));
               last;
            }
            elsif ($data[$x] =~ m/^== $section ==$/) {
               $beg = $x +1;
            }
         }
         if ($beg == -1) {
            &ColorMessage("Section '$section' missing. Invalid file: $cliOpts{A}",
                          "BRIGHT_RED", '');
            exit(1);
         }

         # Process the extracted records.
         if ($section eq 'presets' or $section eq 'configuration') {
            my $filename = join('/', &GetTmpDir(), $Sections{$section});
            exit(1) if (&WriteFile($filename, \@secData, 'trim'));
            exit(1) if (&PostUrl(join("/", $WledUrl, "upload"), $filename));
            &ColorMessage("$Sections{$section} data successfully sent.", "WHITE", '');
            unlink $filename;
            sleep 1;       # Delay for WLED to process the upload.
         }
         elsif ($section eq 'palettes') {
            for (my $x = 0; $x <= $#secData; $x++) {
               last unless ($secData[$x] =~ m/palette/);  # End of palettes section.
               if ($secData[$x] =~ m/^palette\d\.json$/) {
                  my $filename = join('/', &GetTmpDir(), $secData[$x]);
                  my @array = ("$secData[$x +1]");
                  exit(1) if (&WriteFile($filename, \@array, 'trim'));
                  exit(1) if (&PostUrl(join("/", $WledUrl, "upload"), $filename));
                  &ColorMessage("$secData[$x] data successfully sent.", "WHITE", '');
                  unlink $filename;
               }
            }
         }
         elsif ($section eq 'ledmaps') {
            for (my $x = 0; $x <= $#secData; $x++) {
               last unless ($secData[$x] =~ m/map/);   # End of ledmaps section.
               if ($secData[$x] =~ m/^ledmap\d\.json$/) {
                  my $filename = join('/', &GetTmpDir(), $secData[$x]);
                  my @array = ("$secData[$x +1]");
                  exit(1) if (&WriteFile($filename, \@array, 'trim'));
                  exit(1) if (&PostUrl(join("/", $WledUrl, "upload"), $filename));
                  &ColorMessage("$secData[$x] data successfully sent.", "WHITE", '');
                  unlink $filename;
               }
            }
         }
      }
   }
   else {
      &ColorMessage("Invalid file: $cliOpts{A}", "BRIGHT_RED", '');
      exit(1);
   }
   &ColorMessage("WLED auto-reset. Wait ~15 sec for network reconnect.", "WHITE", '');
   exit(0);
}

# ==========
# Backup any user custom ledmaps to individual files. 
if (exists( $cliOpts{m} )) {
   if (-d $cliOpts{m}) {
      $cliOpts{m} =~ s#[/|\\]$##;      # Remove trailing / or \ if present.
      my @resp = ();
      for (my $x = 0; $x < 10; $x++) {
         my $pStr = join('', 'ledmap', $x, '.json');
         my $url = join("/", $WledUrl, $pStr);
         my $code = &GetUrl($url, \@resp);
         if ($code == 0) {
            my $pathFile = join('/', $cliOpts{m}, $pStr);
            exit(1) if (&WriteFile($pathFile, \@resp, 'trim'));
            &ColorMessage("Ledmap backup: $pathFile", "WHITE", '');
         }
      }
   }
   else {
      &ColorMessage("Directory not found: $cliOpts{m}", "BRIGHT_RED", '');
   }
   exit(0);
}

# ==========
# Send user specified JSON ledmap file(s) data to WLED.
if (exists( $cliOpts{M} )) {
   my @files = ();
   if ($cliOpts{M} =~ m/,/) {                # Multiple files specified?
      @files = split(',', $cliOpts{M});
   }
   elsif ($cliOpts{M} =~ m/\*|\?/) {         # Wildcard character specified?
      @files = grep {-f} glob $cliOpts{M};   # Get matching file entries.
   }
   else {
      push (@files, $cliOpts{M});
   }
   foreach my $file (@files) {
      $file =~ s/^\s+|\s+$//g;
      if (-e $file) {
         exit(1) if (&PostUrl(join("/", $WledUrl, "upload"), $file));
         &ColorMessage("$file data successfully sent.", "WHITE", '');
      }
      else {
         &ColorMessage("File not found: $file", "BRIGHT_RED", '');
      }
   }
   exit(0);
}

# ==========
# Backup any user custom palettes to individual files. 
if (exists( $cliOpts{g} )) {
   if (-d $cliOpts{g}) {
      $cliOpts{g} =~ s#[/|\\]$##;      # Remove trailing / or \ if present.
      my @resp = ();
      for (my $x = 0; $x < 10; $x++) {
         my $pStr = join('', 'palette', $x, '.json');
         my $url = join("/", $WledUrl, $pStr);
         my $code = &GetUrl($url, \@resp);
         if ($code == 0) {
            my $pathFile = join('/', $cliOpts{g}, $pStr);
            exit(1) if (&WriteFile($pathFile, \@resp, 'trim'));
            &ColorMessage("Palette backup: $pathFile", "WHITE", '');
         }
      }
   }
   else {
      &ColorMessage("Directory not found: $cliOpts{g}", "BRIGHT_RED", '');
   }
   exit(0);
}

# ==========
# Send user specified JSON data file(s) data to WLED.
if (exists( $cliOpts{G} )) {
   my @files = ();
   if ($cliOpts{G} =~ m/,/) {                # Multiple files specified?
      @files = split(',', $cliOpts{G});
   }
   elsif ($cliOpts{G} =~ m/\*|\?/) {         # Wildcard character specified?
      @files = grep {-f} glob $cliOpts{G};   # Get matching file entries.
   }
   else {
      push (@files, $cliOpts{G});
   }
   foreach my $file (@files) {
      $file =~ s/^\s+|\s+$//g;
      if (-e $file) {
         exit(1) if (&PostUrl(join("/", $WledUrl, "upload"), $file));
         &ColorMessage("$file data successfully sent.", "WHITE", '');
      }
      else {
         &ColorMessage("File not found: $file", "BRIGHT_RED", '');
      }
   }
   exit(0);
}

# ==========
# Display all available WLED data. The endpoint URLs are defined on the WLED
# json-api webpage. https://kno.wled.ge/interfaces/json-api/
if (exists( $cliOpts{l} ) or exists( $cliOpts{w} )) {
   my @resp = ();   my @data = ();
   foreach my $obj ('state','info','nodes','eff','palx','fxdata','net','pal') {
      my $url = join("/", $WledUrl, 'json', $obj);
      exit(1) if (&GetUrl($url, \@resp));
      if (exists( $cliOpts{w} )) {
         push (@data, "WLED $url");
         push (@data, @resp, '');
      }
      else {
         &ColorMessage("WLED $url", "CYAN", '');
         &ColorMessage("@resp \n", "WHITE", '');
      }
   }
   # Use the globally defined %Sections hash for URL mapping.
   foreach my $section ("configuration","presets") {
      my $url = join("/", $WledUrl, $Sections{$section});
      exit(1) if (&GetUrl($url, \@resp));
      if (exists( $cliOpts{w} )) {
         push (@data, "WLED $url");
         push (@data, @resp, '');
      }
      else {
         &ColorMessage("WLED $url", "CYAN", '');
         &ColorMessage("@resp", "WHITE", '');
      }
   }
   # Have to brute force get of the palette data. Currently no way to know
   # which palettes are defined ahead of time.
   for (my $x = 0; $x < 10; $x++) {
      my $pStr = join('', 'palette', $x, '.json');
      my $url = join("/", $WledUrl, $pStr);
      my $code = &GetUrl($url, \@resp);
      next if ($code != 0);
      if (exists( $cliOpts{w} )) {
         push (@data, "WLED $url");
         push (@data, @resp, '');
      }
      else {
         &ColorMessage("WLED $url", "CYAN", '');
         &ColorMessage("@resp", "WHITE", '');
      }
   }
   if (exists( $cliOpts{w} )) {
      exit(1) if (&WriteFile($cliOpts{w}, \@data, 'trim'));
      &ColorMessage("$cliOpts{w} successfully created.", "WHITE", '');
   }
   exit(0);
}

# ==========
# Send user specified JSON data file(s) to WLED. Remove comment data if present.
if (exists( $cliOpts{x} )) {
   my @files = ();
   if ($cliOpts{x} =~ m/,/) {                # Multiple files specified?
      @files = split(',', $cliOpts{x});
   }
   elsif ($cliOpts{x} =~ m/\*|\?/) {         # Wildcard character specified?
      @files = grep {-f} glob $cliOpts{x};   # Get matching file entries.
   }
   else {
      push (@files, $cliOpts{x});
   }
   foreach my $file (@files) {
      $file =~ s/^\s+|\s+$//g;
      if (-e $file) {
         my(@data) = ();   my(@json) = ();
         exit(1) if (&ReadFile($file, \@data, 'trim'));
         foreach my $line (@data) {
            next if ($line =~ m/^#/);
            push (@json, $line);
         }
         unless (scalar @json == scalar @data) {   # Use tmp file if comments.
            my $path = &GetTmpDir();
            $file = join('/', $path,'data.json');
            exit(1) if (&WriteFile($file, \@json, 'trim'));
         }
         exit(1) if (&PostUrl(join("/", $WledUrl, "upload"), $file));
         &ColorMessage("$file data successfully sent.", "WHITE", '');
         unlink $file if (scalar @json != scalar @data);   # Delete tmp file.
      }
      else {
         &ColorMessage("File not found: $file", "BRIGHT_RED", '');
      }
   }
}

# ==========
# Reset WLED.
if (exists( $cliOpts{r} )) {
   sleep 1 if (exists( $cliOpts{P} ));   # Wait for WLED to process presets restore. 
   exit(1) if (&PostJson(join("/", $WledUrl, "json/state"), 
               qq({"on":true,"rb":true})));
   &ColorMessage("Reset sent to WLED. Wait ~15 sec for network reconnect.",
                 "WHITE", '');
}

exit(0);
