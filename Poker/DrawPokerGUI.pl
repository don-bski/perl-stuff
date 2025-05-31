# ==============================================================================
# FILE: DrawPokerGui.pl                                               8-01-2024
#
# SERVICES: Draw Poker Perl-Tk GUI
#
# DESCRIPTION:
#   This program provides a Perl-Tk GUI interface to DrawPoker.pl. Tk displays
#   the various GUI objects and processes user interaction via its event driven
#   methodologies. Gameplay utilizes a 'state machine' architecture that uses
#   the $GameState variable for state control and transition. Onscreen controls
#   are enabled/disabled for game flow.
#
#   A new Tk MainWindow is created during program launch. The game preferences
#   screen is presented to the user. After making selections, the user clicks
#   the 'Ok' button. A Tk Toplevel screen is opened and used for all game play
#   related widgets and functions. When the Tk Toplevel is exit by the user, 
#   the preferences screen is again displayed. From here, the user can select
#   different preferences and start another game or terminate the program.
#
#   The Tk::Place function is used for positioning the screen widgets. All 
#   widget related data, as well as the game state and player data is held in
#   the DrawPokerGuiData.pm defined working hashes. These hash definitions
#   are selected and loaded during program startup, based on detected verticle
#   screen size, using dclone.
#
#   The module Tk::waitVariableX is used to perform game play related time 
#   delays. This function does not block other TK background functionality 
#   like the perl 'sleep' command does. A needed time delays call a subroutine
#   in DrawPokerGuiLib.pm that wraps this function.
#
#   When using a menubar launcher to start this program on Linux systems, two
#   required perl modules may fail to be located; Tk::waitVariableX and GD. This
#   necessitates code in the BEGIN block to add additional search paths to the
#   @INC variable. This hackish code is user account specific and not required
#   when the program is started from a terminal session.
#
#   When using the menubar launcher, if a required module is not found, the 
#   associated terminal will briefly open and then immediately close making it
#   difficult to troubleshoot the abort cause. Try one of the following.
#
#      Add 2>/home/pi/Desktop/log.txt to the end of the launcher command. 
#        Change 'pi' to the user account home directory. (Debian distros.)
#      Add '-H' to terminal command if supported. (Ubuntu mint XFCE.)
# 
#   For linux, use a menubar command similar to one of the following. Include
#   DrawPoker options if needed. Launcher command for Windows/MacOS is TBD. 
#
#      lxterminal --geometry=50x5 -t 'Poker GUI' -l -e '/usr/bin/perl /home/pi/
#        perl5/code_examples/DrawPoker/DrawPokerGUI.pl'
#      xfce4-terminal --geometry=50x5 -T 'Poker GUI' -e '/usr/bin/perl /home/
#        don/perl/code_examples/DrawPoker/DrawPokerGUI.pl'
#
#   There are a few keys and options that are defined primarily for program
#   debug. The -x option enables adult mode which displays progressive opponent
#   images on the game table. In this mode, the arrow keys will change the 
#   opponent images. The < and > keys can be used to set player bankrolls; 
#   $450 and $50 or $50 and $450 respectively. The ? key displays the current
#   hand rank for player 2.
#
# PERL VERSION:  5.28.1
#
# ==============================================================================
BEGIN {
   use Cwd;
   our ($ExecutableName) = ($0 =~ /([^\/\\]*)$/);
   if (length($ExecutableName) == length($0)) {
      $WorkingDir = cwd();
   }
   else {
      if ($^O =~ m/Win/) {
         $WorkingDir = substr($0, 0, rindex($0, "\\"));
      }
      else {
         $WorkingDir = substr($0, 0, rindex($0, "/"));
      }
   }
   unshift (@INC, $WorkingDir);
   # Set additional paths needed for Raspberry Pi and laptop.
   if ($WorkingDir =~ m#/home/pi#) {  # RPi paths to Tk::waitVariableX and GD
      unshift (@INC, '/home/pi/perl5/lib/perl5');
      unshift (@INC, '/home/pi/perl5/lib/perl5/aarch64-linux-gnu-thread-multi');
   }
   elsif ($WorkingDir =~ m#/home/don#) {  # Laptop paths to Tk::waitVariableX and GD
      unshift (@INC, '/home/don/perl/lib/perl5');   
      unshift (@INC, '/home/don/perl/lib/perl5/x86_64-linux-gnu-thread-multi');
   }
}

# -------------------------------------------------------------------------
# External module definitions.
use Getopt::Std;
use Tk;
use Tk::PNG;
use Tk::JPEG;
use Tk::waitVariableX;
use Time::HiRes qw(gettimeofday);
use POSIX qw(strftime);
use DrawPokerGuiLib;
use DrawPokerGuiData;

# Seed random number generator.
srand(time);

# Global variables and working data.
%Game = ();                     # Game play working data
%Header = ();                   # Header section working data.
%Cards = ();                    # Card section working data.
%Footer = ();                   # Footer section working data.
%Pref = ();                     # Startup screen working data.
%MsgData = ();                  # Gameplay messages.
%Image = ();                    # Game images.
$Logfile = '';                  # Set if logging to file is specified (-l).
$Xdotool = '/usr/bin/xdotool';  # Utility tool for minimizing launch terminal.

