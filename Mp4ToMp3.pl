#!/usr/bin/perl
# ==============================================================================
# FILE: Mp4ToMp3.pl                                                  12-23-2024
#
# SERVICES: Extract MP4 audio to MP3 file
#
# DESCRIPTION:
#   This program is used to extract the audio track in an MP4 file and convert
#   it to MP3 using ffmpeg. The audio level can be optionally normalized, and 
#   album cover image added, as part of the process. The MP4 files in the
#   current working directory are processed unless otherwise specified by CLI
#   options.
#
#   This program has been coded to run on both Linux and Windows. In Linux,
#   ANSI color is used for user messages. If color messages are not desired,
#   or Term::ANSIColor is not available, comment out 'use Term::ANSIColor'.
#
#   Notes for Windows environments:
#    * Alter the $FFmpeg program path as required. Paths that containg spaces
#      must be double quoted. For example: '"C:\Program Files\ffmpeg.exe"'. 
#    * File::Glob:bsd_glob is needed to handle paths containing spaces.
#    * ANSI color messages are not used.
#
# PERL VERSION:  5.28.1
# ==============================================================================
BEGIN {
   use Cwd;
   our ($ExecutableName) = ($0 =~ /([^\/\\]*)$/);
   our $WorkingDir = cwd();
#   if (length($ExecutableName) != length($0)) {
#      $WorkingDir = substr($0, 0, rindex($0, "/"));
#   }
   unshift (@INC, $WorkingDir);

   if ($^O =~ m/Win/) {   # Windows environment?
      our $FFmpeg = '"F:/Program Files (x86)/ClipGrab/ffmpeg.exe"';
   }
   else {
      our $FFmpeg = '/usr/bin/ffmpeg';
   }
}

# -------------------------------------------------------------------------
# External module definitions.
use Getopt::Std;
use Term::ANSIColor;
use File::Glob ':bsd_glob';    # Needed for Windows paths containing spaces.

# -------------------------------------------------------------------------
# Global variables.
$Normalize = 99;               # Audio normalization level. (-n)
$NormMin = -50;                # Normalize minimum value.
$NormMax = 10;                 # Normalize maximum value.
$InputDir = $WorkingDir;       # Input directory path. (-i)
$OutputDir = $WorkingDir;      # Output directory path. (-o)
$CoverImg = '';                # Cover image. (-c)
$TrackCnt = 0;                 # Track count for metadata. (-t)
$Mp3Rate = 0;                  # MP3 audio bitrate. (-r)

# -------------------------------------------------------------------------
# Program help text.
$UsageText = (qq(
===== Help for $ExecutableName ================================================

GENERAL DESCRIPTION
   This program extracts the audio track in an MP4 file and converts it to
   MP3 using ffmpeg. The audio level can be normalized using the -n option.
   MP4 files in the current working directory are processed unless otherwise
   specified by CLI options. MP3 title metadata, derived from the input file
   name, is always added. See examples below. 
   
   Windows note: For options with a file path, use the / character for the
                 folder separator, not \\.  

USAGE:
   $ExecutableName  [-h] [-q] [-d] [-t] [-i <path>] [-n <dB>] [-o <path>] 
                [-b <path>] [-c <img>] [-r <rate>] [ <file> [<file>] ...]
   
   -h          Displays program usage text.
   -q          Suppress all program message output.
   -d          Run in debug mode.
   
   -i <path>   Process MP4 files in specified input path. (default cwd)
   -o <path>   Write MP3 files to specified output path.  (default cwd)
               The output path is created if it does not exist.
   -b <path>   Sets input and output to the specified path. 
   -n <dB>     Normalize audio volume to the specified dB level (-50 to +10).
               A value of zero (0) will maximize volume up to the point of
               audio distortion. If not specified, no normalization is done
               and the MP3 audio level will be the same as MP4 audio level.
   -c <img>    Adds the specified cover image file to the MP3 file(s). The
               Jpg/Png image size should be 300-600 pixels square. If path
               is not specified, the MP4 input directory is used.
   -t          Adds track number metadata to the MP3 file(s). The track
               number is the sequential count of the processed files.
   -r <rate>   Set MP3 bitrate to <rate> Kbps (96 to 320). If not specified,
               the audio bitrate of the MP4 input file will be used.
   -v          Applies inverse RIAA eq to restore high frequencies. 
   
   <file>      One or more space separated MP4 files. Overrides -i option.

EXAMPLES:
   $ExecutableName -n 0 C:/Users/Don/Desktop/video.mp4
   Process the specified MP4 file and write the MP3 file to the current 
   working directory. Audio volume is normalized to 0 dB.

   $ExecutableName -i /home/don/Videos -o /home/don/Music -t
   Process the MP4 files in the input directory and write the MP3 files
   to the output directory. Audio is not normalized. Add track number
   metadata to each MP3 file.

   $ExecutableName -n -1 -c cover.jpg -r 192
   Process the MP4 files in the current working directory and write the
   MP3 files to the current working directory. Audio volume is normalized
   to -1 dB of MP4 level. The specified cover image is added to each MP3
   file. Set MP3 bitrate to 192 Kbps.

   $ExecutableName -n 0 -c cover.jpg -t -b C:/Users/Don/Desktop/temp
   Process the MP4 files in the specified directory and write the MP3
   files to the same directory. Audio volume is normalized to 0 dB. The
   specified cover image and track number metadata is added to each MP3 
   file.

===============================================================================
));

