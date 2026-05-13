#!/usr/bin/perl
# ==============================================================================
# FILE: wordle.pl                                                     5-13-2026
#
# SERVICES: Wordle Word Guess Game 
#
# DESCRIPTION:
#   This program is a perl based adaptation of the word guessing game Wordle.
#   It is run from the terminal/command line and uses ANSI color sequences to
#   color the letter clues that are output after each guess. Coded and debugged
#   using Linux Mint 22.3, Windows 7, and, perl v5.40. Coded as an exercise 
#   in ANSI color, character graphics, and cross-platform compatibility.
#
#   With respect to character graphics, considerable time was spent in making 
#   the program functional in linux and windows environments. Linux uses UTF8
#   characters for drawing boxes around the letters. In windows, code page 
#   CP437 characters are used. Couldn't get UTF8 to work with strawberry perl
#   though that effort is ongoing. 
#
#   In windows, an escape sequence is needed to tell Win32::Console::ANSI that
#   the CP437 characters are used. See https://bribes.org/perl/wANSIConsole.html  
#   '\e(437X'. This took more time than I care to admit to figure out. For an 
#   additional environmental workaround, the startup -a option can be used to
#   disable box drawing. Use the -2 option for double line letter boxes.
#
#   The file 'wordle-word-list.txt' contains the valid words used by the program.
#   A random word is selected from the file during program start. The file
#   'wordle-clue-list.txt' contains words that are valid input but not selected
#   as a target word. Both files must be located with the program file.
#
# REVISION HISTORY:
#   v0.1   05-07-2026   Initial release.
#   v0.2   05-09-2026   Reworked ProcessGuess logic and used letter display. 
#                       Verified program operation in Windows 11 and perl v5.42.
#   v0.3   05-13-2026   Added exit confirmation for Windows environments.
#
# PERL VERSION: v5.42
#
# ==============================================================================
use strict;
use warnings;
use Term::ANSIColor;
require Win32::Console::ANSI if ($^O =~ m/Win/i);
use utf8;

# ----------
# Seed the random number generator for word selection.
srand(time);

# Compliment word at end of game.
my %Compliment = (1 => 'Genius', 2 => 'Magnificent', 3 => 'Impressive',
                  4 => 'Splendid', 5 => 'Great', 6 => 'Phew');
                   
# Used letters hash indexed by letter. Value is the current color. 
my %UsedLetters = ();
            
# The %GuessHash defaults to the data used for the instructions example.            
my %GuessHash = (1 => {'letter' => ['W','E','A','R','Y'], 
   'color' => ['BRIGHT_GREEN','WHITE','WHITE','BRIGHT_YELLOW','WHITE']});

# The %StatsHash holds the game play statistics.
my %StatsHash = ();

# The following arrays are loaded from files in the CWD at startup. 
my @WordList = ();     # Words used for answer.
my @ClueList = ();     # Words permitted as input guesses.

my $WordFile = 'wordle-word-list.txt';
my $ClueFile = 'wordle-clue-list.txt';
my $StatsFile = 'wordle-stats.txt';

# Check for command line options.
my ($NoBox, $Boxline, $Debug) = (0, 1, 0);
foreach my $arg (@ARGV) {
   $NoBox = 1 if ($arg =~ m/^-a$/);      # Process CLI -a option.
   $Boxline = 2 if ($arg =~ m/^-2$/);    # Process CLI -2 option.
}

# ----------
# Load the working word data and previous statistics.
exit(1) if (&LoadWorkingData(\@WordList, \@ClueList, \%StatsHash, 
                             $WordFile, $ClueFile, $StatsFile));

if (scalar %StatsHash == 0) {  # Initialize stats if no previous.
   foreach my $stat ('Game Score:','Avg Score:','Games Won:','Games Lost:', 
                     'Win Streak:','Max Streak:','Game Total:','Win Pct:') {
      $StatsHash{$stat} = 0;
   }
   &ColorMsg("\nGame play statistics have been initialized.",'BRIGHT_YELLOW','');
}   

# ----------
# Display program usage.
exit(1) if (&DisplayInstructions(\%GuessHash, $Boxline, $NoBox));