# Program help text.
$UsageText = (qq(
===== Help for $ExecutableName ================================================

GENERAL DESCRIPTION
   This program is a perl-tk implementation of the card game five card draw
   poker. Game play is between the computer and a single user. Each player
   begins with a \$100 bankroll. Bankrolls are loaned \$100 for losses up to
   3 times. Winnings are used to pay back loans. The game ends when either 
   player wins \$500.
   
   The cards are shuffled before each hand. Players automatically ante \$5 at
   the start of each round and have the opportunity to wager before and after
   card exchange. Players wager in \$5 increments, \$5-\$25. First player to 
   bet will alternate after each round.
   
   Keyboard keys 1-5 can be used for wager entry. These keys 1-5 can also
   be used to mark cards for discard in addition to mouse click on card.
   In general, the most common screen button is activated by the 'Enter'
   key. e.g. Deal, Discard, Call
   
   Use the preferences window to select the desired game play options. The
   OK button saves the selections for use as defaults in subsequent 
   program starts. It also initiates game play. 

USAGE:
   $ExecutableName  [-h] [-d <lvl>] [-a] [-s] [-x] [-l]
   
   -h             Displays program usage text.
   -d <lvl>       Run at specified debug level; 0-4. Level 4 is used for
                  widget positioning and alignment.
   -a             Auto-play mode. Used for game play evaluation. Click drop 
                  button at end of round to stop.
   -s             Verticle card orientation.
   -x             Force -s. Opponent multiple images.
   -l             Send debug output to file instead of console. Must also
                  specify a -d level.
   
EXAMPLES:
   $ExecutableName

===============================================================================
));

# =============================================================================
# MAIN PROGRAM
# =============================================================================
# Process user specified CLI options.
getopts("haxsld:");

# Display program help if -h specified.
if (defined($opt_h)) {
	 print"$UsageText\n";
	 exit(0);  
}

# Minimize launch terminal if not wayland and linux xdotool is available.
if ($ENV{'XDG_SESSION_TYPE'} =~ m/wayland/i ) {
   print "Wayland detected. Can't use xdotool to minimize launch console. \n";
}
else {
   if ($^O =~ m/linux/i and not defined($opt_d)) {
      my($result) = `which $Xdotool`;
      chomp($result);
      if ($Xdotool eq $result) {
         my($actWindow) = `$Xdotool getactivewindow`;
         chomp($actWindow);
         $result = `$Xdotool windowminimize $actWindow`;
      }
   }
}

# Setup for log file.
if (defined($opt_l)) {
   $Logfile = $0;
   $Logfile =~ s/\.pl$/\.log/;
   unlink $Logfile if (-e $Logfile);
   &DisplayDebug(2, "===== Logfile: $Logfile =====");
   my($timestamp) = strftime('%Y-%m-%d_%H:%M:%S', localtime);
   &DisplayDebug(2, "===== Start logging: $timestamp =====");
}

# Set card orientation.
$opt_s = 1 if (defined($opt_x));
if (defined($opt_s)) {
   $orientation = 'vertical';
}
else {
   $orientation = 'horizontal';
}

# Launch main window and get the monitor screen height. Load working hashes which
# contain the widget size and screen position data for each supported resolution.
my($mw) = MainWindow->new;
$mw->resizable(0,0);   
my($monHeight) = $mw->screenheight;
my($monWidth) = $mw->screenwidth;

# Load working hashes.
if (&LoadGuiData($monHeight, $orientation, \%Header, \%Cards, \%Footer, \%Pref,
       \%Game, \%MsgData)) {
   &ColorMessage("Error return from LoadGuiData.", 'RED');
   exit(1);
}

# Add path to various hash file values.
$Game{'Main'}{'BackImg'} = join('/', $WorkingDir, 'cards', 
                                $Game{'Main'}{'BackImg'});
$Pref{'p0'}{'backImg'} = join('/', $WorkingDir, 'cards', 
                              $Pref{'p0'}{'backImg'});   
# Setup for special gameplay.
if (defined($opt_s)) {     
   exit(1) if (&GenOpponent($mw, \%Game, $monHeight, \%MsgData, $WorkingDir));
}
$mw->title($MsgData{'02'});
$Game{'AutoPlay'} = 0;
$Game{'AutoPlay'} = 1 if (defined($opt_a));
$mw->bind('<KeyPress>' => [\&ArrowKey, $mw, \%Game, \%Pref, \%Header]);
$Game{'Main'}{'StartX'} = ($monWidth - $Game{'Main'}{'Width'}) / 2;
$Game{'Main'}{'StartY'} = ($monHeight - $Game{'Main'}{'Height'}) / 2;
&DisplayDebug(1, "main: $monWidth x $monHeight   game: $Game{'Main'}{'Width'} x " .
   "$Game{'Main'}{'Height'}   $orientation   Origin: $Game{'Main'}{'StartX'},".
   "$Game{'Main'}{'StartY'}");   

# Initialize a new deck of cards and shuffle them. Use -d 3 to show.
&Newdeck(\@{ $Game{'Deck'}{'Cards'} });
my($sec, $usec) = gettimeofday();
my($firstShuffleCount) = 13 + ($sec % 10) + int(rand(25));  # 13 - 46
$Game{'Deck'}{'dPos'} = &Shuffle(\@{ $Game{'Deck'}{'Cards'} }, $firstShuffleCount);
# Launch the game preferences window.
&GamePref($mw, \%Game, \%Header, \%Cards, \%Footer, \%Pref, \%MsgData);

MainLoop;                                      # Start Tk event loop.
1;
