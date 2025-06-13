#!/usr/bin/perl
# ==============================================================================
# FILE: learnReadkey.pl                                               6-13-2025
#
# SERVICES: Learning tool for ANSI and keyboard input handling.  
#
# DESCRIPTION:
#   This program was written as a learning tool for keyboard input handling
#   and ANSI color/control sequences in general. Term::ReadKey is used to 
#   process keyboard input since perl  $resp = <STDIN>  does not process the
#   keypad escape sequences. Downside is the program must periodically check
#   for user keyboard input.
#
#   The up and down arrow keys recall previous/next strings from input history.
#   The left and right arrow keys position the cursor for line editing. The
#   backspace and delete keys remove the character at the cursor position.
#   Typing inserts characters at the cursor position. The enter key commits 
#   the input for processing and adds it to the input history.
#
#   To properly handle auto-repeat input, &GetKeyboardInput gets only the 
#   number of bytes needed for keypad keys from ReadKey. This code will need 
#   change for other keys that return escape sequences. e.g. function keys. 
#
#   Add -d to program start CLI to see DisplayDebug message output.
#
# PERL VERSION:  5.28.1
# ==============================================================================
use Getopt::Std;
use Term::ReadKey;
use Time::HiRes qw(sleep);
# use warnings;

BEGIN {
   use Cwd;
   our ($ExecutableName) = ($0 =~ /([^\/\\]*)$/);
   our $WorkingDir = cwd();
   if (length($ExecutableName) != length($0)) {
      $WorkingDir = substr($0, 0, rindex($0, "/"));
   }
   unshift (@INC, $WorkingDir);
}

our %cliOpts = ();                           # CLI options working hash
getopts('d', \%cliOpts);                     # Init CLI options hash

# =============================================================================
# FUNCTION:  Ctrl_C
#
# DESCRIPTION:
#    This routine is called by the operating system when an abnormal program
#    termination occurs. It performs any final needed functions. The main code
#    sets mutiple signals to run this handler, e.g. SIGINT (ctrl+c).
#
#    This handler restores normal terminal ReadMode operation. It was set for 
#    ReadKey operation, ReadMode('cbreak'), by the main code. 
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
#    None
# =============================================================================
sub Ctrl_C {
   ReadMode('normal');                # Restore normal terminal input.
   exit(0);
}

