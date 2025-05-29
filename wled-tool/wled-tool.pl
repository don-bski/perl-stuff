#!/usr/bin/perl
# ==============================================================================
# FILE: wled-tool.pl                                                  5-28-2025
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
# PERL VERSION:  5.28.1
# ==============================================================================
use Getopt::Std;
use Term::ANSIColor;
require Win32::Console::ANSI if ($^O =~ m/Win/);
use LWP::UserAgent;
use JSON;
use Data::Dumper;
use warnings;

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
getopts('hdilre:f:v:w:x:a:A:c:C:g:G:p:P:', \%cliOpts);  # Load CLI options hash

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
   
   Caution: When using a backup option (-a, -c, -p, -g), if the specified file
   exists, it will be overwritten without warning.
      
   To backup working data prior to a WLED software upgrade, use the -a option.
   After upgrade, connect to WLED using a browser. Use the GUI 'WIFI SETTINGS'
   control to set and save the AP SSID and AP password. (The AP password is not
   backed up by WLED for security reasons.) Power cycle the WLED ESP32 module.
   Then use the -A option to restore the working data.

   The -i option provides a basic means for selecting an operational WLED
   preset. This supports preset audition and testing when the WLED GUI is not
   available. The current presets are read from WLED and presented to the
   user for selection; green colored entries signify playlists. Input the
   numeric value for the desired preset and press enter. A brightness value
   1-255 can also be entered using the 'b<n>' entry. The b entry without a
   value will display the current master brightness setting.
     
   The -i option also supports entry of a custom playlist. Enter a comma
   separated list: p,<n>,<n>,d,<s>  where p is followed by one or more
   preset numbers and optional d is followed by a time duration in seconds
   between 0 and 3600. Duration defaults to 15 seconds if not specified. The
   p entry with no values will display the current active preset.

   The -f option is used to reformat a preset file for easier use in a text 
   editor. Extraneous whitespace is removed, newlines are added, and JSON
   data pairs are indented for better readability. The changes made are 
   compatible with subsequent preset restore to WLED. The specified file is 
   overwritten with the reformatted content.
    
   The -x option is used to send json formatted data to WLED. See the WLED
   json-api webpage at https://kno.wled.ge/interfaces/json-api/ for details.
   Comment lines, beginning with the # character, may be included in the file 
   data for documentation purposes. Comment data is not sent to WLED. Multiple 
   comma seperated files or a file name wildcard character may be specified.
   