# ----------
# Randomly select a word.
my $Word = uc $WordList[ int(rand(scalar @WordList)) ]; 
# &ColorMsg("Word: $Word",'WHITE','');

# ----------
# Initialize the used letters hash.
foreach my $letter ('A'..'Z') {
   $UsedLetters{$letter} = 'WHITE';
}

# ----------
# Main game play..
my $guessCnt = 1;
my $GuessMax = 6;
my $guess;
while ($guessCnt <= $GuessMax) {
   &ColorMsg("Guess $guessCnt of $GuessMax or q to quit. -> ",'WHITE','nocr');
   chomp($guess = <STDIN>);
   $guess =~ s/^\s+|\s+$//g;
   last if ($guess =~ m/^q$/i or $guess =~ m/^e$/i);    # Exit if q or e.
   next if ($guess eq '' or length($guess) != 5);
   $guess = uc $guess;
   unless (grep /$guess/i, @WordList or grep /$guess/i, @ClueList) {
      &ColorMsg("Not in word list: $guess",'BRIGHT_RED','');
      next;
   }
   @{ $GuessHash{$guessCnt}{'letter'} } = split(//, $guess);
   exit(1) if (&ProcessGuess(\%GuessHash, $guessCnt, $Word, $guess, \%UsedLetters));
   exit(1) if (&DisplayGuess(\%GuessHash, $Boxline, $NoBox));   
   exit(1) if (&DisplayUsedLetters(\%UsedLetters));
   if ($guess eq $Word) {
      &UpdateGameStats(\%StatsHash, $guessCnt, 'win');
      my $compliment = "$Compliment{$guessCnt}!";
      my $indent = ' ' x (17 - int(length($compliment)/2));
      &ColorMsg($indent . $compliment,'BRIGHT_CYAN','');
      last;
   }
   $guessCnt++;
}

# ----------
# Show closing information.
if ($guess =~ m/^q$/i or $guess =~ m/^e$/i) {
   &ColorMsg("Word was: ",'WHITE','nocr');
   &ColorMsg($Word,'BRIGHT_CYAN','');
   exit(0);
}   
elsif ($guessCnt > $GuessMax) {
   my $spc = ' ' x 10;
   &ColorMsg($spc . "Word was: ",'WHITE','nocr');
   &ColorMsg("$Word\n",'BRIGHT_CYAN','');
   &UpdateGameStats(\%StatsHash, $GuessMax, 'lose');
}
exit(1) if (&DisplayGameStats(\%StatsHash));

# ----------
# Save game statistics.
my $tmpFile = $StatsFile;
$tmpFile =~ s/(\.txt)$/_tmp$1/;
my $fh;
if (open($fh, '>', $tmpFile)) {
   foreach my $key (sort keys(%StatsHash)) {
      unless (print $fh "$key $StatsHash{$key}\n") {
         &ColorMsg("Error writing file: $tmpFile - $!",'BRIGHT_RED','');
         close($fh);
         exit(1);
      } 
   }
   close($fh);
   if (-e $tmpFile) {
      unlink $StatsFile;
      rename $tmpFile, $StatsFile;
   }
}
else {
   &ColorMsg("Error opening file: $StatsFile - $!",'BRIGHT_RED','');
}

# The following exit code is run in windows environments to differentiate
# between a CMD window CLI launch of the program and launch initiated by a
# double click of the wordle.pl file. The former defines a $ENV{'PROMPT'} 
# variable, the latter does not. Tested in Windows 7 and 11. This results 
# in a 'Press Enter key to exit' message giving the user an opportunity to
# view the game score and statistics before the CMD window is closed.
if ($^O =~ m/Win/i) {
   unless (exists($ENV{'PROMPT'})) {
      &ColorMsg("Press Enter key to exit.",'WHITE','');
      chomp($guess = <STDIN>);
   }
}
exit(0);

# =============================================================================
# FUNCTION:  LoadWorkingData
#
# DESCRIPTION:
#    This routine loads the working word list files and previous game statistics.
#    The word list file must successfully load.
#
# CALLING SYNTAX:
#    $result = &LoadWorkingData(\@WordList, \@ClueList, \%StatsHash, 
#                               $WordFile, $ClueFile, $StatsFile);
# ARGUMENTS:
#    $WordList        Pointer to word list array.
#    $ClueList        Pointer clue word array.
#    $StatsHash       Pointer to statistics hash.
#    $WordFile        Word list file name.
#    $ClueFile        Clue words file name.
#    $StatsFile       Statistics data file name.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub LoadWorkingData {
   my($WordList, $ClueList, $StatsHash, $WordFile, $ClueFile, $StatsFile) = @_;
   my $fh;

   # ----------
   # Read the word list file.
   if (-e $WordFile) {
      unless (open($fh, '<', $WordFile)) {
         &ColorMsg("Error opening file: $WordFile - $!",'BRIGHT_RED','');
         return 1;
      }
      @$WordList = <$fh>;
      close($fh);
      chomp foreach @$WordList;
      # &ColorMsg(scalar @$WordList . " words loaded.",'WHITE','');
   }
   else {
      &ColorMsg("File not found: $WordFile",'BRIGHT_RED','');
      return 1;
   }
   
   # ----------
   # Read the clue word list file.
   if (-e $ClueFile) {
      unless (open($fh, '<', $ClueFile)) {
         &ColorMsg("Error opening file: $ClueFile - $!",'BRIGHT_RED','');
      }
      @$ClueList = <$fh>;
      close($fh);
      chomp foreach @$ClueList;
      # &ColorMsg(scalar @$ClueList . " clue words loaded.",'WHITE','');
   }
   else {
      &ColorMsg("File not found: $ClueFile",'BRIGHT_RED','');
   }

   # ----------
   # Read statistics file.
   if (-e $StatsFile) {
      if (open($fh, '<', $StatsFile)) {
         while (my $rec = <$fh>) {
            chomp($rec);
            if ($rec =~ m/^(.+:)\s*(.+)/) {
               $$StatsHash{$1} = $2;
               # print "$1 $StatsHash{$1} $2\n";
            }
         }
         close($fh);
      }
      else {
         &ColorMsg("Error opening file: $StatsFile - $!",'BRIGHT_YELLOW','');
      }
   }
   return 0;
}