# =============================================================================
# FUNCTION:  ColorMessage
#
# DESCRIPTION:
#    Displays a message to the user. If specified, an input parameter provides
#    coloring for the message text. Supported color constants are as follows.
#
#    black            red                green            yellow
#    blue             magenta            cyan             white
#    bright_black     bright_red         bright_green     bright_yellow
#    bright_blue      bright_magenta     bright_cyan      bright_white
#    gray             reset
#
#    gray = bright_black. reset return to screen colors.
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
   
   # The color constants and their associated ANSI terminal sequence.
   my(%colConst) = (
      'black' => "\e[30m", 'red' => "\e[31m", 'green' => "\e[32m",
      'yellow' => "\e[33m", 'blue' => "\e[34m", 'magenta' => "\e[35m",
      'cyan' => "\e[36m", 'white' => "\e[37m", 'gray' => "\e[90m",
      'bright_black' => "\e[90m", 'bright_red' => "\e[91m", 
      'bright_green' => "\e[92m", 'bright_yellow' => "\e[93m",
      'bright_blue' => "\e[94m", 'bright_magenta' => "\e[95m",
      'bright_cyan' => "\e[96m", 'bright_white' => "\e[97m", 
      'reset' => "\e[39;49m");
   
   $cr = '' if ($Nocr ne '');
      
   if ($Color ne '') {
      print STDOUT $colConst{ lc($Color) }, $Message, $colConst{'reset'}, "$cr";
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
#    $main::cliOpts{d}
# =============================================================================
sub DisplayDebug {
   my($Message) = @_;
   
   &ColorMessage($Message, 'BRIGHT_CYAN', '') if (defined( $main::cliOpts{d} ));
   return 0;
}

# =============================================================================
# FUNCTION:  ProcessKeypadInput
#
# DESCRIPTION:
#    This routine is used to process user keyboard input. Keys with no action
#    defined are ignored. The following table shows the expected byte sequence
#    for the keypad keys. 'iptr' is the current input buffer position.
#
#       Key              Action                      Bytes
#       ---------        ---------------             --------  
#       up arrow         previous history entry      27 91 65
#       down arrow       next history entry          27 91 66
#       left arrow       previous input character    27 91 68
#       right arrow      next input character        27 91 67
#       end                                          27 91 70
#       home                                         27 91 72
#       page up                                      27 91 53 126
#       page down                                    27 91 54 126
#       keypad 5                                     27 91 69
#       keypad 0 (ins)                               27 91 50 126
#       keypad . (del)   Delete character            27 91 51 126
#       enter                                        10
#       /                                            47
#       +                                            43
#       -                                            45
#       backspace        Delete prev character       127
#
# CALLING SYNTAX:
#    $result = &ProcessKeypadInput(\%InWork);
#
# ARGUMENTS:
#    $InWork           Pointer to input working hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub ProcessKeypadInput {
   my($InWork) = @_;

   # This hash is a dispatch table that defines the supported keypad byte 
   # sequences and the subroutine used to perform the actions.
   my(%keySub) = ('279151126' => \&delete, '127' => \&backSpace, '279165' => \&upArrow,
      '279166' => \&downArrow, '279168' => \&leftArrow, '279167' => \&rightArrow);
                  
   # This hash defines cursor move and edit ANSI sequences. Not all are used.
   # For details, see https://en.wikipedia.org/wiki/ANSI_escape_code             
   my(%cursor) = ('left' => "\e[D", 'right' => "\e[C", 'up' => "\e[A", 
                  'down' => "\e[B", 'clrLeft' => "\e[1K", 'clrRight' => "\e[0K",
                  'clrLine' => "\e[2K", 'delLine' => "\e[2K\r", 'insLine' => "\e[L",
                  'insChar' => "\e[\@", 'delChar' => "\e[P");               

   &DisplayDebug("ProcessKeypadInput: inseq: '$$InWork{'inseq'}'  ". 
                 "iptr: $$InWork{'iptr'}   inbuf: '$$InWork{'inbuf'}'  ".
                 "hptr: $$InWork{'hptr'}   history: @{ $$InWork{'history'} }");
   if (exists($keySub{ $$InWork{'inseq'} })) {
      return $keySub{ $$InWork{'inseq'} }->($InWork,\%cursor);  
   }
   &ColorMessage("ProcessKeypadInput: No handler for $$InWork{'inseq'}",
                 'BRIGHT_RED', '');
   return 1;
   
   # ----------
   # Delete key handler. Remove character after 'iptr'. Characters 'iptr'+1
   # to end shift left. 
   sub delete {
      my($InWork, $Cursor) = @_;
      my $pre = substr($$InWork{'inbuf'}, 0, $$InWork{'iptr'});
      my $post = substr($$InWork{'inbuf'}, $$InWork{'iptr'} +1);
      return 0 if ($post eq '');  # Nothing to delete.
      $$InWork{'inbuf'} = join('', $pre, $post);
      my $len = length($post);
      $post = join('', $$Cursor{'clrRight'}, $post);
      $post = join('', $post, "\e[", $len, "D") if ($len > 0);
      print $post;
      return 0;
   }

   # ----------
   # Backspace key handler. Remove the character left of 'iptr'. Characters
   # 'iptr' to end shift left. 
   sub backSpace {
      my($InWork, $Cursor) = @_; 
      my $pre = substr($$InWork{'inbuf'}, 0, $$InWork{'iptr'} -1);
      return 0 if ($pre eq '');   # Nothing to delete.
      my $post = substr($$InWork{'inbuf'}, $$InWork{'iptr'});
      $$InWork{'inbuf'} = join('', $pre, $post);
      $$InWork{'iptr'}--;
      my $len = length($post);
      $post = join('', $$Cursor{'left'}, $$Cursor{'clrRight'}, $post);
      $post = join('', $post, "\e[", $len, "D") if ($len > 0);
      print $post;
      return 0;
   }
   
   # ----------
   # Up arrow key handler. Populate 'inbuf' with previous @'history' entry.
   sub upArrow {
      my($InWork, $Cursor) = @_;
      if ($#{ $$InWork{'history'} } >= 0) {     # Ignore key if no history.
         return 0 if ($$InWork{'hptr'} == 0);   # Ignore key if at min. 
         $$InWork{'inbuf'} = ${ $$InWork{'history'} }[ --$$InWork{'hptr'} ];
         my $plen = 0;
         $plen = length($$InWork{'prompt'}) if (exists($$InWork{'prompt'}));
         $$InWork{'iptr'} = length($$InWork{'inbuf'});  # iptr to end-of-line  
         print $$Cursor{'delLine'};
         &ColorMessage($$InWork{'prompt'}, $$InWork{'pcol'}, 'nocr');         
         print $$InWork{'inbuf'};
      }
      return 0;
   }
   
   # ----------
   # Down arrow key handler. Populate 'inbuf' with next @'history' entry. 
   sub downArrow {
      my($InWork, $Cursor) = @_;
      if ($#{ $$InWork{'history'} } >= 0) {  # Ignore key if no history.
         return 0 if ($$InWork{'hptr'} == $#{ $$InWork{'history'} }); # Ignore if at max.
         $$InWork{'inbuf'} = ${ $$InWork{'history'} }[ ++$$InWork{'hptr'} ];
         my $plen = 0;
         $plen = length($$InWork{'prompt'}) if (exists($$InWork{'prompt'}));
         $$InWork{'iptr'} = length($$InWork{'inbuf'});  # iptr to end-of-line  
         print $$Cursor{'delLine'};
         &ColorMessage($$InWork{'prompt'}, $$InWork{'pcol'}, 'nocr');         
         print $$InWork{'inbuf'};
      }
      return 0;
   }
   
   # ----------
   # Left arrow key handler. Move cursor left unless already at start.
   sub leftArrow {
      my($InWork, $Cursor) = @_;
      if ($$InWork{'iptr'} > 0) {
         $$InWork{'iptr'}--;
         print $$Cursor{'left'};       # Move cursor left
      }
      return 0;
   }
   
   # ----------
   # Right arrow key handler. Move cursor right unless already at end.
   sub rightArrow {
      my($InWork, $Cursor) = @_;
      if ($$InWork{'iptr'} < length($$InWork{'inbuf'})) {
         $$InWork{'iptr'}++;
         print $$Cursor{'right'};      # Move cursor right
      }
      return 0;
   }
}   

# =============================================================================
# FUNCTION:  GetKeyboardInput
#
# DESCRIPTION:
#    This routine is used to check/get user keyboard input. This allows for
#    processing of keypad and arrow key input. This is used to impliment
#    basic input line editing and history/recall. These functions are not 
#    available with perl's $response = <STDIN> form of input. The down side
#    is this routine needs to be called periodically to check for user input.
#
#    Keypad and arrow key input is any key that returns a byte sequence that 
#    starts with the value 27. When detected, the bytes associated with it are
#    read and processed by &ProcessKeypadInput. The keypad sequence is passed
#    as a text string using the perl ord function to make it easier visualize.
#    Refer to &ProcessKeypadInput for a description of the sequences and the
#    actions performed.
#
#    The following shows the required working data %InWork and their required
#    initial start content. 
#
#    %InWork (
#       'inbuf'  => '',    Buffer used to accumulate keyboard input.
#       'iptr' => 0,       inbuf position. Used with console display.
#       'prompt' => '',    Optional: User input prompt string.
#       'pcol' => '',      Optional: Color for prompt string.       
#       ------             These keys are created at runtime.
#       'pflag' => 0,      Prompt user if undef or 0.
#       'inseq' => '',     Holder for keypad escape sequence. 
#       'history' => [],   History array. Used with up/down arrow keys.
#       'hptr' => 0        History position. Used with up/down arrow keys.
#    );
#
#    Keyboard input is accumulated in $InWork{'inbuf'} until the enter key
#    is detected. The inbuf data is returned to the caller. Following 
#    consumption, the caller must reset 'inbuf' and 'iptr' ('', 0) before 
#    the next input request. 
#
#    This subroutine uses the Term::ReadKey module to read keyboard input. Use
#    ReadMode('cbreak') in the main code to enable processing. This setting is
#    applied to the terminal session that was used to launched this program. 
#    Use ReadMode('normal') to restore default settings at program exit or
#    abnormal termination.
#
# CALLING SYNTAX:
#    $result = &GetKeyboardInput(\%InWork);
#
# ARGUMENTS:
#    $InWork      Pointer to input working hash.
#
# RETURNED VALUES:
#    0 = Input inprogress,  1 = Input available.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub GetKeyboardInput {
   my($InWork) = @_;

   # Output user prompt if necessary.
   if (exists($$InWork{'prompt'})) {
      $$InWork{'pflag'} = 0 unless (exists($$InWork{'pflag'}));
      unless ($$InWork{'pflag'} == 1) {
         &ColorMessage($$InWork{'prompt'}, $$InWork{'pcol'}, 'nocr');
         $$InWork{'pflag'} = 1;
      }
   }
   while (defined($char = ReadKey(-1))) {     # Get user input.
      &DisplayDebug("ProcessKeyboardInput: char: '" . ord($char) . "'");
      
      if (ord($char) == 27) {                       # Escape sequence.
         $$InWork{'inseq'} = ord($char);
         # To properly handle auto-repeat input, take only the number of bytes
         # needed from ReadKey. See escape sequences in &ProcessKeypadInput 
         # description. 3rd byte in range 65-72 indicates a 3 byte keypad 
         # sequence. Otherwise, get 1 more byte (126).
         while (defined($char = ReadKey(-1))) {     # Get remaining bytes.
            $$InWork{'inseq'} = join('', $$InWork{'inseq'}, ord($char));
            last if (ord($char) =~ m/^(65|66|67|68|69|70|72)/);
            last if (ord($char) =~ m/^126/);
         }
         &ProcessKeypadInput($InWork);
      }
      elsif (ord($char) == 127) {                   # Backspace key.
         $$InWork{'inseq'} = ord($char);
         &ProcessKeypadInput($InWork);
      }
      elsif (ord($char) == 10) {                    # Enter key.
         if ($$InWork{'inbuf'} ne '') {
            # Create history array if not present.
            unless (defined( $$InWork{'history'} )) {
               push (@{ $$InWork{'history'} }, $$InWork{'inbuf'});
            }
            else {
               # Don't save to history if same command.
               if ($$InWork{'inbuf'} ne ${ $$InWork{'history'} }[-1]) {
                  push (@{ $$InWork{'history'} }, $$InWork{'inbuf'});
               }
            }
            # Point 1 beyond the new last history entry for upArrow.
            $$InWork{'hptr'} = scalar @{ $$InWork{'history'} };
            # Add \n to inbuf and print on console.
            $$InWork{'inbuf'} = join('', $$InWork{'inbuf'}, $char);
            $$InWork{'iptr'}++;
            $$InWork{'pflag'} = 0;   # Enable prompt output next call.
            print $char;
            return 1;        # Return input available to caller.
         }
      }
      else {   # Insert character at iptr.
         my $pre = substr($$InWork{'inbuf'}, 0, $$InWork{'iptr'});
         my $post = substr($$InWork{'inbuf'}, $$InWork{'iptr'});
         $$InWork{'inbuf'} = join('', $pre, $char, $post);
         $$InWork{'iptr'}++;
         # Display new character and reposition cursor to insert point.
         print $char, $post, "\b" x length($post);
      }
   }
   return 0;
}