# =============================================================================
# FUNCTION:  DisplayMessage
#
# DESCRIPTION:
#    Displays a message to the user unless $opt_q (-q option) is defined.
#
# CALLING SYNTAX:
#    DisplayMessage($Message);
#
# ARGUMENTS:
#    $Message         A multi-line message.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $opt_q
# =============================================================================
sub DisplayMessage {

   my($Message) = @_;

   &ColorMessage($Message) unless (defined ($opt_q));
   return 0;
}

# =============================================================================
# FUNCTION:  DisplayDebug
#
# DESCRIPTION:
#    Displays a debug message to the user if the $opt_d (-d option) is defined.
#
# CALLING SYNTAX:
#    DisplayDebug($Message);
#
# ARGUMENTS:
#    $Message         A multi-line message.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $opt_d
# =============================================================================
sub DisplayDebug {

   my($Message) = @_;

   &ColorMessage($Message, 'CYAN') if (defined ($opt_d));
   return 0;
}

# =============================================================================
# FUNCTION:  DisplayError
#
# DESCRIPTION:
#    Displays a red error message to the user.
#
# CALLING SYNTAX:
#    DisplayError($Message);
#
# ARGUMENTS:
#    $Message         A multi-line message.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub DisplayError {

   my($Message) = @_;

   &ColorMessage($Message, 'BRIGHT_RED');
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
#    $result = &ColorMessage($Message, $Color, $Option);
#
# ARGUMENTS:
#    $Message         Message to be output.
#    $Color           Optional color attributes to apply (linux only).
#    $Option          'nocr' to suppress message final \n.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub ColorMessage {
   my($Message, $Color, $Option) = @_;
   my($cr) = "\n";

   $cr = '' if ($Option eq 'nocr');
   if ($Color ne '' and $^O =~ m/linux/ and defined($INC{'Term/ANSIColor.pm'})) {
      print STDOUT colored($Message . $cr, $Color);
   }
   else {
      print STDOUT $Message . $cr;
   }
   return 0;
}