USAGE:
   $ExecutableName  [-h] [-d] [-i] [-l] [-r] [-e <url>] [-a <file>] [-A <file>]
      [-c <file>] [-C <file>] [-g <dir>] [-G <file>[,<file>,...]] [-p <file]
      [-P <file>] [-f <file>] [-v <file>] [-w <file>] [-x <file>]

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
   -g <dir>     Backup custom palettes to specified directory.

   -A <file>    Restore WLED cfg, presets, and palettes from a file previously
                created by the -a option.
   -C <file>    Restore WLED configuration data from file. 
   -P <file>    Restore WLED preset data from file. Use -r option to activate
                the restored presets.
   -G <file>    Restore specified custom palette file(s) content to WLED. 
                  
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
                    "BRIGHT_RED");
      return 1;
   }
   foreach my $line (@$OutputArrayPointer) {
      if ($Option =~ m/trim/i) {
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
#    $main::cliOpts{d}
# =============================================================================
sub GetTmpDir {
   my($path, $os) = ('','');

   if ($^O =~ m/Win/) {   # Windows environment?
      $os = 'win';
      foreach my $env ('TMP','TEMP','TMPDIR','TEMPDIR') {
         my $result = `set $env 2>&1`;
         next if ($result =~ m/not defined/i);
         $path = $result;
         last;
      }
      $path = 'c:/windows/temp' if ($path eq '');
   }
   else {
      $os = 'linux';
      foreach my $env ('TMPDIR','TEMPDIR','TMP','TEMP') {
         my $result = `env $env 2>&1`;
         next if ($result =~ m/no such file/i);
         $path = $result;
         last;
      }
      $path = '/tmp' if ($path eq '');
   }
   chomp($path);
   $path =~ s/^\s+|\s+$//g;
   print "GetTmpDir: os: $os   path: '$path'\n" if (exists( $main::cliOpts{d} ));
   unless (-d $path) {
      &ColorMessage("GetTmpDir - Directory not found: $path", "BRIGHT_RED");
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
      if ($^O =~ m/Win/) {            # Windows environment?
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
# FUNCTION:  CleanData
#
# DESCRIPTION:
#    This routine removes multiple spaces from the specified array. The 
#    resulting data is validated using decode_json.
#
# CALLING SYNTAX:
#    $result = &CleanData(\@Array);
#
# ARGUMENTS:
#    $Array          Pointer to array of json records.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub CleanData {
   my($ArrayPointer) = @_;

   my @array = @$ArrayPointer;              # Local working copy
   s/\x20{2,}//g foreach @array;            # Remove multiple spaces   
   my $check = join('', @array);
   eval { decode_json($check) };            # Validate json data formatting.
   if ($@) {
      &ColorMessage("CleanData - Invalid json.", "BRIGHT_RED");
      &ColorMessage("CleanData - $@", "CYAN");
      &ColorMessage("CleanData - '$check'", "WHITE");
      return 1;
   }
   else {
      @$ArrayPointer = @array;              # Replace with cleaned data.
   }
   return 0;
}

# =============================================================================
# FUNCTION:  FormatPresets
#
# DESCRIPTION:
#    This routine reformats the specified WLED JSON preset data for readability
#    and use in a text editor. The input data pointer can specify an array or
#    a hash. If an array pointer, input is decoded to a local working hash.
#
#    The processed output is returned in the specified array. Each array record
#    is a line containing the JSON data pairs as defined by the @order array.
#
# CALLING SYNTAX:
#    $result = &FormatPresets($Presets);
#
# ARGUMENTS:
#    $Presets        Pointer to preset data.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::cliOpts{d}
# =============================================================================
sub FormatPresets {
   my($Presets) = @_;
   my($tab) = ' ' x 3;   

   # Clean and validate the input JSON preset data.
   return 1 if (&CleanData($Presets));

   # Concatenate data to a single line. Add marker characters and then split.
   my($data) = join('', @$Presets);
   $data =~ s/("\d+":)/%$1/g;              # Split point for preset id.
   $data =~ s/(\{"id":\d+,)/%$1/g;         # Split point for segment id.
   $data =~ s/("col":)/%$1/g;              # Split point for col.
   $data =~ s/("c1":)/%$1/g;               # Split point for c1.
   $data =~ s/("ps":\[)/%$1/g;             # Split point for playlist ps.
   $data =~ s/("dur":\[)/%$1/g;            # Split point for playlist dur.
   $data =~ s/("transition":\[)/%$1/g;     # Split point for playlist transition.
   $data =~ s/(\{"stop":0\})/%$1/g;        # Split point for every {"stop":0}.
   $data =~ s/(\{"stop":0\}\],)/$1%/g;     # Split point for segment end.
   my @work = split('%', $data);           # Make it so.
   if ($work[0] eq '{') {
      splice (@work, 0, 1);                # Remove standalone open brace.
      @work[0] = join('', '{', $work[0]);  # Add it to the next record.
   }
   @$Presets = ();          # Clear preset array for results.
   
   # Add readability indenting. Combine {"stop":0} data into 10 per line.
   for (my $x = 0; $x <= $#work; $x++) {
      if ($work[$x] =~ m/^\{"id":/ or $work[$x] =~ m/^"n":/ or $work[$x] =~ m/^"ps":/ or 
          $work[$x] =~ m/^"dur":/ or $work[$x] =~ m/^"transition":/) {
         $work[$x] = join('', $tab, $work[$x]);
      }
      elsif ($work[$x] =~ m/^"col":/ or $work[$x] =~ m/^"c1":/) {
         $work[$x] = join('', $tab, $tab, $work[$x]);
      }
      elsif ($work[$x] =~ m/^\{"stop":0\}/) {
         my $stops = '';   my @temp = ();   my($stopCnt) = 0;
         for (my $y = $x; $y <= $#work; $y++) {
            if ($work[$y] =~ m/^\{"stop":0\},$/) {  # only stop?
               if ($stopCnt == 10) {
                  push(@$Presets, $stops);
                  $stops = '';
                  $stopCnt = 0;
               }
               if ($stopCnt == 0) {
                  $stops = join('', $tab, $work[$y]);
                  $stopCnt = 1;
               }
               else {
                  $stops = join('', $stops, $work[$y]);
                  $stopCnt++;
               }
            }
            else {
               # Add last stop; it has the segment end ].
               if ($stopCnt == 10) {
                  push(@$Presets, $stops);
                  $stops = join('', $tab, $work[$y]);
               }
               else {
                  $stops = join('', $stops, $work[$y]);
               }
               push(@$Presets, $stops);
               $x = $y;     # Point $x to the next preset line.
               last;        # Break out of inner $y loop.
            }
         }
         next;    # Nothing to output. Continue with next $x. 
      }
      push(@$Presets, $work[$x]);
   }
   if (defined($main::cliOpts{d})) {
      foreach my $line (@$Presets) {
         print $line, "\n";
      }
   }
   return 0;
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
#    $main::cliOpts{d}
# =============================================================================
sub PostJson {
   my($Url, $Json, $Resp) = @_;
   my($request, $response, @data);
   my($agent) = "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, " .
                "like Gecko) Chrome/89.0.4389.114 Safari/537.36";
   my($retry) = 3;
   my($exitCode) = 0;
   print "PostJson: $Url   Json: '$Json'\n" if (exists( $main::cliOpts{d} ));

   my $userAgent = LWP::UserAgent->new(
      timeout => 5, agent => $agent, protocols_allowed => ['http',]);
   if ($Json ne '') {
      eval { decode_json($Json) };             # Validate json data formatting.
      if ($@) {
         &ColorMessage("PostJson - Invalid json.", "BRIGHT_RED");
         &ColorMessage("PostJson - $@", "CYAN");
         &ColorMessage("PostJson - '$Json'", "WHITE");
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
               &ColorMessage("HTTP POST $Url", "BRIGHT_RED");
               &ColorMessage("HTTP POST error: " . $response->code, "BRIGHT_RED");
               &ColorMessage("HTTP POST error: " . $response->message .
                             "\n","BRIGHT_RED");
               $exitCode = 1;
            }
            else {
               &ColorMessage("PostJson - POST retry ...", "CYAN");
               sleep 1;       # Wait a bit for network stabilization.
            }
         }
      }
   }
   else {
      &ColorMessage("PostJson - No JSON data specified.", "BRIGHT_RED");
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
#    $main::cliOpts{d}
# =============================================================================
sub PostUrl {
   my($Url, $File) = @_;
   my($request, $response, @data);
   my($agent) = "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, " .
                "like Gecko) Chrome/89.0.4389.114 Safari/537.36";
   my($retry) = 3;
   my($exitCode) = 0;
   print "PostUrl: $Url   File: '$File'\n" if (exists( $main::cliOpts{d} ));

   my $userAgent = LWP::UserAgent->new(
      timeout => 10, agent => $agent, protocols_allowed => ['http',]);
   if (-e $File) {
      return 1 if (&ReadFile($File, \@data, 'trim'));
      my $check = join('', @data);
      eval { decode_json($check) };             # Validate json data formatting.
      if ($@) {
         &ColorMessage("PostUrl - Invalid json: $File", "BRIGHT_RED");
         &ColorMessage("PostUrl - $@", "CYAN");
#         &ColorMessage("PostUrl - '$check'", "WHITE");
         $exitCode = 1;
      }
      else {
         print "HTTP POST data: '@data'\n" if (exists( $main::cliOpts{d} ));
         
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
               &ColorMessage("PostUrl - Invalid palette: $check", "BRIGHT_RED");
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
               &ColorMessage("HTTP POST $Url", "BRIGHT_RED");
               &ColorMessage("HTTP POST error: " . $response->code, "BRIGHT_RED");
               &ColorMessage("HTTP POST error: " . $response->message .
                             "\n","BRIGHT_RED");
               $exitCode = 1;
            }
            else {
               &ColorMessage("PostUrl - POST retry ...", "CYAN");
               sleep 1;       # Wait a bit for network stabilization.
            }
         }
      }
   }
   else {
      &ColorMessage("PostUrl - File not found: $File", "BRIGHT_RED");
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
#    $main::cliOpts{d}, $main::cliOpts{r}
# =============================================================================
sub GetUrl {
   my($Url, $Resp) = @_;
   my($request, $response, @data);
   my($agent) = "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, " .
                "like Gecko) Chrome/89.0.4389.114 Safari/537.36";
   my($retry) = 3;
   my($exitCode) = 0;
   print "GetUrl: $Url\n" if (exists( $main::cliOpts{d} ));
   
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
         my $check = join('', @data);
         print "GetUrl: check: '$check'\n" if (exists( $main::cliOpts{d} ));
         eval { decode_json($check) };     # Validate json data formatting.
         if ($@) {
            &ColorMessage("GetUrl - Invalid json data. Retry Get ...", "CYAN");
            $retry--;
            if ($retry == 0) { 
               &ColorMessage("GetUrl - $@", "WHITE");
#               &ColorMessage("GetUrl - '$check'", "WHITE");
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
         # Request for a palette.json beyond the last available will return 404 
         # status. In this case, suppress error report and return 2.
         my $code = $response->code; 
         if ($Url =~ m/palette\d\.json$/ and $code == 404) {
            $exitCode = 2;
            last;
         }
         else {  
            $retry--;
            if ($retry == 0) { 
               &ColorMessage("HTTP GET $Url", "BRIGHT_RED");
               &ColorMessage("HTTP GET error code: " . $response->code, "BRIGHT_RED");
               &ColorMessage("HTTP GET error message: " . $response->message .
                             "\n","BRIGHT_RED");
               $exitCode = 1;
            }
            else {
               &ColorMessage("GetUrl - GET retry ...", "CYAN");
               sleep 1;       # Wait a bit for network stabilization.
            }
         }
      }
   }
   undef($userAgent);
   return $exitCode;
}

# =============================================================================
# FUNCTION:  AuditionPresets
#
# DESCRIPTION:
#    This routine gets the presets data from WLED and displays the available
#    preset names and associated Id. An interactive loop is then entered that
#    requests user Id input. The user entered Id value is sent to WLED to set
#    the specified preset active. An Id value of zero (0) terminates the loop.
#
#    The -i option also supports entry of a custom playlist. Enter a comma
#    separated list: p,<n>,<n>,d,<s>  where p is followed by one or more
#    preset numbers and optional d is followed by a time duration in seconds
#    between 0 and 3600. Duration defaults to 15 seconds if not specified. 
#
#    To change the WLED brightness setting, enter b<n> where <n> is a value
#    in the range 1-255. A relative brightness change can be entered by adding
#    a + or - character. b+<n> or b-<n>.
#    
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
#    $main::cliOpts{d}
# =============================================================================
sub AuditionPresets {
   my($WledUrl) = @_;
   my(@resp) = ();   my(%presetIds) = ();

   # Get WLED state data which includes the current brightness setting. This is
   # used for a user requested brightness change (b) during audition.
   return 1 if (&GetUrl(join("/", $WledUrl, 'json', 'state'), \@resp));
   my $s_ref = decode_json(join('', @resp));
   # $Data::Dumper::Sortkeys = 1;
   # print Dumper $s_ref;

   # Get available presets from WLED and load the working hash.
   return 1 if (&GetUrl(join("/", $WledUrl, "presets.json"), \@resp));
   my $p_ref = decode_json(join('', @resp));
   # $Data::Dumper::Sortkeys = 1;
   # print Dumper $p_ref;
   
   foreach my $id (keys(%$p_ref)) {
      next if ($id == 0);
      $presetIds{$id}{'name'} = $p_ref->{$id}{'n'};
      if (exists($p_ref->{$id}{'playlist'})) {
         $presetIds{$id}{'color'} = 'GREEN';
      }
      else {
         $presetIds{$id}{'color'} = 'CYAN';
      }
   }
   # print Dumper \%presetIds;

   # Show user the available presets and associated Id.
   my $col = 0;   my $cols = 3;
   my $line = '=' x 75;
   &ColorMessage("\n$line", "WHITE");
   &ColorMessage("WLED presets available for audition:", "WHITE");
   foreach my $id (sort {$a <=> $b} keys(%presetIds)) {
      &ColorMessage('  ' . substr("  $id", -3) . " ", "WHITE", 'nocr');
      &ColorMessage(substr($presetIds{$id}{'name'} . ' ' x 20, 0, 20), 
                           $presetIds{$id}{'color'}, 'nocr');
      $col++;
      if ($col == $cols) {
         &ColorMessage("", "CYAN");
         $col = 0;
      }
   }
   &ColorMessage("", "CYAN") if ($col != 0);
   &ColorMessage("For a custom playlist enter: p,<n>,<n>,d,<s>", "WHITE");
   &ColorMessage("LED Brightness: b <n> (1-255) or b +<n> or b -<n>       " .
                 "Current: $s_ref->{'bri'}", "WHITE");
   &ColorMessage("$line", "WHITE");

   # Get user input and process.
   while (1) {
      &ColorMessage("Enter a preset number or 0 to exit. -> ", "WHITE", 'nocr');
      my $preset = <STDIN>;
      chomp($preset);
      next if ($preset eq '');

      # ==========
      if ($preset =~ m/^p/i) {           # User wants a custom playlist.
         my @pset = ();  my $dur = 15;
         # Isolate presets.
         if ($preset =~ m/p([0-9,]+)/i) {
            my $data = $1;
            $data =~ s/^,|,$//g;
            @pset = split(',', $data);
            # Get duration if specified.
            if ($preset =~ m/d,(\d+)/i) {
               $dur = $1 unless ($1 < 1 or $1 > 3600);
            }
         }
         print "pset: '@pset'   dur: '$dur' \n" if (exists( $main::cliOpts{d} ));
         if ($#pset >= 0) {
            # Validate presets.
            my $valid = 1;
            foreach my $id (@pset) {
               unless (exists($presetIds{$id})) {
                  &ColorMessage("Invalid preset Id: $id", "BRIGHT_RED");
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
            }
         }
         else {
            my $msg = "Active preset is: $s_ref->{'ps'}";
            $msg = join(' ', $msg, '(default)') if ($s_ref->{'ps'} == -1);
            &ColorMessage($msg, "CYAN");
         }
      }
      # ==========
      elsif ($preset =~ m/^(\d+)$/) {    # User wants a single preset.
         my $id = $1;
         last if ($id == 0);
         if (exists($presetIds{$id})) {
            last if (&PostJson(join("/", $WledUrl, "json/state"), qq({"ps": $id})));
            $s_ref->{'ps'} = $id;
         }
         else {
            &ColorMessage("Invalid preset Id: $id", "BRIGHT_RED");
         }
      }
      # ==========
      elsif ($preset =~ m/^b$/i) {           # b with no value
         &ColorMessage("LED brightness is: $s_ref->{'bri'}", "CYAN");
      }
      elsif ($preset =~ m/^b\s*([\+|\-]*[0-9]+)/i) {   # User wants brightness change.
         my $val = $1;   my $noSet = 0;
      
         # Update parameter value in state working hash.
         if ($val =~ m/^[\+|\-]/) {
            $s_ref->{'bri'} += $val;       # relative
            $s_ref->{'bri'} = 1 if ($s_ref->{'bri'} < 1);
            $s_ref->{'bri'} = 255 if ($s_ref->{'bri'} > 255);
         }
         else {
            if ($val > 0 and $val < 256) {
               $s_ref->{'bri'} = $val;     # absolute
            }
            else {
               &ColorMessage("Invalid brightness value: $val", "BRIGHT_RED");
               $noSet = 1;
            }
         }
         if ($noSet == 0) {
            last if (&PostJson(join("/", $WledUrl, "json/state"), 
                     qq({"on":true,"bri": $s_ref->{'bri'}})));
            &ColorMessage("LED brightness set to: $s_ref->{'bri'}", "CYAN");
         }
      }
      # ==========
      else {
         &ColorMessage("Invalid entry: '$preset'", "BRIGHT_RED");
      }
      sleep 1;
   }
   &ColorMessage("", "WHITE");
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
#    $main::cliOpts{d}
# =============================================================================
sub JsonData {
   my($Url, $File) = @_;

   if (-e $File) {
   }
   else {
      &ColorMessage("JsonData - File not found: $File", "BRIGHT_RED");
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
   &ColorMessage("\nNo program option specified.", "BRIGHT_RED") if ($allOpts eq '');
   &ColorMessage("$UsageText", "WHITE");
   exit(0);  
}

# ==========
# Validate the json formatted content of the specified file.
if (exists( $cliOpts{v} )) {
   if (-e $cliOpts{v}) {
      my @data = ();
      exit(1) if (&ReadFile($cliOpts{v}, \@data, 'trim'));
      my $check = join('', @data);
      eval { decode_json($check) };             # Validate json data formatting.
      if ($@) {
         &ColorMessage("Invalid json: $cliOpts{v}", "BRIGHT_RED");
         &ColorMessage("$@", "CYAN");
#         &ColorMessage("'$check'", "WHITE");
         exit(1)
      }
      else {
         &ColorMessage("Valid json content in: $cliOpts{v}", "WHITE");
      }
      exit(0);
   }
   else {
      &ColorMessage("File not found: $cliOpts{v}", "BRIGHT_RED");
      exit(1);
   }
}

# ==========
# Reformat the specified presets file. If debug -d option is also specified,
# the reformatted data is only output to the console.
if (exists( $cliOpts{f} )) {
   if (-e $cliOpts{f}) {
      my @presetData = ();
      exit(1) if (&ReadFile($cliOpts{f}, \@presetData, 'trim'));
      # Validate JSON.
      my $check = join('', @presetData);
      eval { decode_json($check) };             # Validate json data formatting.
      if ($@) {
         &ColorMessage("Invalid json: $cliOpts{f}", "BRIGHT_RED");
         &ColorMessage("$@", "CYAN");
#         &ColorMessage("'$check'", "WHITE");
         exit(1)
      }
      # Reformat data.
      exit(1) if (&FormatPresets(\@presetData));
      # Validate reformatted JSON.
      $check = join('', @presetData);
      eval { decode_json($check) };             # Validate json data formatting.
      if ($@) {
         &ColorMessage("Reformatted json is invalid.", "BRIGHT_RED");
         &ColorMessage("$@", "CYAN");
         &ColorMessage("'$check'", "WHITE");
         exit(1) unless (exists( $cliOpts{d} ));
      }
      if (exists( $cliOpts{d} )) {
         print "\n";   # Print to console by -d in &FormatPresets
      }
      else {
         exit(1) if (&WriteFile($cliOpts{f}, \@presetData, 'trim'));
         &ColorMessage("Preset file $cliOpts{f} successfully reformatted.", "WHITE");
      }
   }
   else {
      &ColorMessage("File not found: $cliOpts{f}", "BRIGHT_RED");
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
      &ColorMessage("Invalid IP specified: $cliOpts{e}", "BRIGHT_RED");
      exit(1);
   }
}

# ==========
# Verify endpoint is accessible.
if ($^O =~ m/Win/) {                            # Windows environment?
   my $resp = `ping -w 1000 -n 1 -l 64 $WledIp 2>&1`;   # Windows ping
   unless ($resp =~ m/Reply from $WledIp/m) {
      &ColorMessage("No ping response from IP: $WledIp", "BRIGHT_RED");
      exit(1);
   }
}
else {
   my $resp = `ping -w 1 -c 1 -s 64 $WledIp 2>&1`;      # Linux ping
   unless ($resp =~ m/\d+ bytes from $WledIp/m) {
      &ColorMessage("No ping response from IP: $WledIp", "BRIGHT_RED");
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
   exit(1) if (&CleanData(\@resp));       # Remove extra whitespace.
   exit(1) if (&WriteFile($cliOpts{p}, \@resp, 'trim'));
   &ColorMessage("Preset backup $cliOpts{p} successfully created.", "WHITE");
}

# ==========
# Restore WLED presets. WLED parses presets.json. The user specified file is
# copied/renamed to the OS temp directory if named other than presets.json.
if (exists( $cliOpts{P} )) {
   $cliOpts{P} = $Sections{'presets'} if ($cliOpts{P} eq '-');
   if (-e $cliOpts{P}) {
      my $file = $cliOpts{P};
      exit(1) if (&ReadFile($file, \@data, 'trim'));
      unless (grep /\{"0":\{\},/, @data) {         # Check for preset 0 entry.
         &ColorMessage("File content doesn't look like WLED preset data. " .
                       "Continue? [y/N] -> ", "BRIGHT_YELLOW", 'nocr');
         my $resp = <STDIN>;
         exit(0) unless ($resp =~ m/y/i);
      }
      unless ($file eq 'presets.json') {
         my @data = ();
         my $path = &GetTmpDir();
         exit(1) if (&ReadFile($file, \@data, 'trim'));
         $file = join('/', $path,'presets.json');
         exit(1) if (&WriteFile($file, \@data, 'trim'));
      }
      exit(1) if (&PostUrl(join("/", $WledUrl, "upload"), $file));
      &ColorMessage("Presets successfully restored from $cliOpts{P}", "WHITE");
      unlink $file if ($file ne $cliOpts{P});   # Delete tmp file.
      # If -r or -b options were also specified, don't exit here.
      exit(0) unless ( exists($cliOpts{r}) or exists($cliOpts{C}) );
   }
   else {
      &ColorMessage("File not found: $cliOpts{P}", "BRIGHT_RED");
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
   &ColorMessage("Configuration backup $cliOpts{c} successfully created.", "WHITE");
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
      &ColorMessage("Configuration successfully restored from $cliOpts{C}", "WHITE");
      unlink $file if ($file ne $cliOpts{C});         # Delete tmp file.
      &ColorMessage("WLED auto-reset. Wait ~15 sec for network reconnect.", "WHITE");
      exit(0);
   }
   else {
      &ColorMessage("File not found: $cliOpts{C}", "BRIGHT_RED");
      exit(1);
   }
}

# ==========
# Backup WLED configuration, presets, and palettes to specified file. Have to 
# brute force get of the palette data. Currently no way to know which palettes
# are defined ahead of time.
if (exists( $cliOpts{a} )) {
   my @resp = ();   my @data = ();
   foreach my $section ("configuration","presets","palettes") {
      if ($section eq 'palettes') {
         push (@data, "== $section ==");
         &ColorMessage("$section", "WHITE");
         for (my $x = 0; $x < 10; $x++) {
            my $pStr = join('', 'palette', $x, '.json');
            my $url = join("/", $WledUrl, $pStr);
            my $code = &GetUrl($url, \@resp);
            if ($code == 0) {
               push (@data, $pStr, @resp);
               &ColorMessage("   $pStr", "WHITE");
            }
         }
      }
      else {
         push (@data, "== $section ==");
         &ColorMessage("$section", "WHITE");
         exit(1) if (&GetUrl(join("/", $WledUrl, $Sections{$section}), \@resp));
         push (@data, @resp, '');
      }
   }
   push (@data, '', '== eof ==');
   exit(1) if (&WriteFile($cliOpts{a}, \@data, 'trim'));
   &ColorMessage("Backup $cliOpts{a} successfully created.", "WHITE");
   exit(0);
}

# ==========
# Restore WLED configuration, presets, and palettes from specified file. File must
# have the section breaks that were created by the -a backup code. We send the
# configuration data last due to WLED auto-reboot following configuration load.
if (exists( $cliOpts{A} )) {
   my @data = ();
   exit(1) if (&ReadFile($cliOpts{A}, \@data, 'trim'));
   if (grep /== eof ==/, @data) {
      foreach my $section ("presets","palettes","configuration") {
         # Extract data records for section.
         my @secData = ();  my $beg = -1;
         for (my $x = 0; $x <= $#data; $x++) {
            if ($beg != -1 and ($data[$x] =~ m/^== \w+ ==$/ or $x == $#data)) {
               @secData = splice(@data, $beg, ($x - $beg));
               last;
            }
            elsif ($data[$x] =~ m/^== $section ==$/) {
               $beg = $x +1;
            }
         }
         # Process the extracted records.
         if ($section eq 'presets' or $section eq 'configuration') {
            my $name = join('/', &GetTmpDir(), $Sections{$section});
            exit(1) if (&WriteFile($name, \@secData, 'trim'));
            exit(1) if (&PostUrl(join("/", $WledUrl, "upload"), $name));
            &ColorMessage("$Sections{$section} data successfully sent.", "WHITE");
            unlink $name;
         }
         elsif ($section eq 'palettes') {
            for (my $x = 0; $x <= $#secData; $x++) {
               if ($secData[$x] =~ m/^palette\d\.json$/) {
                  my $name = join('/', &GetTmpDir(), $secData[$x]);
                  my @array = ("$secData[$x +1]");
                  exit(1) if (&WriteFile($name, \@array, 'trim'));
                  exit(1) if (&PostUrl(join("/", $WledUrl, "upload"), $name));
                  &ColorMessage("$secData[$x] data successfully sent.", "WHITE");
                  unlink $name;
               }
            }
         }
      }
   }
   else {
      &ColorMessage("Invalid file: $cliOpts{A}", "BRIGHT_RED");
      exit(1);
   }
   &ColorMessage("WLED auto-reset. Wait ~15 sec for network reconnect.", "WHITE");
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
            &ColorMessage("Palette backup: $pathFile", "WHITE");
         }
      }
   }
   else {
      &ColorMessage("Directory not found: $cliOpts{g}", "BRIGHT_RED");
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
         &ColorMessage("$file data successfully sent.", "WHITE");
      }
      else {
         &ColorMessage("File not found: $file", "BRIGHT_RED");
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
         &ColorMessage("WLED $url", "CYAN");
         &ColorMessage("@resp \n", "WHITE");
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
         &ColorMessage("WLED $url", "CYAN");
         &ColorMessage("@resp", "WHITE");
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
         &ColorMessage("WLED $url", "CYAN");
         &ColorMessage("@resp", "WHITE");
      }
   }
   if (exists( $cliOpts{w} )) {
      exit(1) if (&WriteFile($cliOpts{w}, \@data, 'trim'));
      &ColorMessage("$cliOpts{w} successfully created.", "WHITE");
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
         &ColorMessage("$file data successfully sent.", "WHITE");
         unlink $file if (scalar @json != scalar @data);   # Delete tmp file.
      }
      else {
         &ColorMessage("File not found: $file", "BRIGHT_RED");
      }
   }
}

# ==========
# Reset WLED.
if (exists( $cliOpts{r} )) {
   sleep 1 if (exists( $cliOpts{P} ));   # Wait for WLED to process presets restore. 
   my @resp = ();
   exit(1) if (&GetUrl(join("/", $WledUrl, 'win&RB'), \@resp));
   &ColorMessage("Reset sent to WLED. Wait ~15 sec for network reconnect.", "WHITE");
}

exit(0);
