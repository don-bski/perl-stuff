#!/usr/bin/perl
# ==============================================================================
# FILE: wled-librarian.pl                                             8-03-2025
#
# SERVICES: WLED Preset Librarian  
#
# DESCRIPTION:
#   This program is a simple WLED preset librarian. The perl DBD:SQlite module
#   is used for the database. This module includes the database and related 
#   access functions in a single distribution package. For details about this
#   perl module, see https://metacpan.org/pod/DBD::SQlite.
#
#   See the subroutine &InitDB for a description of the database tables and 
#   their associated column names/definitions.
#
#   For operational help, launch the program and enter help at the prompt.
#
# PERL VERSION:  5.28.1
# ==============================================================================
use Getopt::Std;
require Win32::Console::ANSI if ($^O =~ m/Win/i);
use Term::ReadKey;
use DBI;
use File::Copy;
use Time::HiRes qw(sleep);
use Data::Dumper;
# use warnings;
# $Data::Dumper::Sortkeys = 1;
# print Dumper $href;

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

# --- Add the executable included perl modules. Eval method for windows.
eval "use WledLibrarianLib";
eval "use WledLibrarianDBI";
# use WledLibrarianLib;
# use WledLibrarianDBI;

our %cliOpts = ();                           # CLI options working hash
getopts('hdaprc:', \%cliOpts);               # Load CLI options hash
our $DbFile = 'wled_librarian.dbs';          # Default database file
our $Dbh;                                    # Working reference to DB object
our $ChildPid = 0;                           # Pid of forked child. ShowOnWled
our $WledIp = '4.3.2.1';                     # WLED endpoint IP
our $Sort = 'Lid ASC';                       # Default output ordering.

our $UsageText = (qq(
===== Help for $ExecutableName ================================================

GENERAL DESCRIPTION
   Wled librarian is a simple tool that is used for the storage of WLED presets 
   as individual entities in a database. These preset data are tagged and grouped 
   by the user as needed. For example, 'xmas' might identify the presets used in
   a holiday display. Presets can then be selected ad-hoc or by tag/group word
   for export to a WLED presets file or directly to WLED over WIFI.
   
   The database is contained in a single file (default: wled_librarian.dbs) that
   is located in the librarian startup directory or optionally specified on the
   program start CLI. For additional safeguard, periodically copy the file to a 
   safe external location using an appropriate operating system CLI command. To 
   restore, copy the backup file to the working database file name.

   The -p option disables preset ID duplication checks during import. Preset data
   are import with existing ID values. Also during import, the preset data is 
   reformatted for user readability (show pdata). The -r option disables this 
   processing which may result in inconsistent key:value pair location within 
   the pdata.
       
   The -c option performs the specified command(s) directly. Results are sent to
   STDOUT and errors to STDERR. Used to integrate with a script or other external
   program. <cmds> must comform to the operational usage rules. See operational 
   help for details. 

   For operational help, launch the program and enter 'help' at the prompt.

USAGE:
   $ExecutableName  [-h] [-a] [-d] [-p] [-r] [-f <file>] [-c '<cmds>']

   -h              Displays this usage text.
   -a              Monochrome output. No ANSI color.
   -d              Run the program in debug mode.
   -p              Disable import preset ID checks.
   -r              Disable import preset data reformat.

   -f <file>       Use the specified database file.
   -c '<cmds>'     Process <cmds> non-interactive.
                  
EXAMPLES:
   $ExecutableName
      Run program using default database file wled_librarian.dbs located in the
      current working directory. Import preset ID checking is enabled.

   $ExecutableName -f /home/pi/myDB.dbs
      Run program using the /home/pi/myDB.dbs database file. 

   $ExecutableName -c 'SHOW tag:xmas EXPORT wled:4.3.2.1'
      Run program to show the presets tagged with xmas and export them to the
      active WLED at 4.3.2.1.

===============================================================================
));

# =============================================================================
# FUNCTION:  Ctrl_C
#
# DESCRIPTION:
#    This routine is used to perform final functions at program termination. 
#    The main code sets mutiple linux signal events to run this handler. For
#    wled-librarian.pl, this handler closes the database connection. We also
#    restore normal terminal operation since it was redirected by for arrow
#    history recall. 
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
#    $Dbh
# =============================================================================
sub Ctrl_C {
   $Dbh->disconnect;
   ReadMode('normal');                # Restore normal terminal input.
   sleep .1;
   exit(0);
}
sub SigTerm {
   exit(0);
}