# =============================================================================
# FUNCTION:  ProcessGuess
#
# DESCRIPTION:
#    This routine processes the specified %GuessHash entry. It adds the 'color' 
#    sub-key based on analysis of the target word and guess word. The yellow
#    indication, letter used but wrong position, is limited by the number of 
#    times the letter is used in the answer word. $Word with one G and $Guess
#    containing two G's results in the 2nd G in $Guess showing as unused (white)
#    instead of used (yellow). This behavior is consistent with the online game.
#
# CALLING SYNTAX:
#    $result = &ProcessGuess(\%GuessHash, $GuessIdx, $Word, $Guess, \%UsedLetters);
#
# ARGUMENTS:
#    $GuessHash       Pointer to guess hash.
#    $GuessIdx        GuessHash index for color result.
#    $Word            Answer word.
#    $Guess           User guess word.
#    $UsedLetters     Pointer to used letters hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ProcessGuess {
   my($GuessHash, $GuessIdx, $Word, $Guess, $UsedLetters) = @_;
   my @colors = ('WHITE','WHITE','WHITE','WHITE','WHITE');   
   my($wChr, $gChr);

   # Set matching letters green.   
   for (my $x = 0; $x < length($Guess); $x++) {
      if (substr($Word, $x, 1) eq substr($Guess, $x, 1)) {
         $colors[$x] = 'BRIGHT_GREEN';
         $gChr = substr($Guess, $x, 1);          # Guess word character
         $$UsedLetters{$gChr} = 'BRIGHT_GREEN';
         substr($Word, $x, 1) = '-';             # Remove from further checks.
         substr($Guess, $x, 1) = '-';            # Mark guess letter used.
      }
   }
   
   # Set mispositioned letters to yellow.   
   for (my $x = 0; $x < length($Guess); $x++) {
      $gChr = substr($Guess, $x, 1);             # Guess word character
      next if ($gChr eq '-');
      for (my $y = 0; $y < length($Word); $y++) {
         $wChr = substr($Word, $y, 1);           # Answer word character
         if ($wChr eq $gChr) {
            substr($Word, $y, 1) = '-';          # Remove from further checks.
            substr($Guess, $x, 1) = '-';         # Mark guess letter used.
            $colors[$x] = 'BRIGHT_YELLOW';
            $$UsedLetters{$gChr} = 'BRIGHT_YELLOW';
            last;
         }
      }
   }

   # Set unused letters to gray.   
   for (my $x = 0; $x < length($Guess); $x++) {
      $gChr = substr($Guess, $x, 1);             # Guess word character
      next if ($gChr eq '-' or $$UsedLetters{$gChr} ne 'WHITE');
      $$UsedLetters{$gChr} = 'BRIGHT_BLACK';
   }
   @{ $$GuessHash{$GuessIdx}{'color'} } = @colors;
   return 0;
}