# =============================================================================
# FUNCTION:  ProcessFile
#
# DESCRIPTION:
#    This routine processes the specified file and writes the MP3 output to
#    the specified directory. 
#
# CALLING SYNTAX:
#   $result = &ProcessFile($File, $Normalize, $Mp3Rate, $OutputDir, 
#                          $TrackCnt, $CoverImg);
#
# ARGUMENTS:
#    $File          MP4 file to process.
#    $Normalize     Audio normalization level.
#    $Mp3Rate       User specified MP3 bitrate in Kbps.
#    $OutputDir     Output directory path.
#    $TrackCnt      MP3 metadata track number if > 0.
#    $CoverImg      Optional front album cover image.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $FFmpeg, $NormMin, $NormMax, $opt_v
# =============================================================================
sub ProcessFile {
   my($File, $Normalize, $Mp3Rate, $OutputDir, $TrackCnt, $CoverImg) = @_;
   my($result, $baseCmd, $cmd, $mp3);
   my($mp3Bitrate) = 128;
   my($normAdj) = 0;
   DisplayDebug("ProcessFile --> File: '$File'   Normalize: '$Normalize'");
   DisplayDebug("ProcessFile --> OutputDir: '$OutputDir'   TrackCnt: '$TrackCnt'");
   DisplayDebug("ProcessFile --> Mp3Rate: '$Mp3Rate'   CoverImg: '$CoverImg'");
   
   if (-e $File) {
      my($path, $file) = $File =~ m{(.+)/([^/]+)$};
      my($title) = $file;                    # Used below for MP3 title metadata.
      $title =~ s/\.mp4$//i;                 # Remove mp4 extension.
      $title =~ s/^\d+[ \.-]//;              # Remove leading sequence characters.
      $title =~ s/^\s+|\s+$//;               # Remove leading/trailing spaces.
      DisplayDebug("ProcessFile path: '$path'   file: '$file'   title: '$title'");
      
      # Generate output filename and handle spaces in filename. For windows, file
      # names containing space must be enclosed within double quotes. Linux works
      # with either single or double quotes.
      $File = join('', '"', $File, '"') if ($file =~ m/ /);
      $file =~ s/mp4$/mp3/i;
      $file = join('', '"', $file, '"') if ($file =~ m/ /);
      $baseCmd = "$FFmpeg -hide_banner -i $File";

      # Get MP4 audio bitrate and max_volume.
      $cmd = join(' ', $baseCmd, "-af volumedetect -f null");
      if ($^O =~ m/Win/) {                   # Windows environment?
         $cmd = join(' ', $cmd, "NUL");
      }
      else {
         $cmd = join(' ', $cmd, "/dev/null");
      }
      DisplayDebug("ProcessFile audio cmd: '$cmd'");
      $result = `$cmd 2>&1`;
      DisplayDebug("ProcessFile audio result: '$result'");
      if ($Normalize >= $NormMin and $Normalize <= $NormMax) {
         if ($result =~ m/max_volume: (.+) dB/m) {
            $normAdj = $Normalize - $1;
            DisplayDebug("ProcessFile vol: $1   normAdj: $normAdj");
         }
         else {
            DisplayError("Can't determine volume level; audio not normalized.");
         }
      }
 
      # Setup MP3 bitrate. If CLI specified, use it. Otherwise, use MP4 bitrate.
      if ($Mp3Rate != 0) {        # User specified bitrate if not 0;
         $mp3Bitrate = $Mp3Rate;
      }
      else {
         if ($result =~ m#Stream.+?Audio:.+?, (\d+) kb#) {
            $mp3Bitrate = $1;
         }
         else {
            DisplayError("Can't determine MP4 audio bitrate; using 128 Kbps.");
         }
      }
      DisplayDebug("ProcessFile Mp3 bitrate: $mp3Bitrate");

      # Build ffmpeg command for required functions.
      $cmd = "$baseCmd -y";
      $cmd = join(' ', $cmd, "-i $CoverImg -map 0:a -map 1:0") if ($CoverImg ne '');
      
      # Add ffmpeg options for title and track number metadata.
      $cmd = join(' ', $cmd, qq(-metadata title="$title"));
      $cmd = join(' ', $cmd, qq(-metadata track="$TrackCnt")) if ($TrackCnt > 0);
      
      # Create the MP3 output path/filename. Remove existing file, if any.
      $mp3 = join('/', $OutputDir, $file);
      unlink $mp3 if (-e $mp3);

      # Add audio option if adjustment is non-zero, MP3 codec, and output path/file.      
      $cmd = join(' ', $cmd, "-af volume=${normAdj}dB") if ($normAdj != 0);
#      $cmd = join(' ', $cmd, "-af aemphasis=type=riaa") if (defined($opt_v));      
      $cmd = join(' ', $cmd, "-c:a libmp3lame -b:a ${mp3Bitrate}K $mp3");
      DisplayDebug("ProcessFile cmd: '$cmd'");
      
      $result = `$cmd 2>&1`;
      DisplayDebug("ProcessFile result: '$result'");
      if (($? >> 8) != 0) {
         DisplayError("ffmpeg returned error: " . ($? >> 8));
         return 1;
      }
   }
   else {
      print "*** File not found: $File\n";
   }
   return 0;
}