# =============================================================================
# MAIN PROGRAM
# =============================================================================
# Process user specified CLI options.

# ==========
# Display program help if -h specified or no other option.
if (exists( $cliOpts{h} )) {
   &ColorMessage("$UsageText", "WHITE", '');
   exit(0);  
}

# ==========
# Setup for processing termination signals. Provides for properly closing the
# database by the Ctrl_C subroutine. Signal TERM calls a seperate subroutine.
# Used to simply exit a child process.                          
foreach my $sig ('INT','QUIT','ABRT','STOP','KILL','HUP') {
   $SIG{$sig} = \&Ctrl_C;
}
$SIG{TERM} = \&SigTerm;
$SIG{CHLD} = 'IGNORE';

# ==========
# Open database connection. Create a new database if user confirmed.
$DbFile = join('/', cwd(), $DbFile);          # Add cwd to default database file.
$DbFile = $cliOpts{f} if (exists( $cliOpts{f} ));  # Use CLI option if specified.
unless (-e $DbFile) {
   &ColorMessage("\nDatabase file not found: $DbFile", "BRIGHT_YELLOW", '');
   &ColorMessage("Create a new one? [y|N] -> ", "WHITE", 'nocr');
   my $resp = <STDIN>;
   chomp($resp);
   exit(0) unless ($resp =~ m/y/i);
   $Dbh = &InitDB($DbFile, 'new');
   $Dbh->disconnect;                      # We'll reconnect for validate.
}

# Validate database. The $Dbh object pointer will be used for all subsequent
# database queries.
$Dbh = &InitDB($DbFile, '');
exit(1) if ($Dbh == -1);                # Exit if database was not validated.

my %cmdHash = ('sort' => $Sort);   # Clear command and parsing hash. Set sort.
if ($cliOpts{c} ne '') {
   exit(1) if (&ParseInput($Dbh, $cliOpts{c}, \%cmdHash));
   exit(0);  
}

# Unbuffered output needed; mainly Windows environments.
$| = 1;

# ==========
# Setup the input working hash. See &GetKeyboardInput description for details.
my %inWork = ('inbuf' => '', 'iptr' => 0, 'prompt' => 'Enter -> ',
              'pcol' => 'BRIGHT_GREEN', 'noCmdcr' => 1,);
ReadMode('cbreak');                # Start readkey input processing.

# ==========
# Main program loop.
if ($Dbh) { 
   &DisplayHeadline();                  # Show the program's headline.
   my $runLoop = 1;
   while ($runLoop == 1) {
      # Initialize input hash.
      $inWork{'inbuf'} = '';
      $inWork{'iptr'} = 0;
      # Prompt user for input.
      &DisplayDebug("Call GetKeyboardInput for user command.");
      while (&GetKeyboardInput(\%inWork) == 0) {  # Wait for user input.
         sleep .2;
      }
      chomp($inWork{'inbuf'});
      &DisplayDebug("Process command: $inWork{'inbuf'}");
      if ($inWork{'inbuf'} =~ m/^q[uit]*$/i) {   # Terminate program if quit.
         &ColorMessage("   Program stop.", "YELLOW", '');
         $runLoop = 0;
         last;
      }
      
      # Parse and process the user input.
      %cmdHash = ('sort' => $Sort);   # Clear command and parsing hash. Set sort.
      # Kill &ShowOnWled started child process if running. Forked code used to
      # cycle preset on WIFI connected WLED.
      if ($ChildPid != 0) { 
         kill 'TERM', $ChildPid;
         $ChildPid = 0;
         sleep .1;
      }
      &ParseInput($Dbh, $inWork{'inbuf'}, \%cmdHash);
      if ($cmdHash{'cmd0'} eq 'quit') {
         $runLoop = 0;
         last;
      }
      # Save current sort if changed by sort command.
      $Sort = $cmdHash{'sort'} if ($Sort ne $cmdHash{'sort'});
   }
}

# Disconnect the database, restore normal terminal input, and terminate.
$Dbh->disconnect;
ReadMode('normal');
exit(0);