# =============================================================================
# FUNCTION:  DisplayInstructions
#
# DESCRIPTION:
#    Displays the game play instructions.
#
# CALLING SYNTAX:
#    $result = &DisplayInstructions(\%GuessHash, $Boxline, $NoBox);
#
# ARGUMENTS:
#    $GuessHash       Pointer to guess hash.
#    $Boxline         Box line; 1=single, 2=double
#    $NoBox           No letter boxes if set to 1.  (-a option)
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub DisplayInstructions {
   my($GuessHash, $Boxline, $NoBox) = @_;

   &ColorMsg("\n   - - -  ",'BRIGHT_MAGENTA','nocr');
   &ColorMsg("P E R L   W O R D L E",'BRIGHT_CYAN','nocr');
   &ColorMsg("  - - -\n",'BRIGHT_MAGENTA','');
   &ColorMsg("Guess the WORDLE in six tries. Each guess must be a valid five",
             'WHITE','');
   &ColorMsg("letter word. After each guess, the color of the letters will",'WHITE','');
   &ColorMsg("change to show how close your guess is to the word.\n",'WHITE','');
   &ColorMsg("Example:",'WHITE','');
   return 1 if (&DisplayGuess($GuessHash, $Boxline, $NoBox));   
   &ColorMsg("\n     W is in the word and in the correct spot.",'WHITE','');
   &ColorMsg("     R is in the word but in the wrong spot.",'WHITE','');
   &ColorMsg("     White letters are not in the word in any spot.\n",'WHITE','');
   
   return 0;
}

# =============================================================================
# FUNCTION:  DisplayUsedLetters
#
# DESCRIPTION:
#    Displays the letters that have been used. Letters are displayed in keyboard
#    layout and colored based on the %UsedLetters hash.
#
# CALLING SYNTAX:
#    $result = &DisplayUsedLetters(\%UsedLetters);
#
# ARGUMENTS:
#    $UsedLetters      Pointer to used letters hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub DisplayUsedLetters {
   my($UsedLetters) = @_;
   my @keyboard = ('5QWERTYUIOP', '7ASDFGHJKL', '9ZXCVBNM');
   
   &ColorMsg('','WHITE','');
   foreach my $keyRow (@keyboard) {
      my @rowKeys = split(//, $keyRow);
      my $cnt = splice(@rowKeys, 0, 1);
      my $row = ' ' x $cnt;
      foreach my $key (@rowKeys) {
         if (exists($$UsedLetters{$key})) {
            my $col = $$UsedLetters{$key};
            $key = join('', color("$col"), $key, color("RESET"));
         }
         $row = join('', $row, $key, '  ');
      }
      &ColorMsg($row,'','');
   }
   &ColorMsg('','WHITE','');
   return 0;
}