# =============================================================================
# MAIN PROGRAM
# =============================================================================

# ==========
# Setup for processing termination signals. Sets ReadMode back to 'Normal'.
foreach my $sig ('INT','QUIT','TERM','ABRT','STOP','KILL','HUP') {
   $SIG{$sig} = \&Ctrl_C;
}

# ==========
# Setup the input working hash. See &GetKeyboardInput description for details.
my %inWork = ('inbuf' => '','iptr' => 0, 'prompt' => "$ExecutableName -> ",
              'pcol' => 'BRIGHT_GREEN');
ReadMode('cbreak');                # Start readkey input processing.

my $runLoop = 1;
while ($runLoop == 1) {
   sleep .1;
   
   # Check for user keyboard input. Return 1 indicates input is available.
   if (&GetKeyboardInput(\%inWork) == 1) {   # Process new keypad input.
      chomp($inWork{'inbuf'});
      &ColorMessage($inWork{'inbuf'}, 'BRIGHT_GREEN', 'nocr');
      my $temp = join(',', @{ $inWork{'history'} });
      &ColorMessage("   history: $temp", 'BRIGHT_YELLOW', 'nocr');
      &ColorMessage("   hptr: $inWork{'hptr'}", 'BRIGHT_BLUE', '');
      $runLoop = 0 if ($inWork{'inbuf'} =~ m/^q/i);
      
      # Clear inbuf and set iptr to 0 before starting next input.
      $inWork{'inbuf'} = '';
      $inWork{'iptr'} = 0;
   }
}

ReadMode('normal');                # Restore normal terminal input.
exit(0);