# =============================================================================
# MAIN PROGRAM
# =============================================================================
# Process user specified CLI options.
getopts("hqdtvi:n:o:b:c:r:");

# ==========
# Display program help if -h specified.
if (defined($opt_h)) {
	 print"$UsageText\n";
	 exit(0);  
}

# ==========
# Verify that ffmpeg is available. In windows, the file tests fail if double
# quotes are present for handling of path spaces.
$ffCheck = $FFmpeg;
$ffCheck =~ s/"//g if ($^O =~ m/Win/);
unless (-e $ffCheck and -x $ffCheck) {
   DisplayError("Required program not found: $FFmpeg");
   exit(1);
}

# ==========
# Set user specified CLI options and show working parameters if debug mode.
if (defined($opt_b)) {             # Set specified input and output path.
   if (-d $opt_b) {
      $InputDir = $opt_b;
      $OutputDir = $opt_b;
   }
   else {
      DisplayError("Specified path not found: $opt_b");
      exit(1);
   }
   DisplayDebug("InputDir: $InputDir");
   DisplayDebug("OutputDir: $OutputDir");
}
else {
   if (defined($opt_i)) {             # Set specified input path.
      if (-d $opt_i) {
         $InputDir = $opt_i;
      }
      else {
         DisplayError("Specified input path not found: $opt_i");
         exit(1);
      }
   }
   DisplayDebug("InputDir: $InputDir");
   
   if (defined($opt_o)) {             # Set specified output path.
      $OutputDir = $opt_o;
      unless (-d $OutputDir) {        # Create output path if necessary.
         mkdir $OutputDir;
         unless (-d $OutputDir) {
            DisplayError("Can't create output path: $OutputDir");
            exit(1);
         }
      }
   }
   DisplayDebug("OutputDir: $OutputDir");
}

if (defined($opt_n)) {             # Set specified normalization level.
   if ($opt_n >= $NormMin and $opt_n <= $NormMax) {
      $Normalize = $opt_n;
   }
   else {
      DisplayError("Invalid normalization level: $opt_n");
      exit(1);
   }
   DisplayDebug("Normalize to: $Normalize dB");
}

if (defined($opt_r)) {             # Set specified MP3 bitrate.
   if ($opt_r >= 96 and $opt_r <= 320) {
      $Mp3Rate = $opt_r;
   }
   else {
      DisplayError("Invalid normalization level: $opt_r");
      exit(1);
   }
   DisplayDebug("MP3 bitrate: $Mp3Rate Kbps");
}

if (defined($opt_c)) {             # Set specified cover image file.
   $opt_c = join('/', $InputDir, $opt_c) unless ($opt_c =~ m#^.{0,2}/#);
   if (-e $opt_c) {
      $CoverImg = $opt_c;
      $CoverImg = join('', '"', $CoverImg, '"') if ($CoverImg =~ m/ /);
   }
   else {
      DisplayError("Specified image not found: $opt_c");
      exit(1);
   }
   DisplayDebug("Cover image: $CoverImg");
}

# ==========
# Get input file names to process.
my @mp4List = ();
if (scalar(@ARGV) > 0) {
   foreach my $file (@ARGV) {
      if ($file =~ m/\.mp4$/) {
         if ($file =~ m#^.{0,2}/#) {
            push (@mp4List, $file);
         }
         else {
            push (@mp4List, join('/', $InputDir, $file));
         }
      }
      else {
         DisplayError("Invalid input file: $file");
         exit(1);
      }
   }
}
else {
   # Use bsd_glob to properly handle space characters in the input
   # directory path.
   @mp4List = grep { -f } bsd_glob "$InputDir/*.mp4";
}
DisplayDebug("mp4List: '@mp4List'");

# Process the input files.
if ($#mp4List >= 0) {
   foreach my $mp4 (@mp4List) {
      DisplayMessage("Processing $mp4 ...");
      $TrackCnt++ if (defined($opt_t));
      exit(1) if (&ProcessFile($mp4, $Normalize, $Mp3Rate, $OutputDir, 
                               $TrackCnt, $CoverImg));
   }
}
else {
   DisplayMessage("No mp4 files. For help use $ExecutableName -h");
}

exit(0);