# =============================================================================
# FUNCTION:  DisplayGuessHash
#
# DESCRIPTION:
#    Displays the letters in the specified hash using optional box drawing 
#    characters. The primary hash key is the guess number. Sub-arrays 'letter' 
#    and 'color' are present in previous guesses. The 'ltr' array holds the
#    guessed letter for the position. The 'color' array holds the color for
#    the box and letter.
#
#    Some additional code magic tells Win32::Console::ANSI that extended
#    characters, in this case code page 437 box drawing, are in use. Escape
#    sequence '\e(437X'. See https://bribes.org/perl/wANSIConsole.html
#
# CALLING SYNTAX:
#    $result = &DisplayGuessHash(\%GuessHash, $Boxline, $NoBox);
#
# ARGUMENTS:
#    $GuessHash       Pointer to guess hash.
#    $Boxline         Box line; 1=single, 2=double
#    $NoBox           No letter boxes if set to 1.  (-a option)
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub DisplayGuess {
   my($GuessHash, $Boxline, $NoBox) = @_;
   my ($ltrLine, $key);
   my $indent = ' ' x 5;
   $indent = ' ' x 13 if ($NoBox);

   # The following hash defines the box drawing characters. Single and double
   # line sets for CP437 and uft8.
   my %boxChar = ('c1T' => "\x{DA}\x{C4}\x{C4}\x{C4}\x{BF} ",
                  'c1L' => "\x{B3} %%% \x{B3} ",
                  'c1B' => "\x{C0}\x{C4}\x{C4}\x{C4}\x{D9} ",
                  'c2T' => "\x{C9}\x{CD}\x{CD}\x{CD}\x{BB} ",
                  'c2L' => "\x{BA} %%% \x{BA} ",
                  'c2B' => "\x{C8}\x{CD}\x{CD}\x{CD}\x{BC} ",
                  'u1T' => "\x{250C}\x{2500}\x{2500}\x{2500}\x{2510} ",
                  'u1L' => "\x{2502} %%% \x{2502} ",
                  'u1B' => "\x{2514}\x{2500}\x{2500}\x{2500}\x{2518} ",
                  'u2T' => "\x{2554}\x{2550}\x{2550}\x{2550}\x{2557} ",
                  'u2L' => "\x{2551} %%% \x{2551} ",
                  'u2B' => "\x{255A}\x{2550}\x{2550}\x{2550}\x{255D} ");
   
   &ColorMsg('','WHITE','');
   foreach my $guess (sort {$a <=> $b} keys(%$GuessHash)) {
      my @letters = ();   my @colors = ();
      my @top = ();   my @ltr = ();   my @bot = ();
      
      # Build a row of letters.
      if (exists($$GuessHash{$guess}{'letter'})) {
         @letters = @{ $$GuessHash{$guess}{'letter'} };
      }
      if (exists($$GuessHash{$guess}{'color'})) {
         @colors = @{ $$GuessHash{$guess}{'color'} };
      }
      foreach my $pos (0..4) {
         my $color = 'WHITE';                           # Default color
         $color = $colors[$pos] if (exists($colors[$pos]));
         if ($NoBox) {
            $ltrLine = "$letters[$pos] ";
            push (@ltr, join('',color($color), $ltrLine, color('RESET')));
         }
         else {                    # Box drawing characters around letter.
            if ($^O =~ m/Win/i) {  # Use code page 437 extended characters.
               $key = ($Boxline == 2) ? 'c2' : 'c1';
            }
            else {                 # Use unicode characters.
               $key = ($Boxline == 2) ? 'u2' : 'u1';
            }
            $ltrLine = $boxChar{"${key}L"};
            $ltrLine =~ s/%%%/$letters[$pos]/;
            push (@top, join('',color($color), $boxChar{"${key}T"}, color('RESET')));
            push (@ltr, join('',color($color), $ltrLine, color('RESET')));
            push (@bot, join('',color($color), $boxChar{"${key}B"}, color('RESET')));
         }
      }
      
      # Display row of letters.
      if ($NoBox) {
         print STDOUT $indent, @ltr, color('RESET'), "\n";  # Letter only.
      }
      else {
         if ($^O =~ m/Win/i) { 
            print STDOUT "\e(437X";             # Win32::Console::ANSI CP437.
         }
         else {
            binmode(STDOUT, ":utf8");                       # Set for unicode.  
         } 
         print STDOUT $indent, @top, color('RESET'), "\n";  # Top of boxs.
         print STDOUT $indent, @ltr, color('RESET'), "\n";  # Box sides and letter.
         print STDOUT $indent, @bot, color('RESET'), "\n";  # Bottom of box.
         binmode(STDOUT, ":bytes");                         # Restore to default.
      }
   }
   return 0;
}

# =============================================================================
# FUNCTION:  UpdateGameStats
#
# DESCRIPTION:
#    Called to update the game statistics hash.
#
# CALLING SYNTAX:
#    $result = &UpdateGameStats(\%StatsHash, $Guesses, $Type);
#
# ARGUMENTS:
#    $StatsHash       Pointer to the game statistics hash.
#    $Guesses         Number if guesses made.
#    $Type            'win' or 'lose'
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub UpdateGameStats {
   my($StatsHash, $Guesses, $Type) = @_;
   
   $$StatsHash{'Game Score:'} = $Guesses;
   if ($$StatsHash{'Avg Score:'} == 0) {
      $$StatsHash{'Avg Score:'} = $Guesses;
   }
   else {
      $$StatsHash{'Avg Score:'} = sprintf("%.2f", ($$StatsHash{'Avg Score:'} + 
                                                   $Guesses) /2);
   }
   if ($Type =~ m/^win/i) {
      $$StatsHash{'Games Won:'}++;
      $$StatsHash{'Win Streak:'}++;
      if ($$StatsHash{'Win Streak:'} > $$StatsHash{'Max Streak:'}) {
         $$StatsHash{'Max Streak:'} = $$StatsHash{'Win Streak:'};
      }
   }
   elsif ($Type =~ m/^lose/i) {
      $$StatsHash{'Games Lost:'}++;
      $$StatsHash{'Win Streak:'} = 0;
   }
   $$StatsHash{'Game Total:'} = $$StatsHash{'Games Won:'} + $$StatsHash{'Games Lost:'};
   $$StatsHash{'Win Pct:'} = sprintf("%.0f", ($$StatsHash{'Games Won:'} / 
                                             $$StatsHash{'Game Total:'}) * 100);
   return 0;
}

# =============================================================================
# FUNCTION:  DisplayGameStats
#
# DESCRIPTION:
#    Displays the game statistics to the user.
#
# CALLING SYNTAX:
#    $result = &DisplayGameStats(\%StatsHash);
#
# ARGUMENTS:
#    $StatsHash       Pointer to the game statistics hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub DisplayGameStats {
   my($StatsHash) = @_;
   my ($str, @column);
   my $spc2 = ' ' x 2;   my $spc5 = ' ' x 5;
   my @report = ('Game Score:_Avg Score:','Games Won:_Games Lost:',
                 'Win Streak:_Max Streak:','Game Total:_Win Pct:');
   
   &ColorMsg("\n   - - -  ",'BRIGHT_MAGENTA','nocr');
   &ColorMsg("S T A T I S T I C S",'BRIGHT_CYAN','nocr');
   &ColorMsg("  - - -",'BRIGHT_MAGENTA','');
   foreach my $line (@report) {
      @column = split('_', $line);
      foreach my $key (@column) {
         $str = join('', $key, $spc5);
         $str = substr($str, 0, 12);
         &ColorMsg($spc2 . $str,'WHITE','nocr');
         if ($key eq 'Win Pct:') {
            &ColorMsg("$StatsHash{$key}%",'BRIGHT_CYAN','nocr');
         }
         else {
            &ColorMsg(sprintf("%-5s",$StatsHash{$key}),'BRIGHT_CYAN','nocr');
         }
      }   
      &ColorMsg('','WHITE','');
   }
   &ColorMsg('','WHITE','');
   return 0;
}

# =============================================================================
# FUNCTION:  ColorMsg
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
#    Space separate multiple constants. e.g. BOLD BLUE ON_WHITE
#  
# CALLING SYNTAX:
#    $result = &ColorMsg($Message, $Color, $Nocr);
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
sub ColorMsg {
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
