# ==============================================================================
# FILE: DrawPokerGuiLib.pm                                            5-31-2025
#
# SERVICES: Draw Poker Perl-Tk GUI
#
# DESCRIPTION:
#   This program provides support code for Perl-Tk DrawPokerGUI. The -x option
#   enables processing of arrow and less-than '<' greater-than '>' keys.
#
#   Up/Down arrows change the opponent. Left/Right arrows change the opponent 
#   image. The less-than key '<' sets the player and opponent bankrolls to $450
#   and $50 respectively. The greater-than key '>' sets the player and opponent
#   bankrolls to $50 and $450. The question mark key '?' displays the current
#   hand rank for player 2.
#
#   While not absolutely required, the Forks::Super perl module and code in 
#   GameTable is used to background preload the image files. This makes the 
#   game more responsive when image changes are performed. This module 'use
#   Forks::Super' and GameTable code can be commented out if necessary. The 
#   game will function normally without this code.
#
# PERL VERSION:  5.28.1
#
# ==============================================================================
# -----------------------------------------------------------------------------
# Package Declaration
# -----------------------------------------------------------------------------
package DrawPokerGuiLib;
require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
   GamePref
   GameTable
   StateMachine
   ActiveControl
   DealButton
   WagerButton
   CalllButton
   GetFelt
   DisplayCard
   CardClick
   Newdeck
   Shuffle
   TkGameDelay
   CheckLowStraight
   RankHand
   Winner
   ComputerBet
   AutoDiscard
   CheckBankroll
   DisplayGameMsg
   DisplayDebug
   ColorMessage
   PlaySound
   GetCardImage
   GenOpponent
   UnzipFile
   ArrowKey
);

# use Forks::Super;
use Time::HiRes qw(gettimeofday);
use Term::ANSIColor;
use Tk::waitVariableX;
use Tk::Compound;
use MIME::Base64;
use Data::Dumper;
use File::Spec::Functions qw(splitpath);
use IO::File;
use IO::Uncompress::Unzip qw($UnzipError);
use GD;
GD::Image->trueColor(1);  # Ensure GD truecolor processing is used.

# =============================================================================
# FUNCTION:  GamePref
#
# DESCRIPTION:
#    This routine is called at program startup to get the user's game play 
#    preferences. This includes card backs, player name, and game opponent.
#    Default values are used if no changes are made. This routine then calls
#    the GameTable routine to setup the game screen and begin game play.
#
#    An existing $Mw key binding to &ArrowKey, established in DrawPokerGui.pl,
#    is used for the opponent selection box. Code in &ArrowKey is active when
#    the in the 'gamepref' state.
#
#    During exit of this routine, the current preferences are written to a 
#    file in the current working directory. During subsequent program start,
#    the file contents are used to populate the preference screen widgets 
#    with their default values.
#
# CALLING SYNTAX:
#    $result = &GamePref($Mw, $Game, $Header, $Cards, $Footer, $Pref, 
#                        $MsgData);
#
# ARGUMENTS:
#    $Mw            Main window object pointer.
#    $Game          Pointer to game data hash.
#    $Header        Pointer to header section hash.
#    $Cards         Pointer to card section hash.
#    $Footer        Pointer to footer section hash.
#    $Pref          Pointer to preferences screen hash.
#    $MsgData       Pointer to game message data hash.
#
# RETURNED VALUES:
#    $Game{'State'} is set to 'restart' or 'exit'.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::WorkingDir, $main::opt_x, $main::0
# =============================================================================
sub GamePref {
   my($Mw, $Game, $Header, $Cards, $Footer, $Pref, $MsgData) = @_;
   my(@cardBacks, $handle);
   my($prevIndex, $prevName, $prevOppnt) = (0,"","");
   my($widgetBackground) = '#035C36';
   my($btnBackInactive) = '#AF800A';
   my($btnBackActive) = '#DFB03A';

   &DisplayDebug(1, "GamePref ...");
   $$Game{'State'} = 'gamepref';

   # Get previous game preferences, if any, to use as defaults. $main::0 holds
   # the program's path and name.
   my($file) = $main::0;
   $file =~ s/\.pl$/\.cfg/;
   $file =~ s/(\.cfg)$/_v$1/ if (defined($main::opt_x));
   if (-e $file) {
      if (open($handle, '<', $file)) {
         while(<$handle>) {
            if ($_ =~ m/Cardback:\s(\d+)/) {
               $prevIndex = $1;
            }
            elsif ($_ =~ m/Name: (.+)/) {
               $prevName = $1;
            }
            elsif ($_ =~ m/Opponent: (.+)/) {
               $prevOppnt = $1;
            }
         }
         close($handle);
      }
   }
   &DisplayDebug(1, "GamePref prevIndex: '$prevIndex'   prevName: '$prevName'" .
                          "   prevOppnt: '$prevOppnt'");

   $Mw->optionAdd('*font' => $$Pref{'p0'}{'font'});
 	$Mw->minsize($$Pref{'p0'}{'width'},$$Pref{'p0'}{'height'});
   $Mw->geometry(join('', $$Pref{'p0'}{'width'},'x', $$Pref{'p0'}{'height'},
      '+', $$Game{'Main'}{'StartX'},'+', $$Game{'Main'}{'StartY'}));
   
   # Display the background felt image.
   my($img) = $Mw->Photo(-file => $$Pref{'p0'}{'backImg'});
   $$Pref{'p0'}{'obj'} = $Mw->Label(-image => $img)->place(-relx => 0, -rely => 0,
      -width => $$Pref{'p0'}{'width'}, -height => $$Pref{'p0'}{'height'});

   # Display the pref window label widgets. 
   foreach my $label ('p1', 'p3', 'p4', 'p5', 'p14') {
      $$Pref{$label}{'text'} = "-$$MsgData{'01'}-" if ($label eq 'p1');
      &DisplayLabel($Mw, $Game, $Pref, $label);
   }

   # Instructions
   $$Pref{'p2'}{'obj'} = $Mw->Message(
      -text => $$MsgData{'19'}, -padx => 10, -pady => 10,
      -foreground => $$Pref{'p2'}{'color'},
      -borderwidth => .5,
      -relief => 'sunken',
      -background => $widgetBackground,
      -width => $$Pref{'p2'}{'width'},
      -font => $$Pref{'p2'}{'font'})->place(
         -relx => $$Pref{'p2'}{'relx'}, 
         -rely => $$Pref{'p2'}{'rely'});

   # --------------------------------------  
   # Cardback go lower button.
   $$Pref{'p6'}{'obj'} = $Mw->Button(-borderwidth => 3, -relief => 'raised',
         -text => "<", -font => $$Game{'Main'}{'FontB'},
         -background => $btnBackInactive, -activebackground => $btnBackActive,
         -command => [\&lowerCardback, $Mw, $Pref])->place(
         -relx => $$Pref{'p6'}{'relx'}, -rely => $$Pref{'p6'}{'rely'},
         -width => $$Pref{'p6'}{'btnW'}, -height => $$Pref{'p6'}{'btnH'});

   # Get available card backs and display.
   @{ $$Pref{'p7'}{'backs'} } = grep { -f } glob "$main::WorkingDir/cards/b*.png";
   $$Pref{'p7'}{'end'} = $#{ $$Pref{'p7'}{'backs'} };
   $$Pref{'p7'}{'idx'} = $prevIndex if ($prevIndex <= $$Pref{'p7'}{'end'});
   $$Pref{'p7'}{'card'} = 'back';                 # The card to display.
   if ($$Pref{'p7'}{'end'} >= 0) {   
      $$Pref{'p7'}{'idx'} = 0 unless (exists($$Pref{'p7'}{'idx'}));
      $$Pref{'p7'}{'file'} = ${ $$Pref{'p7'}{'backs'} }[$$Pref{'p7'}{'idx'}];      
      $$Pref{'p7'}{'obj'} = $Mw->Label(-image => '')->place(
         -relx => $$Pref{'p7'}{'relx'}, -rely => $$Pref{'p7'}{'rely'});
      &DisplayCard($Mw, $Game, $Pref, 'p7');      # Show the image
   }

   # Cardback go higher button.
   $$Pref{'p8'}{'obj'} = $Mw->Button(-borderwidth => 3, -relief => 'raised',
         -text => ">", -font => $$Game{'Main'}{'FontB'},
         -background => $btnBackInactive, -activebackground => $btnBackActive,
         -command => [\&higherCardback, $Mw, $Pref])->place(
            -relx => $$Pref{'p8'}{'relx'}, -rely => $$Pref{'p8'}{'rely'},
            -width => $$Pref{'p8'}{'btnW'}, -height => $$Pref{'p8'}{'btnH'});
   # --------------------------------------  

   # --------------------------------------  
   # Ok button.
   $$Pref{'p9'}{'obj'} = $Mw->Button(-borderwidth => 3, -relief => 'raised',
         -text => "OK", -font => $$Game{'Main'}{'FontB'},
         -background => $btnBackInactive, -activebackground => $btnBackActive,
         -command => [\&exitGamePref, $Mw, $Game, $Header, $Cards, $Footer,
                      $Pref])->place(
         -anchor => 'center', -relx => $$Pref{'p9'}{'relx'}, 
         -rely => $$Pref{'p9'}{'rely'}, -width => $$Pref{'p9'}{'btnW'},
         -height => $$Pref{'p9'}{'btnH'});
   $$Pref{'p9'}{'obj'}->focus();      

   # End button.
   $$Pref{'p10'}{'obj'} = $Mw->Button(-borderwidth => 3, -relief => 'raised',
         -text => "End", -font => $$Game{'Main'}{'FontB'},
         -background => $btnBackInactive, -activebackground => $btnBackActive,
         -command => \&endGame)->place(
         -anchor => 'center', -relx => $$Pref{'p10'}{'relx'}, 
         -rely => $$Pref{'p10'}{'rely'}, -width => $$Pref{'p10'}{'btnW'},
         -height => $$Pref{'p10'}{'btnH'});

   # Auto-play checkbox. 
   $$Pref{'p14'}{'obj'} = $Mw->Checkbutton(-variable => \$$Game{'AutoPlay'},
         -activebackground => $widgetBackground,
         -activeforeground => 'white',
         -background => $widgetBackground)->place(
         -anchor => 'center', -relx => $$Pref{'p14'}{'btnX'}, 
         -rely => $$Pref{'p14'}{'btnY'}, -width => $$Pref{'p14'}{'btnW'},
         -height => $$Pref{'p14'}{'btnH'});
   # --------------------------------------
   
   # Name input. Binding clears entry box of default value.
   $$Game{'Player1'}{'Name'} = $prevName if ($prevName ne '');
   $$Pref{'p11'}{'obj'} = $Mw->Entry(-textvariable => \$$Game{'Player1'}{'Name'},
      -font => $$Game{'Main'}{'FontB'}, -borderwidth => 1,
      -foreground => $$Pref{'p2'}{'color'},
      -background => $widgetBackground,      
      -justify => 'center')->place(
         -relx => $$Pref{'p11'}{'relx'}, -rely => $$Pref{'p11'}{'rely'},
         -width => $$Pref{'p11'}{'width'}, -height => $$Pref{'p11'}{'height'});
   $$Pref{'p11'}{'obj'}->bind('<FocusIn>', \&name);
   sub name { $$Pref{'p11'}{'obj'}->delete(0,'end'); }      
   
   # Opponent selection
   $$Pref{'p12'}{'obj'} = $Mw->Scrolled('Listbox', -scrollbars => 'oe',
      -selectmode => 'single', -font => $$Game{'Main'}{'FontB'},
      -foreground => $$Pref{'p2'}{'color'},
      -background => $widgetBackground,
      -borderwidth => 1)->place(
         -relx => $$Pref{'p12'}{'relx'}, -rely => $$Pref{'p12'}{'rely'},
         -width => $$Pref{'p12'}{'width'}, -height => $$Pref{'p12'}{'height'});
         
   # Insert opponent names into listbox and bind callback.
   my(@oppnts) = (sort keys(%{ $$Game{'Opponent'} }));
   $$Pref{'p12'}{'obj'}->insert('end', @oppnts);      
   $$Pref{'p12'}{'obj'}->bind('<Button-1>', \&oppnt);
   # In windows environment, add mousewheel scrolling to this widget.
   if ($^O =~ m/Win/) {
      $$Pref{'p12'}{'obj'}->bind('<Enter>' =>  sub {$$Pref{'p12'}{'obj'}->focus} );
      $$Pref{'p12'}{'obj'}->bind('<Leave>' =>  sub {$$Pref{'p9'}{'obj'}->focus});
   }

   # Set to previous opponent if in the selection list.
   my(@temp) = grep /$prevOppnt/, @oppnts;   
   if (scalar @temp == 1) {
      $$Game{'Player2'}{'Name'} = $prevOppnt;
      my($idx) = grep { $oppnts[$_] eq $prevOppnt } (0 .. $#oppnts);
      if ($idx >= 0) {
         $$Pref{'p12'}{'obj'}->see($idx);
         $$Pref{'p12'}{'obj'}->selectionClear(0, "end");
         $$Pref{'p12'}{'obj'}->selectionSet($idx);
      }
   }
   else {
      $$Game{'Player2'}{'Name'} = $oppnts[0];
   }
   $$Pref{'p12'}{'obj'}->bind('<Double-Button-1>' => \&OppntDoubleClick);

   # Current opponent thumbnail.
   if (exists($$Game{'Image'}{'Obj'})) {
      $$Pref{'p13'}{'obj'} = $Mw->Label(-image => '')->place(
         -relx => $$Pref{'p13'}{'relx'}, -rely => $$Pref{'p13'}{'rely'});
      $$Pref{'p13'}{'file'} = $$Game{'Opponent'}{ $$Game{'Player2'}{'Name'} }{0}; 
      &DisplayCard($Mw, $Game, $Pref, 'p13');      # Show the image
   }
   # -------------------------------------
   # p12 double-click callback to store opponent selection and start game. 
   sub OppntDoubleClick {
      &oppnt;
      &exitGamePref($Mw, $Game, $Header, $Cards, $Footer, $Pref);
   }
   # -------------------------------------
   # Callback to store opponent selection in $Game hash. 
   sub oppnt { $$Game{'Player2'}{'Name'} = 
         $$Pref{'p12'}{'obj'}->get($$Pref{'p12'}{'obj'}->curselection());
      $$Game{'Player2'}{'Name'} =~ s/^\s+|\s+$//g;
      if (exists($$Game{'Image'}{'Obj'})) {
         $$Pref{'p13'}{'file'} = $$Game{'Opponent'}{ $$Game{'Player2'}{'Name'} }{0}; 
         &DisplayCard($Mw, $Game, $Pref, 'p13');      # Show the image
      }
   }
   # -------------------------------------
   # Callback for cardback change lower.
   sub lowerCardback {
      my($Mw, $Pref) = @_;
      if ($$Pref{'p7'}{'idx'} > 0) {
         $$Pref{'p7'}{'idx'} = $$Pref{'p7'}{'idx'} -1;
         $$Pref{'p7'}{'file'} = ${ $$Pref{'p7'}{'backs'} }[$$Pref{'p7'}{'idx'}];
         &DisplayCard($Mw, $Game, $Pref, 'p7');        # Show the image
     }
   }
   # -------------------------------------
   # Callback for cardback change higher.
   sub higherCardback {
      my($Mw, $Pref) = @_;
      if ($$Pref{'p7'}{'idx'} < $$Pref{'p7'}{'end'}) {
         $$Pref{'p7'}{'idx'} = $$Pref{'p7'}{'idx'} +1;
         $$Pref{'p7'}{'file'} = ${ $$Pref{'p7'}{'backs'} }[$$Pref{'p7'}{'idx'}];
         &DisplayCard($Mw, $Game, $Pref, 'p7');        # Show the image
     }
   }
   # -------------------------------------
   # Callback for OK. Exit GamePref.
   sub exitGamePref {
      my($Mw, $Game, $Header, $Cards, $Footer, $Pref) = @_;
      $$Game{'Deck'}{'Back'} = $$Pref{'p7'}{'file'};       # Selected card back.
      $$Game{'Player1'}{'Name'} = ucfirst($$Game{'Player1'}{'Name'});
      $$Game{'Player1'}{'LoanCount'} = 0;
      $$Game{'Player1'}{'Bankroll'} = 100;
      $$Game{'Player1'}{'Msg'} = '';
      $$Game{'Player1'}{'LoanHigh'} = 0;
      $$Game{'Player2'}{'Name'} = ucfirst($$Game{'Player2'}{'Name'});
      $$Game{'Player2'}{'LoanCount'} = 0;
      $$Game{'Player2'}{'Bankroll'} = 100;
      $$Game{'Player2'}{'Msg'} = '';
      $$Game{'Player2'}{'LoanHigh'} = 0;
      $$Game{'GameCount'} = 0;
      
      # Opponent image check when -s is specified. If there is a 5th opponent image,
      # change 'Pot' label color to show bonus round availability.       
      if (exists($$Game{'Opponent'}{ $$Game{'Player2'}{'Name'} }{5}) and 
                 $$Game{'Opponent'}{ $$Game{'Player2'}{'Name'} }{'C'}{5} =~ m/bonus/i) {
         &PotLabelColor($Mw, $Game, $Header, 'Pref');
      }

      # Save the current selections. $main::0 holds the program's path and name.
      my($file) = $main::0;
      $file =~ s/\.pl$/\.cfg/;
      $file =~ s/(\.cfg)$/_v$1/ if (defined($main::opt_x));
      unlink ($file) if (-e $file);
      if (open($handle, '>', $file)) {
         print $handle "Cardback: $$Pref{'p7'}{'idx'} - $$Game{'Deck'}{'Back'}\n";
         print $handle "Name: $$Game{'Player1'}{'Name'}\n";
         print $handle "Opponent: $$Game{'Player2'}{'Name'}\n";
         close($handle);
         &DisplayDebug(2, "GamePref preferences saved.");
      }
      
      # Save game start time.
      $$Game{'StartTime'} = time;

      # Create a Toplevel, hide preferences screen, and call GameTable.
      my($tl) = $Mw->Toplevel;
      my($title) = $$MsgData{'02'};
      $title = " " x 16 . $title  if ($^O =~ m/linux/);
      $tl->title($title);
      &DisplayDebug(1, "GamePref new tl, $$Game{'State'}");
      $tl->bind('<KeyPress>' => [\&ArrowKey, $tl, $Game, $Pref, $Header]);
      $Mw->iconify;
      &GameTable($tl, $Game, $Header, $Cards, $Footer, $MsgData);
      if ($$Game{'State'} eq 'exit') {
         &DisplayDebug(1, "-----> GamePref program exit, $$Game{'State'}");
         exit(0);
      }
      $Mw->deiconify;
      $Mw-raise;
      # Remove previous game images. Tk has a small memory leak related to retaining
      # some image data even when the associated window is destroied.
      $tl->withdraw;
      my(@list) = $tl->imageNames;
      foreach my $image (@list) {
         $image->destroy;
      }
      
      # Game table image cleanup.
      if (exists($$Game{'Image'}{'Obj'})) {
         $$Game{'Image'}{'File'} = '';   # Clear for game restart.
         &DisplayDebug(2, "GamePref image destroy");
         $$Game{'Image'}{'Obj'}->destroy;
      }
      
      # Background 'felt'.
      &DisplayDebug(2, "GamePref felt destroy");
      $$Game{'Main'}{'BackObj'}->destroy; 
      
      $tl->destroy;
      undef($tl);

      $$Game{'State'} = 'gamepref';
      &DisplayDebug(1, "GamePref return 2, $$Game{'State'}");
      return;
   }
   # -------------------------------------
   # Callback for End button. Destroy main window and exit the program.
   sub endGame {
      &DisplayDebug(1, "-----> GamePref exit via endGame");
      exit(0);
   }
   
   &DisplayDebug(1, "-----> GamePref return 1, $$Game{'State'}");
   return;
}

# =============================================================================
# FUNCTION:  GameTable
#
# DESCRIPTION:
#    This routine sizes and displays the specified game table. The hash 
#    location $Cards{$Card} contains the card file, desired size, and object
#    pointer to a prevoiusly created button widget.
#
#    GD graphics library functions are used for image processing. The TK
#    configure function is used to update the associated button object.
#
# CALLING SYNTAX:
#    $result = &GameTable($Tl, $Game, $Header, $Cards, $Footer, $MsgData);
#
# ARGUMENTS:
#    $Tl            Toplevel object pointer.
#    $Game          Pointer to game data hash.
#    $Header        Pointer to header section hash.
#    $Cards         Pointer to card section hash.
#    $Footer        Pointer to footer section hash.
#    $MsgData       Pointer to game message hash.
#
# RETURNED VALUES:
#    $Game{'State'} is set to 'restart' or 'exit'.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::opt_s
# =============================================================================
sub GameTable {
   my($Tl, $Game, $Header, $Cards, $Footer, $MsgData) = @_;
   my($disabledBack) = '#96680A';      # Disabled button color.
   my($inactiveBack) = '#AF800A';      # Inactive button color.
   my($activeBack) = '#DFB03A';        # Active button color.

   &DisplayDebug(1, "GameTable ...");

   # Set window size for game play. The font size is already set.
   $Tl->optionAdd('*font' => $$Game{'Main'}{'Font'});
 	$Tl->minsize($$Game{'Main'}{'Width'},$$Game{'Main'}{'Height'});
   $Tl->geometry(join('', $$Game{'Main'}{'Width'},'x', $$Game{'Main'}{'Height'},
      '+', $$Game{'Main'}{'StartX'},'+', $$Game{'Main'}{'StartY'}));
   
   # Set game table background.
   &DisplayDebug(2, "GameTable background felt");
   my($img) = $Tl->Photo(-file => $$Game{'Main'}{'BackImg'});
   $$Game{'Main'}{'BackObj'} = $Tl->Label(-image => $img)->place(-relx => 0,
      -rely => 0, -width => $$Game{'Main'}{'Width'},
      -height => $$Game{'Main'}{'Height'});

   # Display top header widgets.
   &DisplayDebug(2, "GameTable create header widgets");
   foreach my $head (sort keys(%$Header)) {
      &DisplayLabel($Tl, $Game, $Header, $head);
   }

   # Display card backs and initialize the -command callback.
   &DisplayDebug(2, "GameTable create card widgets");
   foreach my $card (sort keys(%$Cards)) {   
      $$Cards{$card}{'file'} = $$Game{'Deck'}{'Back'};
      $$Cards{$card}{'cw'} = $$Game{'Main'}{'CardW'};
      $$Cards{$card}{'ch'} = $$Game{'Main'}{'CardH'};
      $$Cards{$card}{'card'} = 'back';

      # Only display players cards in horizontal orientation. If we figure
      # out how to synchronize Tk on-screen card sound effects, the button
      # bind should be uncommented.                  
      if ($card lt '06' or defined($main::opt_s)) {
         $$Cards{$card}{'obj'} = $Tl->Button(-image => '',
            -command => [\&CardClick, $Tl, $Game, $Cards, $card])->place(
               -relx => $$Cards{$card}{'relx'},
               -rely => $$Cards{$card}{'rely'});
         # $$Cards{$card}{'obj'}->bind('<Button>' => \&PlaySound);
         &DisplayCard($Tl, $Game, $Cards, $card);
      }
   }

   # Display bottom footer buttons. Footer index 0 is the game message widget.
   # It needs to appear 'transparent' like the header labels. 
   &DisplayDebug(2, "GameTable create footer widgets");
   foreach my $foot (sort keys(%$Footer)) {
      $$Footer{$foot}{'obj'} = $Tl->Button(
         -text => $$Footer{$foot}{'text'},
         -background => $inactiveBack, 
         -activebackground => $activeBack,
         -disabledforeground => $disabledBack,
         -font => $$Game{'Main'}{'FontB'})->place(
            -relx => $$Footer{$foot}{'relx'},
            -rely => $$Footer{$foot}{'rely'},
            -width => $$Footer{$foot}{'btnW'},
            -height => $$Footer{$foot}{'btnH'});
   }
  
   # Game table image.
   if (exists($$Game{'Image'}{'Obj'})) {
      &DisplayDebug(2, "GameTable create gametable image");
      $$Game{'Image'}{'Obj'} = $Tl->Label(
         -image => '', 
         -borderwidth => 0,
         -width => $$Game{'Image'}{'Width'},
         -height => $$Game{'Image'}{'Height'})->place(
            -relx => $$Game{'Image'}{'Relx'},
            -rely => $$Game{'Image'}{'Rely'});
      &DisplayImage($Tl, $Game);
      my($name) = $$Game{'Player2'}{'Name'};
      if (exists($$Game{'Opponent'}{$name}{'C'})) {
         foreach my $i (keys(%{ $$Game{'Opponent'}{$name}{'C'} })) {
            $$Game{'Player2'}{'Wear'}{$i} = $$Game{'Opponent'}{$name}{'C'}{$i};
         }
      }
      
      # Background encode the remaining images and store in working hash. Needs debug.
      #unless ($^O =~ m/Win/) {
         #my($pid);
         #foreach my $i (sort keys(%{ $$Game{'Opponent'}{$name} })) {
            #next if ($i !~ m/^\d$/ or exists ($$Game{'OppImage'}{$name}{$i}));
            #&DisplayDebug(2, "GameTable fork encode $i: $$Game{'Opponent'}{$name}{$i}");
            #$pid = fork { os_priority => 1 };
            #if (!defined($pid)) {
               #print "--> Failed to create child process. $! \n";
            #}
            #elsif ($pid == 0) {   # In child.
               #print "--> Enter child for $i \n";
               #my($result) = &EncodeImage($Game, $$Game{'Opponent'}{$name}{$i}, $i);
               ## Copy encoded image to parent hash.
               ## print STDERR $$Game{'OppImage'}{$name}{$i};
               #print "--> Exit child for $i \n";
               #exit(0);
            #}
         #}
      #}
   }
   
   # Add the callback code references to the buttons. Can't put these references
   # in the data hashes due to the use of dclone.
   &DisplayDebug(2, "GameTable create widget callbacks");
   foreach my $foot (sort keys(%$Footer)) {
      if ($$Footer{$foot}{'text'} =~ m/^\$(\d+)/) {
         my($amt) = $1;
         $$Footer{$foot}{'obj'}->configure(-command => [\&WagerButton, $Game,
                                           $amt]);
      }
      elsif ($$Footer{$foot}{'text'} =~ m/^Deal/) {
         $$Footer{$foot}{'obj'}->configure(-command => [\&DealButton, $Tl, 
                                           $Game, $Cards, $MsgData]);
      }
      elsif ($$Footer{$foot}{'text'} =~ m/^Discard/) {
         $$Footer{$foot}{'obj'}->configure(-command => [\&DiscardButton, $Tl,
                                           $Game, $Cards, $MsgData]);
      }
      elsif ($$Footer{$foot}{'text'} =~ m/^Call/) {
         $$Footer{$foot}{'obj'}->configure(-command => [\&CallButton, $Game]);
      }
      elsif ($$Footer{$foot}{'text'} =~ m/^Drop/) {
         $$Footer{$foot}{'obj'}->configure(-command => [\&DropButton, $Game]);
      }
   }

   # Show message about player 2, quick card shuffle, and begin gameplay.
   &DisplayGameMsg($$MsgData{'06'}, 'Player2', $Game);
   $$Game{'Deck'}{'dPos'} = &Shuffle(\@{ $$Game{'Deck'}{'Cards'} }, int(rand(8))+2);
   $$Game{'FirstBet'} = 'Player1';      # Player1 bets first with new opponent.
   &StateMachine($Tl, $Game, $Cards, $Header, $Footer, 'table', $MsgData);
   &DisplayDebug(2, "-----> GameTable return, $$Game{'State'}");
   return;
}

# =============================================================================
# FUNCTION:  StateMachine
#
# DESCRIPTION:
#    This routine enables/disables the various button widgets based on the
#    current game state. Button widgets inappropriate for the game state are
#    disabled. Game states are:
#
#       gamepref - Game preferences screen.
#       table    - Table initialized with card backs.
#       deal     - Cards dealt to to players.
#       1stWager - 1st wager input.
#       1stCall  - 1st Call.
#       discard1 - Discard player 1 cards.
#       discard2 - Discard player 2 cards.
#       2ndWager - 2nd wager input.
#       2ndCall  - 2nd Call.
#       winner   - Declare winner and award pot.
#       checkEnd - Check for player GameEnd amount.
#       next     - Prep for next round.
#       end      - A player is out of money.
#       restart  - Restart program.
#       exit     - Terminate program.
#
# CALLING SYNTAX:
#    $result = &StateMachine($Tl, $Game, $Cards, $Header, $Footer, $State, $MsgData);
# ARGUMENTS:
#    $Tl            Toplevel object pointer.
#    $Game          Pointer to game data hash.
#    $Cards         Pointer to card section hash.
#    $Header        Pointer to header section hash.
#    $Footer        Pointer to footer section hash.
#    $State         Optionally sets the game state if specified.
#    $MsgData       Pointer to game message hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::WorkingDir, $main::opt_s
# =============================================================================
sub StateMachine {
   my($Tl, $Game, $Cards, $Header, $Footer, $State, $MsgData) = @_;
   
   # These hashes are used to set the footer button states. The hash corresponding
   # to the current game state is passed to &ActiveControl.
   my(%table) = ('0' => 's', '$5' => 'd', '$10' => 'd', '$15' => 'd', '$20' => 'd',
                 '$25' => 'd', 'Deal' => 'f', 'Discard' => 'd', 'Call' => 'd',
                 'Drop' => 'e');
   my(%deal)  = ('0' => 's', '$5' => 'd', '$10' => 'd', '$15' => 'd', '$20' => 'd',
                 '$25' => 'd', 'Deal' => 'd', 'Discard' => 'd', 'Call' => 'd',
                 'Drop' => 'd');
   my(%bet)   = ('0' => 's', '$5' => 'w', '$10' => 'w', '$15' => 'w', '$20' => 'w',
                 '$25' => 'w', 'Deal' => 'd', 'Discard' => 'd', 'Call' => 'f',
                 'Drop' => 'e');
   my(%call1) = ('0' => 's', '$5' => 'r', '$10' => 'r', '$15' => 'r', '$20' => 'r',
                 '$25' => 'r', 'Deal' => 'd', 'Discard' => 'd', 'Call' => 'd',
                 'Drop' => 'd');
   my(%dcrd1) = ('0' => 's', '$5' => 'x', '$10' => 'x', '$15' => 'x', '$20' => 'x',
                 '$25' => 'x', 'Deal' => 'd', 'Discard' => 'f', 'Call' => 'd',
                 'Drop' => 'd');
   my(%dcrd2) = ('0' => 's', '$5' => 'x', '$10' => 'x', '$15' => 'x', '$20' => 'x',
                 '$25' => 'x', 'Deal' => 'd', 'Discard' => 'd', 'Call' => 'd',
                 'Drop' => 'd');
   my(%call2) = ('0' => 's', '$5' => 'r', '$10' => 'r', '$15' => 'r', '$20' => 'r',
                 '$25' => 'r', 'Deal' => 'd', 'Discard' => 'd', 'Call' => 'd',
                 'Drop' => 'e');
   my(%win)   = ('0' => 's', '$5' => 'r', '$10' => 'r', '$15' => 'r', '$20' => 'r',
                 '$25' => 'r', 'Deal' => 'd', 'Discard' => 'd', 'Call' => 'd',
                 'Drop' => 'd');
   my(%exit) = ('0' => 's', '$5' => 'd', '$10' => 'd', '$15' => 'd', '$20' => 'd',
                 '$25' => 'd', 'Deal' => 'd', 'Discard' => 'd', 'Call' => 'd',
                 'Drop' => 'f');
                 
   &DisplayDebug(1, "StateMachine ...");   
   
   $$Game{'State'} = $State if ($State ne '');
   while ($$Game{'State'} ne 'exit' and $$Game{'State'} ne 'restart') {
      &TkGameDelay($Tl, 200);                           # Game cycle delay.
      &DisplayDebug(1, "StateMachine ...   GameState: $$Game{'State'} ");

      # -----------------------------
      if ($$Game{'State'} eq 'table') {             # 'table' state.
         &ActiveControl($Tl, \%table, $Game, $Cards, $Footer, $MsgData);
         delete $$Game{'button'} if (exists($$Game{'button'}));
         my($cTime) = time + 1;
         while (not exists($$Game{'button'})) {
            &TkGameDelay($Tl, 200);    # Wait for Deal or Drop button.
            # Auto-play if enabled.
            if ($$Game{'AutoPlay'} == 1 and $cTime < time) {
               &DisplayDebug(1, "--> Auto-play deal button.");   
               &DealButton($Tl, $Game, $Cards, $MsgData);
            }
         }
         $$Game{'State'} = 'deal' if ($$Game{'button'} eq 'deal');
         $$Game{'State'} = 'end' if ($$Game{'button'} eq 'drop');
      }
      # -----------------------------
      elsif ($$Game{'State'} eq 'deal') {           # 'deal' state.
         &ActiveControl($Tl, \%deal, $Game, $Cards, $Footer, $MsgData);
         $$Game{'State'} = '1stWager';
      }
      # -----------------------------
      elsif ($$Game{'State'} eq '1stWager') {       # '1stWager' state.
         &ActiveControl($Tl, \%bet, $Game, $Cards, $Footer, $MsgData);
         &WagerCycle($Tl, $Game, $MsgData);   # WagerCycle sets next state.
         
      }
      # -----------------------------
      elsif ($$Game{'State'} eq '1stCall') {        # '1stCall' state.
         &ActiveControl($Tl, \%call1, $Game, $Cards, $Footer, $MsgData);
         # Suppress discard prompt if running in auto-play mode.
         if ($$Game{'AutoPlay'} == 0) {
            &DisplayGameMsg($$MsgData{'15'}, 'Player1', $Game);
         }
         # Firstbet player discards first.
         if ($$Game{'FirstBet'} eq 'Player1') {
            $$Game{'State'} = 'discard1';
         }
         else {
            $$Game{'State'} = 'discard2';
         }
      }
      # -----------------------------
      elsif ($$Game{'State'} eq 'discard1') {        # 'discard1' state.
         &ActiveControl($Tl, \%dcrd1, $Game, $Cards, $Footer, $MsgData);
         delete $$Game{'button'} if (exists($$Game{'button'}));
         my($cTime) = time + 1;
         while ($$Game{'button'} ne 'discard') {
            &TkGameDelay($Tl, 200);    # Wait for discard button press.
            # Auto-play if enabled.
            if ($$Game{'AutoPlay'} == 1 and $cTime < time) {
               &DisplayDebug(1, "--> Auto-play discard button.");   
               &ComputerDiscard($Tl, $Game, 'Player1', $Cards, $MsgData, $Score);
               &DiscardButton($Tl, $Game, $Cards, $MsgData); # Click discard button.
            }
         }
         if ($$Game{'FirstBet'} eq 'Player1') {
            $$Game{'State'} = 'discard2';
         }
         else {
            $$Game{'State'} = '2ndWager';
         }
      }
      # -----------------------------
      elsif ($$Game{'State'} eq 'discard2') {        # 'discard2' state.
         &ActiveControl($Tl, \%dcrd2, $Game, $Cards, $Footer, $MsgData);
         &ComputerDiscard($Tl, $Game, 'Player2', $Cards, $MsgData, $Score);
         if ($$Game{'FirstBet'} eq 'Player1') {
            $$Game{'State'} = '2ndWager';
         }
         else {
            $$Game{'State'} = 'discard1';
         }
      }
      # -----------------------------
      elsif ($$Game{'State'} eq '2ndWager') {       # '2ndWager' state.
         &ActiveControl($Tl, \%bet, $Game, $Cards, $Footer, $MsgData);
         &WagerCycle($Tl, $Game, $MsgData);   # WagerCycle sets next state.     
      }
      # -----------------------------
      elsif ($$Game{'State'} eq '2ndCall') {        # '2ndCall' state.
         # Show player 2 cards. These are %Card entries 06..10.
         # If horizontal orientation, display card backs first to 
         # help differentiate this is player 2's hand.
         &DisplayGameMsg($$Game{'Player2'}{'HandRank'}, 'Player2', $Game, 1);
         &TkGameDelay($Tl, 100);
         my($i) = 0;
         if (defined($main::opt_s)) {
            foreach my $card ('06','07','08','09','10') {
               my($crd) = $$Game{'Player2'}{'Hand'}[$i++];
               $$Cards{$card}{'file'} = join('/', $main::WorkingDir, 'cards',
                              "${crd}.png");
               &DisplayCard($Tl, $Game, $Cards, $card);      
               &TkGameDelay($Tl, 150);
            }
         }
         else {
            foreach my $card ('01','02','03','04','05') {
               $$Cards{$card}{'file'} = $$Game{'Deck'}{'Back'};
               &DisplayCard($Tl, $Game, $Cards, $card);      
            }
            &TkGameDelay($Tl, 50);
            foreach my $card ('01','02','03','04','05') {
               my($crd) = $$Game{'Player2'}{'Hand'}[$i++];
               $$Cards{$card}{'file'} = join('/', $main::WorkingDir, 'cards',
                              "${crd}.png");
               &DisplayCard($Tl, $Game, $Cards, $card);      
               &TkGameDelay($Tl, 200);
            }
         } 
         $$Game{'State'} = 'winner';
      }
      # -----------------------------
      elsif ($$Game{'State'} eq 'winner') {          # 'winner' state.
         &ActiveControl($Tl, \%win, $Game, $Cards, $Footer, $MsgData);
         &DisplayDebug(2, "Winner state Pot: $$Game{'Pot'}");
         my($winner) = &Winner($Game);          # Determine the winner.
         if ($winner eq 'Player1') {
            unshift(@{ $$Game{'WinHistory'} }, 1);
            &DisplayGameMsg($$MsgData{'12'}, 'Player1', $Game);
            $$Game{'Player1'}{'Bankroll'} += $$Game{'Pot'};
            $$Game{'Pot'} = 0;
            # Payback outstanding loan, if any.
            my($chk) = &CheckBankroll($Tl, $Game, 'Player1', 0);
         }
         elsif ($winner eq 'Player2') {
            unshift(@{ $$Game{'WinHistory'} }, 2);
            &DisplayGameMsg($$MsgData{'12'}, 'Player2', $Game);
            $$Game{'Player2'}{'Bankroll'} += $$Game{'Pot'};
            $$Game{'Pot'} = 0;
            # P2 won bonus round?
            if (exists($$Game{'Image'}{'Bonus'}) and 
               $$Game{'Player2'}{'Bankroll'} >= 100) { 
               &DisplayGameMsg($$MsgData{'22'}, 'Player1', $Game);
               delete $$Game{'Image'}{'Bonus'};
               $$Game{'GameEnd'} -= 100;      # Reset game limit.
               $$Game{'State'} = 'end';
               &TkGameDelay($Tl, 2000); 
            }
            else {   
               # Payback outstanding loan, if any.
               my($chk) = &CheckBankroll($Tl, $Game, 'Player2', 0); 
            }
         }
         else {
            # Draw 
            &DisplayGameMsg($$MsgData{'07'}, '', $Game);
         }
         
         # Move drawn cards to end of deck and shuffle.
         my(@used) = splice(@{ $$Game{'Deck'}{'Cards'} }, 0, 
                            $$Game{'Deck'}{'dPos'});
         push(@{ $$Game{'Deck'}{'Cards'} }, @used);
         
         # Shuffle cards and set a random start point in first half
         # of the deck. Effectively a deck cut.
         &Shuffle(\@{ $$Game{'Deck'}{'Cards'} }, '');
         $$Game{'Deck'}{'dPos'} = int(rand(30));

         $$Game{'State'} = 'checkEnd' if ($$Game{'State'} ne 'end');
      }
      # -----------------------------
      elsif ($$Game{'State'} eq 'checkEnd') {         # 'checkEnd' state.
         &DisplayDebug(2, "checkEnd P1 bankroll: $$Game{'Player1'}{'Bankroll'}");   
         &DisplayDebug(2, "checkEnd P2 bankroll: $$Game{'Player2'}{'Bankroll'}");   
         &DisplayDebug(2, "checkEnd GameEnd: $$Game{'GameEnd'}");   
         # Go to 'end' state if one of the players has won the GameEnd amount. 
         if ($$Game{'Player1'}{'Bankroll'} >= $$Game{'GameEnd'}) {
            if (exists($$Game{'Image'}{'Obj'})) {
               $$Game{'Player2'}{'LoanCount'} += 1;   # Set to display image 4 
               # P1 won bonus round?
               if (exists($$Game{'Image'}{'Bonus'})) {
                  &DisplayGameMsg($$MsgData{'14'}, 'Player1', $Game);
                  delete $$Game{'Image'}{'Bonus'};
                  $$Game{'GameEnd'} -= 100;      # Reset game limit.
                  $$Game{'State'} = 'end';       # Game over.
               }
               else { 
                  # If 5th image and clothing 'bonus' is available, setup for
                  # bonus round.
                  if (exists($$Game{'Opponent'}{ $$Game{'Player2'}{'Name'} }
                       { $$Game{'Player2'}{'LoanCount'} +1 }) and 
                       $$Game{'Opponent'}{ $$Game{'Player2'}{'Name'} }{'C'}
                       { $$Game{'Player2'}{'LoanCount'} +1 } =~ m/bonus/i) {
                     # Image 5 available. Player 1 already won bonus round amount?
                     if ($$Game{'Player1'}{'Bankroll'} >= ($$Game{'GameEnd'}+100)) {
                        &DisplayGameMsg($$MsgData{'18'}, 'Player1', $Game);
                        &DisplayImage($Tl, $Game);            # Display image 4.
                        &TkGameDelay($Tl, 3000);              # Wait a bit
                        $$Game{'Player2'}{'LoanCount'} += 1;  # Set to display image 5.
                        $$Game{'State'} = 'end';              # Game over.
                     }
                     else {
                        # Compute amount needed to win bonus round.
                        $$Game{'Player1'}{'Value'} = 100;
                        if ($$Game{'Player2'}{'Bankroll'} < 0) {
                           $$Game{'Player1'}{'Value'} += $$Game{'Player2'}{'Bankroll'};
                        }
                        &DisplayGameMsg($$MsgData{'13'}, 'Player1', $Game);
                        $$Game{'Image'}{'Bonus'} = 1;
                        $$Game{'State'} = 'next';
                     }
                  }
                  else {
                     $$Game{'State'} = 'end';                 # Game over.
                  }
               }
               &DisplayImage($Tl, $Game);
            }
            else {
               &DisplayGameMsg($$MsgData{'21'}, 'Player2', $Game, 2);
               $$Game{'State'} = 'end';
            }
         }
         elsif ($$Game{'Player2'}{'Bankroll'} >= $$Game{'GameEnd'}) {
            if (exists($$Game{'Image'}{'Obj'})) {
               &DisplayGameMsg($$MsgData{'20'}, 'Player1', $Game, 2);
            }
            $$Game{'State'} = 'end';
         }
         else {
            &DisplayDebug(2, "Neither player >= $$Game{'GameEnd'}");   
            &DisplayImage($Tl, $Game) if (exists($$Game{'Image'}{'Obj'}));
            $$Game{'State'} = 'next' unless ($$Game{'State'} eq 'end');
         }
         &TkGameDelay($Tl, 2000) if ($$Game{'State'} eq 'end'); 
      }
      # -----------------------------
      elsif ($$Game{'State'} eq 'next') {           # 'next' state.
         # Alternate first bet between players.
         if ($$Game{'FirstBet'} eq 'Player1') {
            $$Game{'FirstBet'} = 'Player2';
         }
         else {
            $$Game{'FirstBet'} = 'Player1';
         }
         # Wait for deal or drop button. Deal will set cardbacks from
         # this state.
         &ActiveControl($Tl, \%table, $Game, $Cards, $Footer, $MsgData);
         delete $$Game{'button'} if (exists($$Game{'button'}));
         my($cTime) = time + 2;
         # Wait for Deal or Drop.
         while ($$Game{'button'} ne 'deal' and $$Game{'button'} ne 'drop') {    
            &TkGameDelay($Tl, 200); 
            if ($$Game{'AutoPlay'} == 1) {      # Auto-play if enabled.
               if ($cTime < time) { 
                  &DisplayDebug(1, "--> Auto-play deal button.");   
                  &DealButton($Tl, $Game, $Cards, $MsgData);
               }
            }
         }
         if ($$Game{'button'} eq 'deal') {
            if (exists($$Game{'Image'}{'Bonus'})) {
               # Add $100 to game limit and player2 bankroll.
               if ($$Game{'Image'}{'Bonus'} == 1) {
                  $$Game{'GameEnd'} += 100;      # Set bonus round game limit.
                  $$Game{'Player2'}{'Bankroll'} += 100;
                  $$Game{'Image'}{'Bonus'} = 2;  # Only one bonus round, != 1.
               }
            }
            $$Game{'State'} = 'deal';
         }
         $$Game{'State'} = 'end' if ($$Game{'button'} eq 'drop');         
      }
      # -----------------------------
      elsif ($$Game{'State'} eq 'end') {            # 'end' state.
         &PotLabelColor($Tl, $Game, $Header, 'End');
         if ($$Game{'AutoPlay'} == 1) {
            my($msg) = "Auto-Play hands: $$Game{'GameCount'}";
            my($time) = time - $$Game{'StartTime'};
            $msg = join('   ', $msg, "Duration: $time sec.");
            my($stat) = join('/', $$Game{'Player1'}{'LoanHigh'}, 
                                  $$Game{'Player2'}{'LoanHigh'});
            $msg = join('   ', $msg, "P1/P2 loan high: $stat");
            &DisplayGameMsg($msg, '', $Game);
         }
         else {
            if ($$Game{'Player1'}{'Bankroll'} > $$Game{'Player2'}{'Bankroll'}) {
               $$Game{'Player1'}{'Bankroll'} += $$Game{'Pot'};
               $$Game{'Pot'} = 0;
               &DisplayGameMsg($$MsgData{'03'}, 'Player1', $Game);
            }
            else {
               $$Game{'Player2'}{'Bankroll'} += $$Game{'Pot'};
               $$Game{'Pot'} = 0;
               &DisplayGameMsg($$MsgData{'04'}, 'Player1', $Game);
            }
         }
         # Clear player messages.
         &DisplayGameMsg('', 'Player1', $Game, 1);
         &DisplayGameMsg('', 'Player2', $Game, 1);
         delete $$Game{'Image'}{'Bonus'} if (exists($$Game{'Image'}{'Bonus'}));

         # Clear cards from game table.
         foreach my $card (sort keys(%$Cards)) {   
            if ($card lt '06' or defined($main::opt_s)) {
               &DisplayDebug(2, "StateMachine card destroy: $card");
               $$Cards{$card}{'obj'}->destroy;
            }
         }
         # Change buttons Deal and Drop text to Pref and Exit.
         foreach my $btn (sort keys(%$Footer)) {
            if ($$Footer{$btn}{'text'} eq 'Drop') {
               $$Footer{$btn}{'obj'}->configure(-text => 'Exit',
                                                -command => \&Exit);
            }
            elsif ($$Footer{$btn}{'text'} eq 'Deal') {
               $$Footer{$btn}{'obj'}->configure(-text => 'Pref',
                                                -command => \&Pref);
            }
         } 
         # Get player input; 'Pref' or 'Exit' 
         &ActiveControl($Tl, \%table, $Game, $Cards, $Footer, $MsgData);
         # &ActiveControl($Tl, \%exit, $Game, $Cards, $Footer, $MsgData);
         while ($$Game{'State'} eq 'end') {
            &TkGameDelay($Tl, 200);    # Wait a bit.
         }
         
         sub Pref { $$Game{'State'} = 'restart'; return; }
         sub Exit { $$Game{'State'} = 'exit'; return; }
      }
   }
   &DisplayDebug(2, "-----> StateMachine return: $$Game{'State'}");   
   return;
}

# =============================================================================
# FUNCTION:  ActiveControl
#
# DESCRIPTION:
#    This routine enables/disables the footer button widgets as specified
#    by the referenced hash. Each widget to be affected is named in the 
#    input hash. The key values are one of the following.
#
#       'e' = Enable widget; set it to 'normal'
#       'f' = Implies 'e' and also sets focus to this widget.
#       'w' = Implies 'e' and sets wager binding to keys 1-5.
#       'd' = Disable widget.
#       'x' = Implies 'd' and sets discard binding to keys 1-5.
#       'r' = Implies 'd' and resets binding to keys 1-5.
#       's' = No-op this key position.
#
#    Example:
#       'Deal' => 's','Call' =>' e', 'Drop' => 'd',  ...
#
# CALLING SYNTAX:
#    $result = &ActiveControl($Tl, $Setting, $Game, $Cards, $Footer, $MsgData);
#
# ARGUMENTS:
#    $Tl            Toplevel object pointer.
#    $Setting       Pointer to setting hash.
#    $Game          Pointer to game data hash.
#    $Cards         Pointer to card section hash.
#    $Footer        Pointer to footer section hash.
#    $MsgData       Pointer to game message hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ActiveControl {
   my($Tl, $Setting, $Game, $Cards, $Footer, $MsgData) = @_;
   
   # This hash maps the %Footer index to the %Cards index. Used with 'x'.
   my(%btnKey) = ('1'=>'01', '2'=>'02', '3'=>'03', '4'=>'04', '5'=>'05');

   &DisplayDebug(1, "ActiveControl ...");   
   
   foreach my $key (sort keys(%$Setting)) {
      next if ($$Setting{$key} =~ m/s/i);
      foreach my $btn (sort keys(%$Footer)) {
         if ($$Footer{$btn}{'text'} eq $key) {
            if ($$Setting{$key} =~ m/e|f|w/i) {
               &DisplayDebug(2, "ActiveControl '$$Setting{$key}' $key: 'normal'");
               $$Footer{$btn}{'obj'}->configure(-state => 'normal');
               if ($$Setting{$key} =~ m/f/i) {
                  $$Footer{$btn}{'obj'}->focus();
               }
               elsif ($$Setting{$key} =~ m/w/i) {
                  my($amt) = $$Footer{$btn}{'obj'}->cget('-text');
                  $amt =~ s/^\$//;
                  my($str) = "<KeyRelease-" . $amt/5 . '>';
                  &DisplayDebug(2, "ActiveControl key bind: $str $amt");
                  $Tl->bind("$str" => sub{ WagerButton($Game, $amt) });
               }              
            }
            elsif ($$Setting{$key} =~ m/d|r|x/i) {
               &DisplayDebug(2, "ActiveControl $key: 'disabled'");
               $$Footer{$btn}{'obj'}->configure(-state => 'disabled');
               if ($$Setting{$key} =~ m/r/i) {
                  my($str) = "<KeyRelease-" . $btn . '>';
                  $Tl->bind("$str" => sub{ NoKeyOp()} );
               }
               elsif ($$Setting{$key} =~ m/x/i) {
                  my($card) = $btnKey{$btn};
                  my($str) = "<KeyRelease-" . $btn . '>';
                  &DisplayDebug(2, "ActiveControl key bind: $str $card");
                  $Tl->bind("$str" => sub{CardClick($Tl, $Game, $Cards, $card)});
               }
            }
            last;
         }
      }
   }
   return 0;

   # This subroutine is used to 'disable' key bindings 1-5. Couldn't come
   # up with a simpler way by just manipulating the bind configuration.   
   sub NoKeyOp { return 0; }
}

# =============================================================================
# FUNCTION:  DealButton
#
# DESCRIPTION:
#    This routine is called when the 'Deal' button is clicked. The deck is
#    shuffled and five cards are delt to each player.
#
# CALLING SYNTAX:
#    $result = &DealButton($Tl, $Game, $Cards, $MsgData);
#
# ARGUMENTS:
#    $Tl            Toplevel object pointer.
#    $Game          Pointer to game data hash.
#    $Cards         Pointer to card section hash.
#    $MsgData       Pointer to game message data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::WorkingDir, $main::opt_s
# =============================================================================
sub DealButton {
   my($Tl, $Game, $Cards, $MsgData) = @_;
   my($cards);
   
   &DisplayDebug(1, "DealButton ...");
   $$Game{'button'} = 'deal';
   
   # Clear message windows.   
   &DisplayGameMsg('', '', $Game);           # Clear main previous message.
   &DisplayGameMsg('', 'Player1', $Game, 1); # Clear Player1 previous handrank 
   &DisplayGameMsg('', 'Player2', $Game, 1); # Clear Player2 previous handrank
   
   # Save the current LoanCount for each player. It is used by ItemMsg during
   # winner processing for keep/won-back messaging after each round of play.
   $$Game{'Player1'}{'PreLoanCount'} = $$Game{'Player1'}{'LoanCount'};
   $$Game{'Player2'}{'PreLoanCount'} = $$Game{'Player2'}{'LoanCount'};

   # Display game count if running Auto-Play mode.
   $$Game{'GameCount'} += 1;
   if ($$Game{'AutoPlay'} == 1) {
      my($msg) = "Auto-Play hand: $$Game{'GameCount'}";
      &DisplayGameMsg($msg, '', $Game);
      &TkGameDelay($Tl, 400);
   }
   
   # If state is 'next', display the card backs.
   if ($$Game{'State'} eq 'next') {
      foreach my $card (sort keys(%$Cards)) {   
         $$Cards{$card}{'file'} = $$Game{'Deck'}{'Back'};
         # Only display players cards in horizontal orientation.                  
         if ($card lt '06' or defined($main::opt_s)) {
            &DisplayCard($Tl, $Game, $Cards, $card);
         }
      }
      &TkGameDelay($Tl, 100);
   }

   # Ante $5
   my($amount) = 5;
   my($chk) = &CheckBankroll($Tl, $Game, 'Player1', $amount);
   $$Game{'Player1'}{'Bankroll'} -= $amount;
   $$Game{'Pot'} += $amount;
   my($chk) = &CheckBankroll($Tl, $Game, 'Player2', $amount);
   $$Game{'Player2'}{'Bankroll'} -= $amount;
   $$Game{'Pot'} += $amount;

   # Clear bets and cards from previous round.       
   $$Game{'Player1'}{'OpponentBet'} = 0;
   @{ $$Game{'Player1'}{'Hand'} } = ();
   $$Game{'Player2'}{'OpponentBet'} = 0;
   @{ $$Game{'Player2'}{'Hand'} } = ();
           
   # Deal 5 cards to each player. FirstBet player gets first card.
   &DisplayDebug(2, "DealButton deck start: $$Game{'Deck'}{'dPos'}");
   foreach (1 .. 10) { 
      if ($_ % 2 == 1) {             # Alternate cards to players.
         if ($$Game{'FirstBet'} eq 'Player1') {
            push(@{ $$Game{'Player1'}{'Hand'} },
              $$Game{'Deck'}{'Cards'}[ $$Game{'Deck'}{'dPos'}++ ]);
         }
         else {
            push(@{ $$Game{'Player2'}{'Hand'} },
              $$Game{'Deck'}{'Cards'}[ $$Game{'Deck'}{'dPos'}++ ]);
         }
      }
      else {
         if ($$Game{'FirstBet'} eq 'Player1') {
            push(@{ $$Game{'Player2'}{'Hand'} },
              $$Game{'Deck'}{'Cards'}[ $$Game{'Deck'}{'dPos'}++ ]);
         }
         else {
            push(@{ $$Game{'Player1'}{'Hand'} },
              $$Game{'Deck'}{'Cards'}[ $$Game{'Deck'}{'dPos'}++ ]);
         }
      }
   }
   
   # Sort each players cards. For a low straight (A,2,3,4,5), the ace is moved
   # to the low card position for proper win determination when both players
   # have a straight. 
   @{ $$Game{'Player1'}{'Hand'} } = sort(@{ $$Game{'Player1'}{'Hand'} });
   &CheckLowStraight($Game, 'Player1');
   @{ $$Game{'Player2'}{'Hand'} } = sort(@{ $$Game{'Player2'}{'Hand'} });
   &CheckLowStraight($Game, 'Player2');
   
   # Determine hand rank for each player. &RankHand checks for hand duplication.
   # Add hand to Game{'AllHands'} after check.
   my($rank1) = &RankHand($Game, 'Player1', 5);
   $cards = join('', @{ $$Game{'Player1'}{'Hand'} });
   push( @{ $$Game{'AllHands'} }, "$cards:1");      # Initial cards player 1.
   my($rank2) = &RankHand($Game, 'Player2', 5);
   $cards = join('', @{ $$Game{'Player2'}{'Hand'} });
   push( @{ $$Game{'AllHands'} }, "$cards:2");      # Initial cards player 2.
   &DisplayDebug(3, "AllHands --> @{ $$Game{'AllHands'} }");

   # The following code grants a small advantage to player 1. If player 2 has
   # won three consecutive rounds, the better hand of the initially dealt cards
   # is given to player 1.
   my(@lastTenWins) = @{ $$Game{'WinHistory'} }[0..9];
   &DisplayDebug(2, "WinHistory --> @lastTenWins");
   if ($lastTenWins[0] == 2 and $lastTenWins[1] == 2 and $lastTenWins[2] == 2) {
      if ((&Winner($Game)) eq 'Player2') {  # Swap cards if Player 2 hand is better.
         my(@temp) = @{ $$Game{'Player1'}{'Hand'} };
         @{ $$Game{'Player1'}{'Hand'} } = @{ $$Game{'Player2'}{'Hand'} };
         @{ $$Game{'Player2'}{'Hand'} } = @temp;
         $$Game{'Player1'}{'HandRank'} = $rank2;
         $$Game{'Player2'}{'HandRank'} = $rank1;
         &DisplayDebug(2, "Deal Button: Card swap performed.");
      }
   }

   # Show player 1 their cards. These are %Card entries 01..05
   my($i) = 0;
   foreach my $card ('01','02','03','04','05') {
      my($crd) = $$Game{'Player1'}{'Hand'}[$i++];
      $$Cards{$card}{'file'} = join('/', $main::WorkingDir, 'cards', "${crd}.png");
      &DisplayCard($Tl, $Game, $Cards, $card);      
      &TkGameDelay($Tl, 150);
   }

   # Show hand rank to player 1
   &DisplayGameMsg($$Game{'Player1'}{'HandRank'}, 'Player1', $Game, 1); 
   
   &DisplayDebug(2, "$$Game{'Player1'}{'Name'} " .
      "cards: @{ $$Game{'Player1'}{'Hand'} }   " .
      "rank: $$Game{'Player1'}{'HandRank'}");
   
   &DisplayDebug(2, "$$Game{'Player2'}{'Name'} " .
      "cards: @{ $$Game{'Player2'}{'Hand'} }   " .
      "rank: $$Game{'Player2'}{'HandRank'}");
	return 0;
}

# =============================================================================
# FUNCTION:  WagerButton
#
# DESCRIPTION:
#    This routine is called when one of the wager buttons is activated. The
#    corresponding amount is passed in.
#
# CALLING SYNTAX:
#    $result = &WagerButton($Game, $Wager);
#
# ARGUMENTS:
#    $Game          Pointer to game data hash.
#    $Wager         Wager amount.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub WagerButton {
   my($Game, $Wager) = @_;

   # Ignore wager input if not in these game states. Primarily, this is for
   # keyboard shortcut keys 1-5 since these bindings are always active.
   if ($$Game{'State'} eq '1stWager' or $$Game{'State'} eq '2ndWager') {
      &DisplayDebug(1, "WagerButton. Wager: $Wager");
      $$Game{'button'} = 'wager';
      $$Game{'Player1'}{'bet'} = $Wager;
   }
	return;
}

# =============================================================================
# FUNCTION:  CallButton
#
# DESCRIPTION:
#    This routine is called when the 'Call' button is clicked.
#
# CALLING SYNTAX:
#    $result = &CallButton($Game);
#
# ARGUMENTS:
#    $Game          Pointer to game data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub CallButton {
   my($Game) = @_;
   
   &DisplayDebug(1, "Call button.");
   $$Game{'button'} = 'call';
   $$Game{'Player1'}{'bet'} = 0;
	return;
}

# =============================================================================
# FUNCTION:  DiscardButton
#
# DESCRIPTION:
#    This routine is called when the 'Discard' button is clicked. It exchanges
#    and displays the player1 specified cards.
#
# CALLING SYNTAX:
#    $result = &DiscardButton($Tl, $Game, $Cards, $MsgData);
#
# ARGUMENTS:
#    $Tl            Toplevel object pointer.
#    $Game          Pointer to game data hash.
#    $Cards         Pointer to card section hash.
#    $MsgData       Pointer to game message data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::WorkingDir
# =============================================================================
sub DiscardButton {
   my($Tl, $Game, $Cards, $MsgData) = @_;
   
   &DisplayDebug(1, "Discard button.");
   $$Game{'button'} = 'discard';
   &DisplayGameMsg('', '', $Game);           # Clear main previous message.

   # Exchange player1 cards. The &CardClick code adds a 'discard' key to the
   # %Cards hash for each card to be exchanged.
   &DisplayDebug(3, "P1 hand  pre-discard: @{ $$Game{'Player1'}{'Hand'} }");
   $$Game{'Player2'}{'OpponentDraw'} = 0;
   foreach my $card ('01','02','03','04','05') {
      if (exists($$Cards{$card}{'discard'})) {
         my($i) = int($card)-1;
         &DisplayDebug(2, "pre-discard: $card   $$Game{'Player1'}{'Hand'}[$i]   " . 
            "dPos: $$Game{'Deck'}{'dPos'}");
         $$Game{'Player1'}{'Hand'}[$i] = 
                        $$Game{'Deck'}{'Cards'}[ $$Game{'Deck'}{'dPos'}++ ];
         &DisplayDebug(2, "pst-discard: $card   $$Game{'Player1'}{'Hand'}[$i]   " . 
            "dPos: $$Game{'Deck'}{'dPos'}");
         delete($$Cards{$card}{'discard'});
         $$Game{'Player2'}{'OpponentDraw'}++;
      }
   }
   @{ $$Game{'Player1'}{'Hand'} } = sort(@{ $$Game{'Player1'}{'Hand'} });
   &CheckLowStraight($Game, 'Player1');
   &DisplayDebug(3, "P1 hand post-discard: @{ $$Game{'Player1'}{'Hand'} }");

   # Determine new hand score and rank for player 1.
   my($rank1) = &RankHand($Game, 'Player1', $$Game{'Player2'}{'OpponentDraw'});
   my($cards) = join('', @{ $$Game{'Player1'}{'Hand'} });
   push( @{ $$Game{'AllHands'} }, "$cards:3");      # Replaced cards player 1.

   &DisplayDebug(2, "$$Game{'Player1'}{'Name'} " .
      "cards: @{ $$Game{'Player1'}{'Hand'} }   " .
      "rank: $$Game{'Player1'}{'HandRank'}");

   # Show player1 cards.
   my($i) = 0;
   foreach my $card ('01','02','03','04','05') {
      my($crd) = $$Game{'Player1'}{'Hand'}[$i++];
      $$Cards{$card}{'file'} = join('/', $main::WorkingDir, 'cards', "${crd}.png");
      &DisplayCard($Tl, $Game, $Cards, $card);      
      &TkGameDelay($Tl, 75);
   }
   # Show hand rank to player 1
   &DisplayGameMsg($$Game{'Player1'}{'HandRank'}, 'Player1', $Game, 1); 
	return;
}

# =============================================================================
# FUNCTION:  DropButton
#
# DESCRIPTION:
#    This routine is called when the 'Drop' button is clicked.
#
# CALLING SYNTAX:
#    $result = &DropButton($Game);
#
# ARGUMENTS:
#    $Game          Pointer to game data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub DropButton {
   my($Game) = @_;
   &DisplayDebug(1, "Drop button.");
   $$Game{'button'} = 'drop';
   $$Game{'Player1'}{'bet'} = -1;
	return;
}

# =============================================================================
# FUNCTION:  WagerCycle
#
# DESCRIPTION:
#    This routine gets each player's bet. The pot and player bankrolls are
#    updated. A player's bankroll is loaned the $BankLoan amount up to
#    $LoanLimit times for a negative balance.
#
#    FirstBet specifies which player bets first.
#
# CALLING SYNTAX:
#    &WagerCycle($Tl, \%Game, \%MsgData)
#
# ARGUMENTS:
#    $Tl            Toplevel object pointer.
#    $Game          Pointer to game hash.
#    $MsgData       Pointer to message hash.
#
# RETURNED VALUES:
#    None.          %game{'State'} updated.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub WagerCycle {
   my($Tl, $Game, $MsgData) = @_;
   my(@players, $bet, $idx, $see, $worth);
   $$Game{'RaiseCount'} = 0;
   $$Game{'Player1'}{'OpponentBet'} = 0;
   $$Game{'Player2'}{'OpponentBet'} = 0;

   &DisplayDebug(1, "WagerCycle ...   first bet Player: $$Game{'FirstBet'}");

   if ($$Game{'FirstBet'} eq 'Player1') {
      @players = ('Player1', 'Player2');
   }
   else {
      @players = ('Player2', 'Player1');
   }

   while ($$Game{'RaiseCount'} < $$Game{'RaiseLimit'}) {
      foreach my $player (@players) {
         $see = 0;
         # Get the players bet. -1 = drop, 0 = call.
         if ($player eq 'Player1') {
            # Prompt for wager if first actual bet.
            if ($$Game{$player}{'OpponentBet'} == 0 and $$Game{'AutoPlay'} == 0) {
               &DisplayGameMsg($$MsgData{'05'}, 'Player1', $Game);
            }
            delete $$Game{$player}{'bet'} if (exists($$Game{$player}{'bet'}));
            # Wait here until player clicks a button.
            while (not exists($$Game{$player}{'bet'})) {
               &TkGameDelay($Tl, 200);
               # Auto-play if enabled.
               if ($$Game{'AutoPlay'} == 1) {
                  &DisplayDebug(1, "--> Auto-play wager button.");   
                  $$Game{$player}{'bet'} = &ComputerBet($Game, $player);
               }
            }
            $bet = $$Game{$player}{'bet'};  # Bet set by button code.
         }
         else {
            $bet = &ComputerBet($Game, $player);
         }
         
         # Player requested drop.
         if ($bet < 0) {    # player drop
            &DisplayGameMsg($$MsgData{'11'}, $player, $Game);
            &TkGameDelay($Tl, 1500);   # Delay for drop message to be seen.
            $$Game{$player}{'HandRank'} = '';
            $$Game{'State'} = 'winner';
            last;
         }
         # Player requested call or we're at raise limit.
         if ($bet == 0 or ($$Game{'RaiseCount'}+1 >= $$Game{'RaiseLimit'})
                           and $player ne $$Game{'FirstBet'}) {
            # Check and update players bankroll for 'see' amount.
            my($chk) = &CheckBankroll($Tl, $Game, $player, 
                                      $$Game{$player}{'OpponentBet'});
            &DisplayGameMsg($$MsgData{'10'}, $player, $Game);
            $$Game{$player}{'Bankroll'} -= $$Game{$player}{'OpponentBet'};
            $$Game{'Pot'} += $$Game{$player}{'OpponentBet'};
            
            # If a player is the first to bet, if their first bet is call,
            # the other player has the opportunity to bet.
            next if ($bet == 0 and $$Game{$player}{'OpponentBet'} == 0);
            # Delay for message read by player.
            if ($player eq 'Player1') {
               if ($$Game{'AutoPlay'} == 1) {
                  &TkGameDelay($Tl, 1500);
               }
               else {
                  &TkGameDelay($Tl, 500);
               }
            }
            else {
               &TkGameDelay($Tl, 1500);
            }
            last 
         }
         else {
            if ($$Game{$player}{'OpponentBet'} == 0) {  # Opponent bet?
               $idx = '08';        # no, bet message
            }
            else {
               $idx = '09';        # yes, see & raise message
               $see = $$Game{$player}{'OpponentBet'};  
            }
            $$Game{'Player2'}{'OpponentBet'} = $bet if ($player eq 'Player1'); 
            $$Game{'Player1'}{'OpponentBet'} = $bet if ($player eq 'Player2'); 

            # Check players bankroll. &Bankroll handles update of player
            # loan/payback. Returned value is the total bet amount which
            # includes the $see amount in a raise condition.
            $bet = &CheckBankroll($Tl, $Game, $player, ($bet + $see));
            
            # Process the &Bankroll returned value.
            &DisplayGameMsg('', $player, $Game); # Clear previous message.
            &TkGameDelay($Tl, 100);
            $$Game{$player}{'Value'} = ($bet - $see); # Bet amount for message.
            &DisplayGameMsg($$MsgData{$idx}, $player, $Game);
            $$Game{$player}{'Bankroll'} -= $bet;  # Full $bet + $see deducted
            $$Game{'Pot'} += $bet;                # and added to the pot.
            if ($$Game{'AutoPlay'} == 1) {
               &TkGameDelay($Tl, 1500);  # Delay for message read.
            }
         }
      }
      last if ($bet <= 0);       # player terminated WagerCycle
      $$Game{'RaiseCount'}++;
      &DisplayDebug(1, "WagerCycle RaiseCount $$Game{'RaiseCount'} of " .
                       "$$Game{'RaiseLimit'}");
   }
   $$Game{'State'} = '1stCall' if ($$Game{'State'} == '1stWager');
   $$Game{'State'} = '2ndCall' if ($$Game{'State'} == '2ndWager');
   return;
}

# =============================================================================
# FUNCTION:  DisplayLabel
#
# DESCRIPTION:
#    This routine is called to create and display each of the label widgets on
#    the game table. Each of these widgets is made to appear 'transparent' with
#    respect to the game table 'green felt' image. This is accomplished by setting
#    the widget's background to the game table image. Since the image varies in
#    color and shading, the label's position must be taken into account. 
#
# CALLING SYNTAX:
#    $result = &DisplayLabel($Tl, $Game, $HashRef, $Index);
#
# ARGUMENTS:
#    $Tl            Toplevel object pointer.
#    $Game          Pointer to game data hash.
#    $HashRef       Pointer to hash section; e.g. %Header.
#    $Index         Hash entry to process.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub DisplayLabel {
   my($Tl, $Game, $HashRef, $Index) = @_;
   my($text, $felt, $comp, $srcX, $srcY);

   &DisplayDebug(1, "DisplayLabel ...   Index: $Index");

   # Get the needed game table felt for the position and size. With the use of
   # label -anchor center, adjust computation for center of widget by subtracting
   # half of width and height. 
   if ($Index =~ m/^p\d+$/) {   # game preference window?
      $srcX = int($$HashRef{'p0'}{'width'} * $$HashRef{$Index}{'relx'}) - 
         int($$HashRef{$Index}{'width'}/2);    # -anchor center
      $srcY = int($$HashRef{'p0'}{'height'} * $$HashRef{$Index}{'rely'}) -
         int($$HashRef{$Index}{'height'}/2);   # -anchor center
      &GetFelt($Tl, $Game, \$felt, $srcX, $srcY, $$HashRef{$Index}{'width'}, 
         $$HashRef{$Index}{'height'}, $$HashRef{'p0'}{'backImg'}, '');
   }
   else {
      $srcX = int($$Game{'Main'}{'Width'} * $$HashRef{$Index}{'relx'}) -
         int($$HashRef{$Index}{'width'}/2);    # -anchor center
      $srcY = int($$Game{'Main'}{'Height'} * $$HashRef{$Index}{'rely'}) -
         int($$HashRef{$Index}{'height'}/2);   # -anchor center
      &GetFelt($Tl, $Game, \$felt, $srcX, $srcY, $$HashRef{$Index}{'width'}, 
         $$HashRef{$Index}{'height'}, $$Game{'Main'}{'BackImg'}, '');
   }
   # Display the label widget. Labels of -textvariable type point to the label's
   # %Game display variable. In this way, when the variable changes, the onscreen
   # value will reflect the change. If text is formatted '-*-', it is the actual
   # text string. Otherwise, it is one or more hash key names.
   &DisplayDebug(2, "DisplayLabel text: '$$HashRef{$Index}{'text'}'");
   if ($$HashRef{$Index}{'text'} =~ m/^-(.+)-$/ or $$HashRef{$Index}{'text'} eq '') {
      $text = $1;
      &DisplayDebug(2, "DisplayLabel label text: '$text'");
      $$HashRef{$Index}{'obj'} = $Tl->Label(
         -text => $text, -font => $$HashRef{$Index}{'font'}, 
         -foreground => $$HashRef{$Index}{'color'})->place(
            -anchor => 'center',
            -relx => $$HashRef{$Index}{'relx'}, 
            -rely => $$HashRef{$Index}{'rely'}, 
            -height => $$HashRef{$Index}{'height'}, 
            -width => $$HashRef{$Index}{'width'}); 
   }
   # Frame is a decorative box around the top game table widgets.
   elsif ($$HashRef{$Index}{'text'} eq 'frame') {
      $$HashRef{$Index}{'obj'} = $Tl->Frame(
         -borderwidth => $$HashRef{$Index}{'borderWidth'},
         -relief => 'sunken',
         -background => $$HashRef{$Index}{'color'})->place(
            -anchor => 'center',
            -relx => $$HashRef{$Index}{'relx'}, 
            -rely => $$HashRef{$Index}{'rely'}, 
            -height => $$HashRef{$Index}{'height'}, 
            -width => $$HashRef{$Index}{'width'});
      $$HashRef{$Index}{'obj'}->Label(-image => $felt)->pack(-fill => 'both');
      return;      
   }
   else {
      # Variables have one or two hash keys to address.
      my(@key) = split(',', $$HashRef{$Index}{'text'});
      &DisplayDebug(2, "DisplayLabel key: @key");
      if (scalar @key == 1) {
         $$HashRef{$Index}{'obj'} = $Tl->Label(
            -textvariable => \$$Game{$key[0]},
            -font => $$HashRef{$Index}{'font'}, 
            -foreground => $$HashRef{$Index}{'color'})->place(
               -anchor => 'center',
               -relx => $$HashRef{$Index}{'relx'}, 
               -rely => $$HashRef{$Index}{'rely'}, 
               -height => $$HashRef{$Index}{'height'}, 
               -width => $$HashRef{$Index}{'width'}); 
      }
      elsif (scalar @key == 2) {
         $$HashRef{$Index}{'obj'} = $Tl->Label(
            -textvariable => \$$Game{$key[0]}{$key[1]},
            -font => $$HashRef{$Index}{'font'}, 
            -foreground => $$HashRef{$Index}{'color'})->place(
               -anchor => 'center',
               -relx => $$HashRef{$Index}{'relx'}, 
               -rely => $$HashRef{$Index}{'rely'}, 
               -height => $$HashRef{$Index}{'height'}, 
               -width => $$HashRef{$Index}{'width'}); 
      }
   }
         
   # Finally, use Tk::Compound to add the background to the object.
   $comp = $$HashRef{$Index}{'obj'}->Compound;
   $comp->Image(-image => $felt);
   if (not defined($main::opt_d) or $main::opt_d < 4) {
      $$HashRef{$Index}{'obj'}->configure(-image => $comp, -compound => 'center');
   }
   undef $_ for $felt, $comp;
   return 0;
}

# =============================================================================
# FUNCTION:  GetFelt
#
# DESCRIPTION:
#    This routine is called to select the specified portion of the background
#    felt image. The specified image box size is returned as a Tk image. If
#    the optional $Data is set to 'data', the image is returned non-encoded
#    for subsequent image merge processing by the caller.
#
# CALLING SYNTAX:
#    $result = &GetFelt($Tl, $Game, $Felt, $SrcX, $SrcY, $Width, $Height,
#                       $FeltFile, 'data');
# ARGUMENTS:
#    $Tl            Toplevel object pointer.
#    $Game          Pointer to game data hash.
#    $Felt          Pointer to data storage variable.
#    $SrcX          Upper left X coordinate.
#    $SrcY          Upper left Y coordinate.
#    $Width         Width to select.
#    $Height        Height to select.
#    $FeltFile      Background felt image path/file.
#    $Data          Return non-encoded image data.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub GetFelt {
   my($Tl, $Game, $Felt, $SrcX, $SrcY, $Width, $Height, $FeltFile, $Data) = @_;
   my($src, $cpysize, $encode, $imgName);

   &DisplayDebug(1, "GetFelt ...");
   &DisplayDebug(2, "GetFeltSrcX: $SrcX   SrcY: $SrcY   Width: $Width   " .
      "Height: $Height   FeltFile: $FeltFile   Data: '$Data'");

   # Open the game table image in GD.
   $src = GD::Image->newFromJpeg($FeltFile);
   
   # Create an empty image with the specified dimensions.
   $cpysize = new GD::Image($Width, $Height);
   
   # Copy from source file at the specified position.
   # gd.copy(source, dstX, dstY, srcX, srcY, width, height)
   $cpysize->copy($src, 0, 0, $SrcX, $SrcY, $Width, $Height);
   if ($Data eq 'data') {
      $$Felt = $cpysize;
      undef $_ for $src, $cpysize;
      return 0;
   }
   
   # Encode the image output of the $cpysize.
   $encode = encode_base64($cpysize->png());
   
   # Create and return the Tk::Photo object.
   $imgName = "Img${SrcX}${SrcY}" . time;
   $$Felt = $Tl->Photo($imgName, -data => $encode, -format => 'png');
   undef $_ for $src, $cpysize, $encode;
   &DisplayDebug(2, "GetFelt return");
   return 0;
}   

# =============================================================================
# FUNCTION:  DisplayCard
#
# DESCRIPTION:
#    This routine sizes and displays the specified card. The hash location
#    $Cards{$Card} contains the card file, desired size, and object pointer
#    to a prevoiusly created button widget.
#
#    GD graphics library functions are used for image processing. The TK
#    configure function is used to update the associated button object.
#
#    If $Game{'Deck'}{'File'} has a value, then it identifies a single file
#    name containing all card images. GD is used to extract the card image.
#    Otherwise, the individual card images are used.
#
# CALLING SYNTAX:
#    $result = &DisplayCard($Tl, $Game, $Cards, $Card);
#
# ARGUMENTS:
#    $Tl            Toplevel object pointer.
#    $Game          Pointer to game data hash.
#    $Cards         Pointer to working card hash.
#    $Card          Working card hash index.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub DisplayCard {
   my($Tl, $Game, $Cards, $Card) = @_;
   my($src, $resize, $encode, $image);

   &DisplayDebug(1, "DisplayCard ...");
   &DisplayDebug(2, "DisplayCard Card: $Card   file: $$Cards{$Card}{'file'}");

   # Open the card image in GD.
   if ($$Cards{$Card}{'file'} =~ m/\.jpg|jpeg$/) {
      $src = GD::Image->newFromJpeg($$Cards{$Card}{'file'});
   }
   else {
      $src = GD::Image->newFromPng($$Cards{$Card}{'file'});
   }
   
   # Create an empty image with the desired dimensions.
   $resize = new GD::Image($$Cards{$Card}{'cw'}, $$Cards{$Card}{'ch'});
   
   # Copy everything from $src and resize it into $resize.
   # gd.copyResized(source, dstX, dstY, srcX, srcY, dstW, dstH, srcW, srcH)
   $resize->copyResized($src, 0, 0, 0, 0, $$Cards{$Card}{'cw'}, 
                        $$Cards{$Card}{'ch'}, $src->width, $src->height);
                        
   # Encode the image output of the $resize.
   $encode = encode_base64($resize->png());
   
   # Create the Tk::Photo object.
   $image = $Tl->Photo("Card${Card}", -data => $encode, -format => 'png');
   
   # Apply the image. The opponent icon gets a more decorative border.
   if ($Card eq 'p13') {
      $$Cards{$Card}{'obj'}->configure(-image => $image, 
         -background => $$Cards{$Card}{'color'}, 
         -borderwidth => 1, -relief => 'flat');
   }
   else {
      $$Cards{$Card}{'obj'}->configure(-image => $image, 
         -background => '#181818', -borderwidth => 0, -relief => 'flat');
   }

   # Free up GD working memory.                                    
   undef $_ for $src, $resize, $encode, $image;
   return 0;
}

# =============================================================================
# FUNCTION:  DisplayImage
#
# DESCRIPTION:
#    This routine displays the specified image in the specified frame object. 
#     This 
#    object ready output is saved in a working hash. This facilitates faster 
#    image redisplay for subsequent requests.  
#
#    GD graphics library functions are used for image processing. The TK
#    configure function is used to update the frame object.
#
# CALLING SYNTAX:
#    $result = &DisplayImage($Tl, $Game);
#
# ARGUMENTS:
#    $Tl            Toplevel object pointer.
#    $Game          Pointer to game hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub DisplayImage {
   my($Tl, $Game) = @_;
   my($file, $encode, $image, $name);
   my($iNum) = $$Game{'Player2'}{'LoanCount'};

   &DisplayDebug(1, "DisplayImage ...   iNum: $iNum");
   
   # Get the file to process.
   $file = $$Game{'Opponent'}{ $$Game{'Player2'}{'Name'} }{$iNum};
   &DisplayDebug(2, "DisplayImage player 2 LoanCount: $iNum   file: $file" .
                    "   current image: $$Game{'Image'}{'File'}");
   return 0 if ($$Game{'Image'}{'File'} eq $file); # Done if image already active.
   unless (-e $file) {
      &DisplayDebug(1, "DisplayImage file not found: $file.");
      return 1;
   }
   $$Game{'Image'}{'File'} = $file;   # Set as active image.

   # Use previous image encode data if available.
   if (exists ($$Game{'OppImage'}{ $$Game{'Player2'}{'Name'} }{$iNum})) {
      $encode = $$Game{'OppImage'}{ $$Game{'Player2'}{'Name'} }{$iNum};
      &DisplayDebug(2, "DisplayImage, using previous encode data.");
   }
   else {                            
      &DisplayDebug(2, "DisplayImage, encoding image ...");
      return 1 if(&EncodeImage($Game, $file, $iNum));
      $encode = $$Game{'OppImage'}{ $$Game{'Player2'}{'Name'} }{$iNum};
   }
   
   # Create the Tk::Photo object.
   $name = join('-', 'Image', $iNum, time);
   $image = $Tl->Photo($name, -data => $encode, -format => 'png');

   # Apply the image.
   $$Game{'Image'}{'Obj'}->configure(-image => $image);

   # Free up GD working memory.                                    
   undef $_ for $encode, $image;
   return 0;
}

# =============================================================================
# FUNCTION:  EncodeImage
#
# DESCRIPTION:
#    This routine sizes and encodes the specified image and stores the TK Photo
#    ready output in the $Game working hash. The hash facilitates faster image 
#    reuse by the DisplayImage routine. It also allows for background image 
#    encoding.
#
#    The image is resized for the game screen resolution, merged with background
#    image (green felt), and then encoded for use by TK Photo. 
#
# CALLING SYNTAX:
#    $result = &EncodeImage($Game, $File, $Inum);
#
# ARGUMENTS:
#    $Game          Pointer to game hash.
#    $File          Image file name to encode.
#    $Inum          Image series number to encode.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub EncodeImage {
   my($Game, $File, $Inum) = @_;
   my($src, $resize, $merge, $encode, $iWidth, $iHeight, $mergeX, $mergeY);
   my($rWidth, $rHeight);
   
   # Open the image in GD.
   if ($File =~ m/\.png$/i) {
      $src = GD::Image->newFromPng($File);
   }
   elsif ($File =~ m/\.(jpg|jpeg)$/i) {
      $src = GD::Image->newFromJpeg($File);
   }
   else {
      &DisplayDebug(2, "EncodeImage unhandled image type: $File");
      return 1;
   }
   &DisplayDebug(2, "EncodeImage Inum: $Inum   File: '$File'");
      
   # Determine the resize and merge width and height.
   ($iWidth, $iHeight) = $src->getBounds();
   &DisplayDebug(2, "EncodeImage src demensions: $iWidth x $iHeight");
   if ($iWidth > $iHeight) {
      $rWidth = $$Game{'Image'}{'Width'};
      $rHeight = int($iHeight * ($rWidth / $iWidth));
      $mergeX = 0;
      $mergeY = int(($$Game{'Image'}{'Height'} - $rHeight) / 2);
   }
   else {
      $rHeight = $$Game{'Image'}{'Height'};
      $rWidth = int( $iWidth * ($rHeight / $iHeight));
      $mergeX = int(($$Game{'Image'}{'Width'} - $rWidth) / 2);
      $mergeY = 0;
   }
   &DisplayDebug(2, "EncodeImage resize demensions: $rWidth x $rHeight");
   &DisplayDebug(2, "EncodeImage merge coordinates: $mergeX , $mergeY");
      
   # Create an empty image with the desired dimensions.
   $resize = new GD::Image($rWidth, $rHeight);
   
   # Copy everything from $src and resize it into $resize.
   # gd.copyResized(source, dstX, dstY, srcX, srcY, dstW, dstH, srcW, srcH)
   $resize->copyResized($src, 0, 0, 0, 0, $rWidth, $rHeight, $iWidth, $iHeight);
      
   # Merge resized image with prepared game table felt image.
   $merge = new GD::Image($$Game{'Image'}{'Width'}, $$Game{'Image'}{'Height'});
   $merge->copy($$Game{'Image'}{'Felt'}, 0, 0, 0, 0, $$Game{'Image'}{'Width'},
                       $$Game{'Image'}{'Height'});
   $merge->copyMerge($resize, $mergeX, $mergeY, 0, 0, $rWidth, $rHeight, 100);
   
   # Encode the image output of the $merge. Save for future use.
   $encode = encode_base64($merge->png());
   $$Game{'OppImage'}{ $$Game{'Player2'}{'Name'} }{$Inum} = $encode;
   &DisplayDebug(2, "EncodeImage, saved image encoding data.");
   undef $_ for $src, $resize, $merge, $encode, $image;
   return 0;
}

# =============================================================================
# FUNCTION:  CardClick
#
# DESCRIPTION:
#    This routine is called when a card is clicked to indicate discard. The
#    button image of the card is changed to include an X overlay. Clicking
#    the card again restores the original image. The card click is processed
#    only if the game state is 'discard'.
#
#    GD graphics library functions are used for image processing. The TK
#    configure function is used to update the associated button object.
#
# CALLING SYNTAX:
#    $result = &CardClick($Tl, $Game, $Cards, $Card);
#
# ARGUMENTS:
#    $Tl            Toplevel object pointer.
#    $Game          Pointer to game data hash.
#    $Cards         Pointer to working card hash.
#    $Card          Working card hash index.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::WorkingDir
# =============================================================================
sub CardClick {
   my($Tl, $Game, $Cards, $Card) = @_;
   my($src, $resize, $encode, $image, $srcDiscard, $resizeDcrd);

   &DisplayDebug(1, "CardClick ...   Card: $Card   discard: '" . 
                    $$Cards{$Card}{'discard1'} . "'");

   if ($$Game{'State'} eq 'discard1') {          # Must be 'discard' state.
      if (not exists($$Cards{$Card}{'discard'})) {
         GD::Image->trueColor(1);         # Need to work in truecolor images.
         # ---
         # Open the card image file in GD.
         $src = GD::Image->newFromPng($$Cards{$Card}{'file'});
      
         # Create an empty image with the desired dimensions.
         $resize = new GD::Image($$Cards{$Card}{'cw'}, $$Cards{$Card}{'ch'});
         $resize->alphaBlending(0);
         $resize->saveAlpha(1);
         
         # Copy from $src and resize it into $resize
         # gd.copyResized(source, dstX, dstY, srcX, srcY, dstW, dstH, srcW, srcH)
         $resize->copyResized($src, 0, 0, 0, 0, $$Cards{$Card}{'cw'}, 
                              $$Cards{$Card}{'ch'}, $src->width, $src->height);
         # ---
         # Open the discard image file in GD.
         $srcDcrd = GD::Image->newFromPng(join('/', $main::WorkingDir, 
                                          'cards/discardX.png'));
         
         # Create an empty image with the desired dimensions.
         $resizeDcrd = new GD::Image($$Cards{$Card}{'cw'}, $$Cards{$Card}{'ch'});
         $resizeDcrd->alphaBlending(0);
         $resizeDcrd->saveAlpha(1);
         
         # Copy everything from $srcDcrd and resize it into $resizeDcrd
         $resizeDcrd->copyResized($srcDcrd, 0, 0, 0, 0, $$Cards{$Card}{'cw'}, 
                                  $$Cards{$Card}{'ch'}, $src->getBounds());
         # ---
         # Merge the two resized images.
         # gd.copyResized(source, dstX, dstY, srcX, srcY, dstW, dstH, srcW, srcH)
         $resize->copyMerge($resizeDcrd, 0,0,0,0, $$Cards{$Card}{'cw'}, 
                            $$Cards{$Card}{'ch'}, 80);
   
         # Encode the resized image.
         $encode = encode_base64($resize->png());
         
         # Create Tk::Photo object. Use it for button overlay.
         $image = $Tl->Photo("Discard${Card}", -data => $encode,
                              -format => 'png');
   
         # Apply the image.
         $$Cards{$Card}{'obj'}->configure(-image => $image, -borderwidth => 3,
                                          -relief => 'raised');
         $$Cards{$Card}{'discard'} = 1;
            
         # Free up GD working memory.
         undef $_ for $src, $srcDcrd, $resize, $resizeDcrd, $encode, $image;
      }
      else {
         delete($$Cards{$Card}{'discard'});
         &DisplayCard($Tl, $Game, $Cards, $Card);  # Display the original card image.
      }
   }
   return 0;
}

# =============================================================================
# FUNCTION:  Newdeck
#
# DESCRIPTION:
#    This routine loads the specified array with a full deck of cards. Cards
#    are set in 'new pack'  or NDO order. That is, ace-of-hearts the top card
#    and ace-of-spades the bottom card. Card order and values are as follows.
#
#     A   2   3   4   5   6   7   8   9   T   J   Q   K
#    14h 02h 03h 04h 05h 06h 07h 08h 09h 10h 11h 12h 13h  hearts
#    14c 02c 03c 04c 05c 06c 07c 08c 09c 10c 11c 12c 13c  clubs
#     K   Q   J   T   9   8   7   6   5   4   3   2   A
#    13d 12d 11d 10d 09d 08d 07d 06d 05d 04d 03d 02d 14d  diamonds
#    13s 12s 11s 10s 09s 08s 07s 06s 05s 04s 03s 02s 14s  spades
#
# CALLING SYNTAX:
#    $result = &Newdeck(\@Deck);
#
# ARGUMENTS:
#    $Deck          Pointer to working deck array.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub Newdeck {
   my($Deck) = @_;
   my(@order);

   &DisplayDebug(1, "Newdeck ...");

   @$Deck = ();
   foreach my $suit ('h','c','d','s') {
      if ($suit eq 'h' or $suit eq 'c') {
         @order = ('14','02','03','04','05','06','07','08','09','10','11','12','13');
      }
      else {
         @order = ('13','12','11','10','09','08','07','06','05','04','03','02','14');
      }
      foreach my $value (@order) {
         push (@$Deck, join('', $value, $suit));
      }
   }
   &DisplayDebug(2, "Newdeck: '@$Deck'");
   return 0;
}

# =============================================================================
# FUNCTION:  Shuffle
#
# DESCRIPTION:
#    This routine shuffles the specified array of cards using three shuffle 
#    methods; Fisher-Yates, deck cut, and fan merge. If an iteration count is
#    not specified, a random count between 2 and 20 inclusive will be used.
#
#    If the program is running in debug mode, a check is performed to ensure
#    all 52 cards are present in the deck.
#
# CALLING SYNTAX:
#    $dPos = &Shuffle(\@Deck, $Iter);
#
# ARGUMENTS:
#    $Deck          Pointer to working deck array.
#    $Iter          Number of shuffle iterations; default 2-10
#
# RETURNED VALUES:
#    0 = top card of the deck
#
# ACCESSED GLOBAL VARIABLES:
#    $main::opt_d
# =============================================================================
sub Shuffle {
   my($Deck, $Iter) = @_;
   my($i, $j, $deckLen, @temp);

   if ($Iter eq '') {
      my($sec, $usec) = gettimeofday();
      $Iter = int($usec % 15) + 3;
   }
   &DisplayDebug(1, "Shuffle ... Iter: $Iter");
   
   if ($#$Deck > -1) {
      &DisplayDebug(2, "Shuffle,  pre-size " . scalar @$Deck . ": '@$Deck'");
      $deckLen = @$Deck;                              # Get the deck length.
      while ($Iter--) {
         $i = $deckLen;
         # Fisher-Yates. Swap each card with one at random deck position.
         while (--$i) {
            $j = int rand ($i + 1);
            @$Deck[$i,$j] = @$Deck[$j,$i];
         }
         
         # Random 3rd-ish deck cut.
         @temp = splice(@$Deck, int(rand(7)+15), int(rand(7)+15));
         push (@$Deck, @temp);
         # Fan merge.
         @temp = splice(@$Deck, 0, int(rand(9)+22));  # Somewhat center.
         $j = $#temp;
         while ($j >= 0) {
            splice(@$Deck, $j--, 0, $temp[$j]);
         }
      }
      &DisplayDebug(2, "Shuffle, post-size " . scalar @$Deck . ": '@$Deck'");
   }
   
   if ($main::opt_d > 0) {      # Validate deck content if running in debug mode.
      my(@chkDeck) = ();
      foreach my $card ('02','03','04','05','06','07','08','09','10','11','12','13','14') {
         foreach my $suit ('c','d','h','s') {
            push (@chkDeck, join('', $card, $suit));
         }
      }
      &DisplayDebug(3, "Shuffle,  chkDeck " . scalar @chkDeck . ": '@chkDeck'");
      my(@wrkDeck) = sort(@$Deck);   # Get current cards and sort.
      &DisplayDebug(3, "Shuffle,  wrkDeck " . scalar @wrkDeck . ": '@wrkDeck'");
      for (my $c = 0; $c <= $#wrkDeck; $c++) {
         if ($wrkDeck[$c] ne $chkDeck[$c]) {
            &ColorMessage('Deck corrupted!', 'BLINK BRIGHT_RED');
            return 0;
         }
      }
   }
   return 0;
}

# =============================================================================
# FUNCTION:  TkGameDelay
#
# DESCRIPTION:
#    This routine is called to perform a game play time delay. The TK module
#    used does not block other TK background functionality like the perl sleep
#    function does.
#
# CALLING SYNTAX:
#    $result = &TkGameDelay($Tl, $Msec);
#
# ARGUMENTS:
#    $Tl            Toplevel object pointer.
#    $Msec          Time in milliseconds to delay.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub TkGameDelay {
   my($Tl, $Msec) = @_;

   waitVariableX($Tl, $Msec) if ($Msec > 0);    # Wait a bit.            
   return 0;
}

# =============================================================================
# FUNCTION:  CheckLowStraight
#
# DESCRIPTION:
#    This routine is called to check the specified sorted player hand for a 
#    low straight 2345A. The hand is reordered to A2345, if found, for proper
#    processing and scoring.
#
# CALLING SYNTAX:
#    $result = &CheckLowStraight($Game, $Player);
#
# ARGUMENTS:
#    $Game          Pointer to game hash.
#    $Player        Hand to process; 'Player1' or 'Player2'
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub CheckLowStraight {
   my($Game, $Player) = @_;

   if ($$Game{$Player}{'Hand'}[0] =~ m/^02/ and 
       $$Game{$Player}{'Hand'}[1] =~ m/^03/ and
       $$Game{$Player}{'Hand'}[2] =~ m/^04/ and
       $$Game{$Player}{'Hand'}[3] =~ m/^05/ and
       $$Game{$Player}{'Hand'}[4] =~ m/^14/) {
      my($ace) = pop(@{ $$Game{$Player}{'Hand'} });
      unshift(@{ $$Game{$Player}{'Hand'} }, $ace);
   }
   return 0;
}

# =============================================================================
# FUNCTION:  RankHand
#
# DESCRIPTION:
#    This routine stores the poker rank for the specified card hand in the 
#    players working hash. In addition to rank, the card value(s) significant
#    to the rank are included, e.g. the high card of a straight or card 
#    forming a pair. The rank is also return to the caller.
#
#    For ranks 'Two-Pair' and 'Full-House', the cards of the more significant
#    part of the rank is listed first. This decending order serves to simplify
#    the 'Winner' code when comparing similar poker hands.
#
#    Checks for duplicated cards and previously dealt hands are also performed
#    for program debug and card shuffle improvement purposes.
#
# CALLING SYNTAX:
#   $rank = &RankHand($Game, $Player, $DrawCount);
#
# ARGUMENTS:
#    $Game          Pointer to game hash.
#    $Player        Hand to process; 'Player1' or 'Player2'
#    $DrawCount     Number of cards drawn.
#
# RETURNED VALUES:
#    Poker rank.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub RankHand {
   my($Game, $Player, $DrawCount) = @_;
   my($rank) = '';   my(@tallyR) = ();
   my(@straight) = ('1402030405','0203040506','0304050607','0405060708','0506070809',
                    '0607080910','0708091011','0809101112','0910111213','1011121314');
   my(%xlat) = ('02' => '2', '03' => '3', '04' => '4', '05' => '5', '06' => '6',
                '07' => '7', '08' => '8', '09' => '9', '10' => 'T', '11' => 'J',
                '12' => 'Q', '13' => 'K', '14' => 'A');

   &DisplayDebug(1, "RankHand ...   $Player   DrawCount: $DrawCount");
   if ($$Game{$Player}{'Hand'}[0] eq $$Game{$Player}{'Hand'}[1] or
       $$Game{$Player}{'Hand'}[1] eq $$Game{$Player}{'Hand'}[2] or
       $$Game{$Player}{'Hand'}[2] eq $$Game{$Player}{'Hand'}[3] or
       $$Game{$Player}{'Hand'}[3] eq $$Game{$Player}{'Hand'}[4]) {
      &ColorMessage('Duplicate card!', 'BLINK BRIGHT_RED');
      $$Game{$Player}{'HandRank'} = 'Duplicate card!';
      return '$Player duplicate card!';
   }
   my($value) = join('', @{ $$Game{$Player}{'Hand'} });
   
   # Check if hand was previously dealt.
   if ($DrawCount != 0) {
      &DisplayDebug(2, "RankHand Hand Check: '$value'");
      my(@check) = grep(/$value/, @{ $$Game{'AllHands'} });
      if (scalar @check > 0) {
         &ColorMessage('Duplicate hand! @check', 'BLINK BRIGHT_RED');
         $$Game{$Player}{'HandRank'} = 'Duplicate hand!';
         return '$Player duplicate hand!';
      }
   }
   
   my($suit) = $value;
   $value =~ s/[cdhs]//g;   # Remove suit characters.
   $suit =~ s/\d//g;        # Remove digit characters.
   &DisplayDebug(3, "RankHand, suit: '$suit'   value: '$value'");
   # ----------
   if ($suit eq 'ccccc' or $suit eq 'ddddd' or $suit eq 'hhhhh' or $suit eq 'sssss') {
      my($hCard) = substr($value, -2);          # High card value
      $rank = "Flush $xlat{$hCard} high"; 
   }
   foreach (@straight) {                        # Check all possible straights
      if ($value eq $_) {                       # Matched?
         my($hCard) = substr($value, -2);       # High card value
         if ($rank =~ m/Flush/) {               # All same suit
            if ($value eq '1011121314') {       # Matched highest straight?
               $rank = 'Royal-Flush';
            }
            else {
               $rank = "Straight-Flush $xlat{$hCard} high";
            }
         }
         else {
            $rank = "Straight $xlat{$hCard} high";
         }
         last;
      }
   }
   # ----------
   unless ($rank) {          # Continue processing if no rank yet.
      my(%pairs) = ();
      foreach my $i ('02','03','04','05','06','07','08',
                     '09','10','11','12','13','14') {
         my(@check) = grep(/${i}c|${i}d|${i}h|${i}s/, @{ $$Game{$Player}{'Hand'} });
         if (scalar(@check) == 4) {
            push(@tallyR, "Four-of-a-Kind $xlat{$i}\x27s");
            last; 
         }
         elsif (scalar(@check) == 3) { 
            push(@tallyR, "Three-of-a-Kind $xlat{$i}\x27s");
         }
         elsif (scalar(@check) == 2) { 
            push(@tallyR, "One-Pair $xlat{$i}\x27s");
            $pairs{$xlat{$i}} = $i;   # Save value for two-pair ordering. 
         }
      }
      if (scalar(@tallyR) == 2) {            # If multiple entry types
         my($types) = join(' ', @tallyR);    # Combine entrys
         if ($types =~ m/Pair\s(\w).+Kind\s(\w)/) {
            $rank = "Full-House $2\x27s $1\x27s";
         }
         elsif ($types =~ m/Kind\s(\w).+Pair\s(\w)/) {
            $rank = "Full-House $1\x27s $2\x27s";
         }
         elsif ($types =~ m/Pair\s(\w).+Pair\s(\w)/) {
            my($c1) = $1;   my($c2) = $2;
            if ($pairs{$c1} > $pairs{$c2}) {
               $rank = "Two-Pair $c1\x27s $c2\x27s";
            }
            else {
               $rank = "Two-Pair $c2\x27s $c1\x27s";
            }
         }
      }
      else {
         $rank = $tallyR[0];
      }
   }
   # ----------
   unless ($rank) {          # Continue processing if no rank yet.
      my($hCard) = substr($value, -2);        # High card value
      $rank = "High-Card $xlat{$hCard}";
   }
   $$Game{$Player}{'HandRank'} = $rank;
   $$Game{$Player}{'RankDebug'} = $rank;   
   &DisplayDebug(2, "RankHand rank: $$Game{$Player}{'HandRank'}");
   return $rank;
}

# =============================================================================
# FUNCTION:  Winner
#
# DESCRIPTION:
#    This routine determines the winner based upon the current poker hands of
#    Player1 and Player2. It relies on the strings created by the HandRank 
#    routine which includes card related information such as high card value
#    and pair value. 
#
# CALLING SYNTAX:
#   $winner = &Winner(\%Game);
#
# ARGUMENTS:
#    $Game          Pointer to game hash.
#
# RETURNED VALUES:
#    'Player1', 'Player2', or 'Draw'
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub Winner {
   my($Game) = @_;
   my($p1Rank, $p2Rank) = ('', ''); 
   my($p1Cards, $p2Cards, $p1Val1, $p2Val1, $p1Val2, $p2Val2); 
   my(%ranks) = ('9' => 'Royal-Flush', '8' => 'Straight-Flush', 
                 '7' => 'Four-of-a-Kind', '6' => 'Full-House', '5' => 'Flush',
                 '4' => 'Straight', '3' => 'Three-of-a-Kind', '2' => 'Two-Pair',
                 '1' => 'One-Pair', '0' => 'High-Card');
   my(%xlat) = ('2' => '02', '3' => '03', '4' => '04', '5' => '05', '6' => '06',
                '7' => '07', '8' => '08', '9' => '09', 'T' => '10', 'J' => '11',
                'Q' => '12', 'K' => '13', 'A' => '14');

   &DisplayDebug(1, "Winner ...");
   &DisplayDebug(2, "Winner p1 hand: '@{ $$Game{'Player1'}{'Hand'} }'");
   &DisplayDebug(2, "Winner p2 hand: '@{ $$Game{'Player2'}{'Hand'} }'");
   
   # Check for player drop.
   return 'Player1' if ($$Game{'Player2'}{'HandRank'} eq '');
   return 'Player2' if ($$Game{'Player1'}{'HandRank'} eq '');
   
   # Do a basic rank check. Higher rank wins.
   foreach my $rank (sort keys(%ranks)) {
      $p1Rank = $rank if ($$Game{'Player1'}{'HandRank'} =~ m/^$ranks{$rank}/);
      $p2Rank = $rank if ($$Game{'Player2'}{'HandRank'} =~ m/^$ranks{$rank}/);
      last if ($p1Rank ne '' and $p2Rank ne '');
   }
   &DisplayDebug(2, "Winner p1Rank: '$ranks{$p1Rank}'   p2Rank: '$ranks{$p2Rank}'");
   return 'Player1' if ($p1Rank > $p2Rank);
   return 'Player2' if ($p1Rank < $p2Rank);
  
   # Ranks are the same so more detailed checks are needed.
   $p1Cards = join('', reverse @{ $$Game{'Player1'}{'Hand'} }); 
   $p1Cards =~ s/[cdhs]//g;       # Remove suit characters.
   $p2Cards = join('', reverse @{ $$Game{'Player2'}{'Hand'} }); 
   $p2Cards =~ s/[cdhs]//g;       # Remove suit characters.
   &DisplayDebug(2, "Winner p1Cards: '$p1Cards'   p2Cards: '$p2Cards'");

   # High-Card or Straight or Flush or Straight-Flush
   if ($p1Rank == 0 or $p1Rank == 4 or $p1Rank == 5 or $p1Rank == 8) {
      return 'Player1' if ($p1Cards gt $p2Cards);
      return 'Player2' if ($p1Cards lt $p2Cards);
   }
   # One-Pair J's or Three-of-a-Kind J's or Four-of-a-Kind J's
   elsif ($p1Rank == 1 or $p1Rank == 3 or $p1Rank == 7) {
      $p1Val1 = $xlat{ substr($$Game{'Player1'}{'HandRank'}, -3, 1) };
      $p2Val1 = $xlat{ substr($$Game{'Player2'}{'HandRank'}, -3, 1) };
      &DisplayDebug(2, "Winner 2 p1Val1: '$p1Val1'   p2Val1: '$p2Val1'");
      return 'Player1' if ($p1Val1 gt $p2Val1);
      return 'Player2' if ($p1Val1 lt $p2Val1);
      &DisplayDebug(2, "Winner 2 p1Cards: '$p1Cards'   p2Cards: '$p2Cards'");
      # Three or Four-of-a-Kind can't get beyond here. Each player has the
      # same card pair so remaining cards determine the winner.
      $p1Cards =~ s/$p1Val1//g;  # Remove pair value.
      $p2Cards =~ s/$p2Val1//g;  # Remove pair value.
      &DisplayDebug(2, "Winner 2 p1Cards: '$p1Cards'   p2Cards: '$p2Cards'");
      return 'Player1' if ($p1Cards gt $p2Cards);
      return 'Player2' if ($p1Cards lt $p2Cards);
   }
   # Two-Pair 7's 3's or Full-House 9's K's
   elsif ($p1Rank == 2 or $p1Rank == 6) {
      $p1Val1 = $xlat{ substr($$Game{'Player1'}{'HandRank'}, -7, 1) }; # High value
      $p2Val1 = $xlat{ substr($$Game{'Player2'}{'HandRank'}, -7, 1) }; # High value
      $p1Val2 = $xlat{ substr($$Game{'Player1'}{'HandRank'}, -3, 1) }; # Low value
      $p2Val2 = $xlat{ substr($$Game{'Player2'}{'HandRank'}, -3, 1) }; # Low value
      &DisplayDebug(2, "Winner 3 p1Val1: '$p1Val1'   p2Val1: '$p2Val1'");
      &DisplayDebug(2, "Winner 3 p1Val2: '$p1Val2'   p2Val2: '$p2Val2'");
      return 'Player1' if ($p1Val1 gt $p2Val1);
      return 'Player2' if ($p1Val1 lt $p2Val1);
      # Full-House can't get beyond here.  Each player has the same first card
      # pair.
      return 'Player1' if ($p1Val2 gt $p2Val2);
      return 'Player2' if ($p1Val2 lt $p2Val2);
      # Each player has the same second card pair. so remaining card determines
      # the winner.
      $p1Cards =~ s/$p1Val1|$p1Val2//g;  # Remove pair values.
      $p2Cards =~ s/$p2Val1|$p1Val2//g;  # Remove pair values.
      &DisplayDebug(2, "Winner 3 p1Cards: '$p1Cards'   p2Cards: '$p2Cards'");
      return 'Player1' if ($p1Cards gt $p2Cards);
      return 'Player2' if ($p1Cards lt $p2Cards);
   }
   return 'Draw';     # Both players with Royal-Flush use this also.
}

# =============================================================================
# FUNCTION:  ComputerBet
#
# DESCRIPTION:
#    This routine is used to determine a bet based on the current handrank for
#    the player, the opponents bet, and amount in pot. Opponent number of cards
#    drawn is available but not yet implemented. 
#
# CALLING SYNTAX:
#    $bet = &ComputerBet($Game, $Player);
#
# ARGUMENTS:
#    $Game          Pointer to game hash.
#    $Player        Hand to process; 'Player1' or 'Player2'
#
# RETURNED VALUES:
#    $Bet           Computer's bet (5,10,15,20,25), 0 = call, -1 = 'drop'
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ComputerBet {
   my($Game, $Player) = @_;
   my($bet) = 0;
   my($handRank) = $$Game{$Player}{'HandRank'};
   my($opponentBet) = $$Game{$Player}{'OpponentBet'};

   &DisplayDebug(1, "ComputerBet ...   handRank: $handRank" .
                    "   opponentBet: $opponentBet   opponentDraw: " . 
                    $$Game{$Player}{'OpponentDraw'});
      
   if ($handRank =~ m/Flush/ or $handRank =~ m/Full/ or
       $handRank =~ m/Four/) {              # Very good hand
      if ($opponentBet >= 15) {
         if ($Game{'Pot'} > 100) {          # More conservative if pot > 100.
            $bet = (int(rand(3))+1)*5+5;    # Random $10 $15 $20
         }
         else {
            $bet = (int(rand(3))+1)*5+10;   # Random $15 $20 $25
         }
      }
      else {
         $bet = (int(rand(3))+1)*5;         # Random $5 $10 $15
      }
      &DisplayDebug(2, "ComputerBet ...   Very good hand   bet: $bet");
   }
   elsif ($handRank =~ m/Straight/ or $handRank =~ m/Three/) {  # Good hand
      if ($opponentBet >= 15) {
         if ($Game{'Pot'} > 100) {          # More conservative if pot > 100.
            $bet = (int(rand(3))+1)*5;      # Random $5 $10 $15
         }
         else {
            $bet = (int(rand(3))+1)*5+5;    # Random $10 $15 $20
         }
      }
      else {
         $bet = (int(rand(3))+1)*5;         # Random  $5 $10 $15
      }
      &DisplayDebug(2, "ComputerBet ...   Good hand   bet: $bet");
   }
   elsif ($handRank =~ 'Two-Pair') {        # Mediocre hand
      $bet = (int(rand(3))+1)*5;            # Random $5 $10 $15
      &DisplayDebug(2, "ComputerBet ...   Mediocre hand   bet: $bet");
   }
   elsif ($handRank =~ 'One-Pair') {        # Poor hand
      if (int(rand(10))+1 > 8) {            # 20% of the time
         if ($Game{'Pot'} > 100) {          # More conservative if pot > 100.
            $bet = (int(rand(2))+1)*5;      # Random $5 $10
         }
         else {
            $bet = (int(rand(2))+2)*5;      # Random $10 $15
         }
      }
      else {
         $bet = (int(rand(3)))*5;           # Random $0 $5 $10
      }
      # If $Player bets first, and this is 1st bet, bet is minimum $5.
      $bet = 5 if ($$Game{'FirstBet'} eq $Player and $opponentBet == 0);
      &DisplayDebug(2, "ComputerBet ...   Poor hand   bet: $bet");
   }
   else {                                   # Very poor hand
      my($rnd) = rand(10);
      &DisplayDebug(1, "ComputerBet ...   rnd: $rnd");
      if ($handRank =~ m/High-Card J/ or $handRank =~ m/High-Card Q/ or
          $handRank =~ m/High-Card K/ or $handRank =~ m/High-Card A/) {
         if ($opponentBet < 15) {
            $bet = (int(rand(2)))*5;        # Random $0 $5
         }
         else {
            # Drop 5% of the time unless a loan was taken.
            $bet = -1 if ($rnd >= 9.94 and $$Game{$Player}{'Bankroll'} > 0);
         }
      }
      else {
         $bet = (int(rand(2)))*5;           # Random $0 $5
         # Drop 20% of the time unless a loan was taken.
         if ($rnd => 7.99 and $$Game{$Player}{'Bankroll'} > 0) {
            $bet = -1;
         }
         else {
            $bet = 0;
         }       
      }
      # If $Player bets first, and this is 1st bet, bet is minimum $5.
      $bet = 5 if ($$Game{'FirstBet'} eq $Player and $opponentBet == 0);
      &DisplayDebug(1, "ComputerBet ...   Very poor hand   bet: $bet");
   }
   return $bet;
}

# =============================================================================
# FUNCTION:  ComputerDiscard
#
# DESCRIPTION:
#    This routine gets and exchanges the specified players cards.
#
# CALLING SYNTAX:
#    $result = &ComputerDiscard($Tl, $Game, $Player, $Cards, $MsgData, $Score);
#
# ARGUMENTS:
#    $Tl            Toplevel object pointer.
#    $Game          Pointer to game data hash.
#    $Player        Hand to process; 'Player1' or 'Player2'
#    $Cards         Pointer to card section hash.
#    $MsgData       Pointer to game message data hash.
#    $Score         Pointer to score data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ComputerDiscard {
   my($Tl, $Game, $Player, $Cards, $MsgData, $Score) = @_;
   my($opponent, @cIndx);
   &DisplayDebug(1, "ComputerDiscard ...   Player: $Player");

   # Get discards and exchange cards.
   if ($Player eq 'Player1') {
      $opponent = 'Player2';
   }
   else {
      $opponent = 'Player1';
   }
   $$Game{$opponent}{'OpponentDraw'} = &AutoDiscard($Tl, $Player, $Game, $Cards);
   # Set 'Value' to be displayed in game table message.
   $$Game{$Player}{'Value'} = $$Game{$opponent}{'OpponentDraw'};
   if ($$Game{$Player}{'Value'} == 1) {
      &DisplayGameMsg($$MsgData{'17'}, $Player, $Game, 1);
   }
   else {
      &DisplayGameMsg($$MsgData{'16'}, $Player, $Game, 1);
   }   
   
   &DisplayDebug(3, "$Player  pre-discard: @{ $$Game{$Player}{'Hand'} }");
   # Replace the players discards from the deck.
   if ($Player eq 'Player1') {
      @cIndx = ('01','02','03','04','05');
   }
   else {
      @cIndx = ('06','07','08','09','10');
   }
   my($i) = 0;
   foreach my $card (@cIndx) {
      if (exists($$Cards{$card}{'discard'})) {
         &DisplayDebug(2, "pre-discard: $card   $$Game{$Player}{'Hand'}[$i]   " . 
            "dPos: $$Game{'Deck'}{'dPos'}");
         $$Game{$Player}{'Hand'}[$i] = 
            $$Game{'Deck'}{'Cards'}[ $$Game{'Deck'}{'dPos'}++ ];
         &DisplayDebug(2, "pst-discard: $card   $$Game{$Player}{'Hand'}[$i]   " .
            "dPos: $$Game{'Deck'}{'dPos'}");
         delete($$Cards{$card}{'discard'});
      }
      $i++;
   }
   @{ $$Game{$Player}{'Hand'} } = sort(@{ $$Game{$Player}{'Hand'} });
   &CheckLowStraight($Game, $Player);
   &DisplayDebug(3, "$Player post-discard: @{ $$Game{$Player}{'Hand'} }");

   # Determine new hand score and rank for player 2.
   my($rank2) = &RankHand($Game, $Player, $$Game{$opponent}{'OpponentDraw'});
   my($cards) = join('', @{ $$Game{'Player2'}{'Hand'} });
   push( @{ $$Game{'AllHands'} }, "$cards:4");      # Replaced cards player 2.

   &DisplayDebug(2, "$$Game{$Player}{'Name'} " .
      "cards: @{ $$Game{$Player}{'Hand'} }   " .
      "rank: $$Game{$Player}{'HandRank'}");
	return;
}

# =============================================================================
# FUNCTION:  AutoDiscard
#
# DESCRIPTION:
#    This routine determines the cards to discard and sets a 'discard' entry 
#    for the corresponding card. For Player1, the onscreen cards are clicked
#    to show the discard indication.
#
# CALLING SYNTAX:
#    $result = &AutoDiscard($Tl, $Player, $Game, $Cards);
#
# ARGUMENTS:
#    $Tl            Toplevel object pointer.
#    $Player        Hand to process; 'Player1' or 'Player2'
#    $Game          Pointer to game hash.
#    $Cards         Pointer to working card hash.
#
# RETURNED VALUES:
#    Number of cards marked for exchange.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub AutoDiscard {
   my($Tl, $Player, $Game, $Cards) = @_;
   my($suits, $values, $count, $card);
   my(@hold) = (0,0,0,0,0);
   
   &DisplayDebug(1, "AutoDiscard ...  $Player @{ $$Game{$Player}{'Hand'} }");   

   if ($$Game{$Player}{'HandRank'} =~ m/Royal-Flush/i or 
       $$Game{$Player}{'HandRank'} =~ m/Straight-Flush/i or
       $$Game{$Player}{'HandRank'} =~ m/Four-of-a-Kind/i or 
       $$Game{$Player}{'HandRank'} =~ m/Full-House/i or
       $$Game{$Player}{'HandRank'} =~ m/Flush/i or 
       $$Game{$Player}{'HandRank'} =~ m/Straight/i) {
       @hold = (1,1,1,1,1);
   }
   elsif ($$Game{$Player}{'HandRank'} =~ m/Three-of-a-Kind/i) {
      # Find three of a kind and hold it.
      foreach (0..2) {
         if (substr($$Game{$Player}{'Hand'}[$_],0,2) eq 
             substr($$Game{$Player}{'Hand'}[$_+1],0,2) and
             substr($$Game{$Player}{'Hand'}[$_+1],0,2) eq 
             substr($$Game{$Player}{'Hand'}[$_+2],0,2)) {
            $hold[$_] = 1;
            $hold[$_+1] = 1;
            $hold[$_+2] = 1;
         }
      }
   }
   elsif ($$Game{$Player}{'HandRank'} =~ m/Two-Pair/i) {
      # Find pairs and hold them.
      foreach (0..3) {
         if (substr($$Game{$Player}{'Hand'}[$_],0,2) eq 
             substr($$Game{$Player}{'Hand'}[$_+1],0,2)) {
            $hold[$_] = 1;
            $hold[$_+1] = 1;
         }
      }
   }
   elsif ($$Game{$Player}{'HandRank'} =~ m/One-Pair/i) {
      # Find pair and hold it.
      foreach (0..3) {
         if (substr($$Game{$Player}{'Hand'}[$_],0,2) eq 
             substr($$Game{$Player}{'Hand'}[$_+1],0,2)) {
            $hold[$_] = 1;
            $hold[$_+1] = 1;
         }
      }
   }

   # If no holds, check for 3-4 cards of flush.
   unless ($hold[0] or  $hold[1] or $hold[2] or $hold[3] or $hold[4]) {
      $suits = join('', @{ $$Game{$Player}{'Hand'} });
      $suits =~ s/\d//g;
      foreach ('c','d','h','s') {
         $count = ($suits =~ tr/$_//);
         if ($count > 2) {
            $suits =~ s/$_/1/g;
            $suits =~ s/[cdhs]/0/g;
            @hold = split('', $suits);
         }
      }
   }
   
   # If no holds, check for 3-4 cards of straight. The ace is always sorted 
   # to the last position in the hand. (Unless a low-straight is previously
   # detected; for which case, we wouldn't be here.) This allows for normal 
   # straight checking for Q, K, A. Since A, 2, 3 is also a valid straight,
   # it is checked as an exception with a separate bit of code.
   unless ($hold[0] or  $hold[1] or $hold[2] or $hold[3] or $hold[4]) {
      my(@temp) = @{ $$Game{$Player}{'Hand'} }; # Copy cards
      foreach my $crd (@temp) {                 # Remove suit designator
         $crd =~ s/[cdhs]//;
      }
      foreach (0..2) {
         if ($_== 0 and $temp[0] == 2 and $temp[1] == 3 and $temp[4] == 14) {
            $hold[0] = 1;
            $hold[1] = 1;
            $hold[4] = 1;
            $hold[2] = 1 if ($temp[2] == 4);   # card a 4?
            $hold[3] = 1 if ($temp[3] == 5);   # card a 5?
            last;     
         }
         elsif (($temp[$_]+1) == $temp[$_+1] and ($temp[$_+1]+1) == $temp[$_+2]) {
            $hold[$_] = 1;
            $hold[$_+1] = 1;
            $hold[$_+2] = 1;
            if ($_== 0) {       # 4th card during 1st iteration. 
               $hold[$_+3] = 1 if ($temp[$_+3] == ($temp[$_+2]+1)); # 3456x
               $hold[$_+3] = 1 if ($temp[$_+3] == ($temp[$_+2]+2)); # 3457x
               $hold[$_+4] = 1 if ($temp[$_+4] == ($temp[$_+2]+2)); # 345x7
            }
            elsif ($_== 1) {    # 4th card during 2nd iteration. 
               if ($temp[$_+3] == ($temp[$_+2]+1)) {                # x5678
                  $hold[$_+3] = 1;
               }
               elsif ($temp[$_+3] == ($temp[$_+2]+2)) {             # x5679
                  $hold[$_+3] = 1;
               }
               elsif ($temp[$_-1] == ($temp[$_]-2)) {               # 4678x 
                  $hold[$_-1] = 1;
               }
            }
            elsif ($_== 2) {    # 4th card during 3rd iteration. 
               $hold[$_-1] = 1 if ($temp[$_-1] == ($temp[$_]-2));   # x4678
            }
            last;
         }
      }
   }

   # If still no holds, keep high card if > 9.
   unless ($hold[0] or  $hold[1] or $hold[2] or $hold[3] or $hold[4]) {
      $hold[-1] = 1 if (substr($$Game{$Player}{'Hand'}[-1], 0, 2) > 9); 
   }
   
   # Finally, step through the @hold array and set 'discard' for 
   # non-marked (0) cards. For Player1, the onscreen card is clicked.
   # This results in 'discard' being set for the card.
   $count = 0;
   for (my $x = 0; $x <= $#hold; $x++) {
      if ($hold[$x] == 0) {
         if ($Player eq 'Player1' ) {
            $card = $x + 1;
         }
         else {
            $card = $x + 6;
         }
         $card = "0$card" if (length($card) == 1);
         if ($$Game{'AutoPlay'} == 1 and $Player eq 'Player1') {
            &CardClick($Tl, $Game, $Cards, $card);
            &TkGameDelay($Tl, 200);    # Wait a bit.            
         }
         else {
            $$Cards{$card}{'discard'} = 1;
         }
         $count++;
      }
   }
   &DisplayDebug(3, "AutoDiscard ...  $count  '@hold'  " .
                                      $$Game{$Player}{'HandRank'});
   return $count;
}

# =============================================================================
# FUNCTION:  CheckBankroll
#
# DESCRIPTION:
#    This routine checks the specified players bankroll for funds sufficient
#    to cover the specified amount. If available, the amount is returned.
#
#    If insufficient funds, the players credit is checked. If good (LoanCount 
#    <= LoanLimit), BankLoan amount is added to the player's BankRoll and the
#    LoanCount is incremented. The player's BankRoll is then deducted and the 
#    amount is returned.
#
#    An input amount of 0 only performs the payback check/function. 
#
# CALLING SYNTAX:
#    $result = &CheckBankroll($Tl, $Game, $Player, $Amount);
#
# ARGUMENTS:
#    $Tl             Toplevel object pointer.
#    $Game           Pointer to game hash.
#    $Player         'Player1' or 'Player2'.
#    $Amount         Amount to check.
#
# RETURNED VALUES:
#    $Amount
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub CheckBankroll {
   my($Tl, $Game, $Player, $Amount) = @_;
   my($msg);   my($pay) = 0;

   &DisplayDebug(1, "CheckBankroll ...   Amount: $Amount   $Player has: " .
      "$$Game{$Player}{'Bankroll'}   loancount: $$Game{$Player}{'LoanCount'}");

   return $Amount if ($Amount < 0);   # Ignore ammount < 0.

   # Payback loan(s) if bankroll funds permit.
   while ($$Game{$Player}{'Bankroll'} > 100 and $$Game{$Player}{'LoanCount'} > 0) {
      $$Game{$Player}{'Bankroll'} -= $$Game{'BankLoan'};  # Payback loan amount.
      $$Game{$Player}{'LoanCount'} -= 1;
      $pay += $$Game{'BankLoan'};
      &DisplayDebug(2, "CheckBankroll whileloop payback   $Player  bankroll: " .
         "$$Game{$Player}{'Bankroll'}   loancount: $$Game{$Player}{'LoanCount'}");
   }
   if ($pay > 0) {
      if (exists($$Game{$Player}{'Wear'})) {
         $msg = &ItemMsg($Game, $Player, 'payback');
      }
      else {
         $msg = join('', $$Game{$Player}{'Name'}, " loan payback \$", 
                         $pay, " Loans: ", $$Game{$Player}{'LoanCount'});
      }
      &DisplayGameMsg($msg, $Player, $Game);
   }
   return 0 if ($Amount == 0);   # Payback function only.
   
   # Debit bankroll.
   if (($$Game{$Player}{'Bankroll'} - $Amount) < 0) {     # Insufficient funds?
      if ($$Game{$Player}{'LoanCount'} < $$Game{'LoanLimit'}) {   # Good credit?
         $$Game{$Player}{'Bankroll'} += $$Game{'BankLoan'};       # Grant loan.
         $$Game{$Player}{'LoanCount'} += 1;
         # Game play stat for Auto-Play. Remember highest LoanCount.
         if ($$Game{$Player}{'LoanHigh'} < $$Game{$Player}{'LoanCount'}) {
            $$Game{$Player}{'LoanHigh'} = $$Game{$Player}{'LoanCount'};
         }

         &DisplayDebug(2, "CheckBankroll loan   $Player  bankroll: " .
         "$$Game{$Player}{'Bankroll'}   loancount: $$Game{$Player}{'LoanCount'}");
         if (exists($$Game{$Player}{'Wear'})) {
            $msg = &ItemMsg($Game, $Player, 'loan');
         }
         else {
            $msg = join('', $$Game{$Player}{'Name'}, " loaned \$", 
               $$Game{'BankLoan'}, " Loans: ", $$Game{$Player}{'LoanCount'});
         }
         &DisplayGameMsg($msg, $Player, $Game);
         &TkGameDelay($Tl, 1000);
      }
   }
   return $Amount;
}

# =============================================================================
# FUNCTION:  DisplayGameMsg
#
# DESCRIPTION:
#    This routine displays a game message to the user in the GUI message widget.
#    This widget is created with the -textvariable option and points to the
#    $Game{'Msg'} variable. Updates to this variable are displayed by Tk in
#    the GUI.
# 
#    Message text substitutions are performed if keywords are present. The
#    following keywords are processed.  
#
#       Keyword   Description
#       -------   -----------
#       %alt%     Random select from alternate messages; separated by '_'.
#       %name%    Replace with player name.
#       %bank%    Players current bankroll.
#       %see%     Acknowledge bet for raise.
#       %value%   Replace with $Game{$Player}{'Value'}.
#       %rank%    Replace with $Game{$Player}{'HandRank'}.
#       %opnt%    Opponent's name.
#
# CALLING SYNTAX:
#    $result = &DisplayGameMsg($Message, $Player, $Game, $Flag);
#
# ARGUMENTS:
#    $Message         Message to be output.
#    $Player          'Player1' or 'Player2'.
#    $Game            Pointer to the game hash.
#    $Flag            1 = Display in player label.
#                     2 = Append to current message string.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub DisplayGameMsg {
   my($Message, $Player, $Game, $Flag) = @_;
   my(%keywords) = ('%name%' => 'Name', '%bank%' => 'Bankroll',
                    '%see%' => 'OpponentBet', '%value%' => 'Value', 
                    '%rank%' => 'HandRank', '%opnt%' => 'Player2');
   my($sub);

   if ($Message ne '') {
      # Change opponent name lookup if called with Player2.
      $keywords{'%opnt%'} = 'Player1' if ($Player eq 'Player2');
      
      if ($Message =~ m/^%alt%(.+)/s) {
         my(@temp) = split('_', $1);
         my($idx) = int(rand($#temp +1));
         $Message = $temp[$idx];
      }
   
      foreach my $key (keys(%keywords)) {
         if ($Message =~ m/$key/) {
            if ($key eq '%opnt%') {
               $sub = $$Game{ $keywords{$key} }{'Name'};
            }
            else {
               $sub = $$Game{$Player}{ $keywords{$key} };
            }
            $sub = substr($sub, 0, index($sub, '_')) if ($sub =~ m/_/);
            $Message =~ s/$key/$sub/;
         }
      }
   }
   &DisplayDebug(1, "DisplayGameMsg Flag: '$Flag'   '$Player' - '$Message'");
   
   if ($Flag == 1) {
      $$Game{$Player}{'Msg'} = $Message;
   }
   elsif ($Flag == 2) {
      $$Game{'Msg'} = join(' ', $$Game{'Msg'}, $Message);
   }
   else {   
      $$Game{'Msg'} = $Message;
   }
   return 0;
}

# =============================================================================
# FUNCTION:  DisplayDebug
#
# DESCRIPTION:
#    Displays a debug message to the user if the current program debug level 
#    is >= to the message debug level. Debug level colors message. 
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
#    $main::opt_d
# =============================================================================
sub DisplayDebug {
   my($Level, $Message) = @_;
   
   if ($main::opt_d >= $Level) {
      if ($Level == 1) {
         &ColorMessage($Message, 'BRIGHT_CYAN');
      }            
      elsif ($Level == 2) {
         &ColorMessage($Message, 'BRIGHT_GREEN');
      }            
      elsif ($Level == 3) {
         &ColorMessage($Message, 'BRIGHT_MAGENTA');
      }            
      else {
         &ColorMessage($Message, '');
      }
   }
   return 0;
}

# =============================================================================
# FUNCTION:  ColorMessage
#
# DESCRIPTION:
#    Displays a message to the user. If specified, an input parameter provides
#    coloring the message text. Specify 'use Term::ANSIColor' in the perl script
#    to define the ANSIcolor constants. Output of the message is directed to
#    $main::Logfile if -l has been specified on the startup CLI.
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
#    $main::Logfile
# =============================================================================
sub ColorMessage {
   my($Message, $Color, $Option) = @_;
   my($cr) = "\n";

   if ($main::Logfile ne '') {
      open(my $FH, '>>', $main::Logfile);
      print $FH $Message . "\n";
      close($FH);
      return 0;
   }

   $cr = '' if ($Option eq 'nocr');
   if ($Color ne '' and $^O =~ m/linux/) {
      print STDOUT colored($Message . $cr, $Color);
   }
   else {
      print STDOUT $Message . $cr;
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
#    $main::WorkingDir
# =============================================================================
sub PlaySound {
   my($SoundFile, $Volume) = @_;
   my($vol);
   my($player) = "/usr/bin/aplay -q -f cd";
   my($pathFile) = join('/', $main::WorkingDir, 'wave', 'Card-flip-1.wav'); #$SoundFile);

   &DisplayDebug(1, "PlaySound ...  filePath: $pathFile");

   if (-e $pathFile) {
      if ($Volume =~ m/^(\d+)/) {
         $vol = $1;
      }
      else {
         $vol = 80;
      }
#      system("/usr/bin/amixer set PCM ${vol}% >/dev/null");
      system("$player $pathFile &");
   }
   return 0;
}

# =============================================================================
# FUNCTION:  GetCardImage
#
# DESCRIPTION:
#    This routine is called by &DisplayCard when using a card deck image file
#    that holds all cards. The %cardDeck hash below holds the associated data
#    to extract the card image. The GD copy function is used.
#
#    The suit keys (d,c,h,s) supply the Y coordinate and the card value (02,
#    03..14) supply the X coordinate. Key 15 is the card back image.
#
# CALLING SYNTAX:
#    $imgObj = &GetCardImage($Game, $Cards, $Card);
#
# ARGUMENTS:
#    $Game          Pointer to game hash.
#    $Cards         Pointer to working card hash.
#    $Card          The card to return. e.g. 03c, 10s.
#
# RETURNED VALUES:
#    Card image object = Success, undef = Error
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub GetCardImage {
   my($Game, $Cards, $Card) = @_;
   my($x, $y, $src, $out);
   my($deck) = '';
   my(%cardDeck) = (
      '1' => {'name' => 'deck-1.png', 'width' => 318, 'height' => 452, 
              'd' => 0, 'c' => 480, 'h' => 962, 's' => 1445, 'b' => 962,
              '02' => 0, '03' => 343, '04' => 686, '05' => 1028, '06' => 1370,
              '07' => 1714, '08' => 2056, '09' => 2399, '10' => 2742, '11' => 3083,
              '12' => 3428, '13' => 3769, '14' => 4113, 'back' => 4455});
              
   &DisplayDebug(1, "GetCardImage ...   $Card   file: $$Cards{$Card}{'file'}");

   if (-e $$Cards{$Card}{'file'}) {
      foreach $_ (sort keys(%cardDeck)) {
         if ($$Cards{$Card}{'file'} =~ m/$cardDeck{$_}{'name'}/) {
            $deck = $_;
            last;
         }
      }
      &DisplayDebug(1, "GetCardImage deck: '$deck'");
      return undef if ($deck eq '');
        
      if ($$Cards{$Card}{'card'} eq 'back') {
         $x = $cardDeck{$deck}{'back'};
         $y = $cardDeck{$deck}{'b'}; 
      }
      elsif ($Card =~ m/(\d\d)(\w)/) {
         $x = $cardDeck{$deck}{'$1'};
         $y = $cardDeck{$deck}{'$2'}; 
      }
      else {
         return undef;   
      }
      &DisplayDebug(1, "GetCardImage x1: $x   y1: $y   " .
                       "x2: $cardDeck{$deck}{'width'}   " . 
                       "y2: $cardDeck{$deck}{'height'}");
                       
      $src = GD::Image->newFromPng($$Cards{$Card}{'file'});
      &DisplayDebug(1, "GetCardImage srcW: " . $src->width . "  srcH: " .
                    $src->height); 
      # Create an empty image with the desired dimensions.
      $out = GD::Image->new($cardDeck{$deck}{'width'}, $cardDeck{$deck}{'height'});
      # Extract the card image.
      $out->copy($src, 0, 0, $x, $y, $cardDeck{$deck}{'width'}, 
                 $cardDeck{$deck}{'height'});
      return $out;
   }
   return undef;   
}

# =============================================================================
# FUNCTION:  GenOpponent
#
# DESCRIPTION:
#    This routine is called to add opponent data to the game hash and add
#    working data for image based opponents.
#
# CALLING SYNTAX:
#    $result = &GenOpponent($Mw, $Game, $Res, $MsgData, $WorkingDir);
#
# ARGUMENTS:
#    $Mw             Main window object pointer.
#    $Game           Pointer to game hash.
#    $Res            Vertical screen size.
#    $MsgData        Pointer to message hash.
#    $WorkingDir     Game working directory path.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::opt_d, $main::opt_x, $main::Logfile
# =============================================================================
sub GenOpponent {
   my($Mw, $Game, $Res, $MsgData, $WorkingDir) = @_;
   my($data, @info);
   my($modelDir) = join('/', $WorkingDir, 'models');
   my(@defNames) = sort keys(%{ $$Game{'Opponent'} });

   &DisplayDebug(1, "GenOpponent ...   $Res   $WorkingDir");
   unless (-d $modelDir) {
      &ColorMessage("Directory not found: $modelDir", 'RED');
      return 1;
   }

   # These entries are added when the -s option is specified. They are
   # used to define the position and size of the game table player2
   # image. This definition (the hash exists) is also used by the 
   # program to indicate that player2 images are in use.
   if ($Res >= 2160) {
      $$Game{'Image'}{'Obj'} = 0; $$Game{'Image'}{'Width'} = 1550;
      $$Game{'Image'}{'Height'} = 1476; $$Game{'Image'}{'Relx'} = .177;
      $$Game{'Image'}{'Rely'} = .091; $$Game{'Image'}{'File'} = '';
      $$Game{'Image'}{'Felt'} = '';
   }
   elsif ($Res >= 1440) {
      $$Game{'Image'}{'Obj'} = 0; $$Game{'Image'}{'Width'} = 942;
      $$Game{'Image'}{'Height'} = 925; $$Game{'Image'}{'Relx'} = .177;
      $$Game{'Image'}{'Rely'} = .0905; $$Game{'Image'}{'File'} = '';
      $$Game{'Image'}{'Felt'} = '';
   }
   elsif ($Res >= 1080) {
      $$Game{'Image'}{'Obj'} = 0; $$Game{'Image'}{'Width'} = 775;
      $$Game{'Image'}{'Height'} = 738; $$Game{'Image'}{'Relx'} = .177;
      $$Game{'Image'}{'Rely'} = .091; $$Game{'Image'}{'File'} = '';
      $$Game{'Image'}{'Felt'} = '';
   }
   else {
      $$Game{'Image'}{'Obj'} = 0; $$Game{'Image'}{'Width'} = 510;
      $$Game{'Image'}{'Height'} = 490; $$Game{'Image'}{'Relx'} = .178;
      $$Game{'Image'}{'Rely'} = .109; $$Game{'Image'}{'File'} = '';
      $$Game{'Image'}{'Felt'} = '';
   }
   delete $$Game{'Opponent'};    # Remove existing opponents.
   
   # Prepare section of felt game table for use during image display.
   my($srcX) = int($$Game{'Main'}{'Width'} * $$Game{'Image'}{'Relx'});
   my($srcY) = int($$Game{'Main'}{'Height'} * $$Game{'Image'}{'Rely'});
   &GetFelt($Mw, $Game, \$data, $srcX, $srcY, 
      $$Game{'Image'}{'Width'}, $$Game{'Image'}{'Height'}, 
      $$Game{'Main'}{'BackImg'}, 'data');
   $$Game{'Image'}{'Felt'} = $data;  
   undef $data; 
   
   # Unzip default distribution file if necessary.
   my($defDir) = join('/', $modelDir, 'default');
   my($defZip) = join('/', $modelDir, 'default.zip');
   if (not -d $defDir and -e $defZip) {
      mkdir($defDir);
      return 1 if (&UnzipFile($defZip, $defDir));
      rename $defZip, join('-', $defZip, 'save');
   }
   # Setup default player images. 
   unless (defined($main::opt_x)) {
      foreach my $name (@defNames) {
         $$Game{'Opponent'}{$name}{0} = join("/", $defDir, "${name}-0.jpg");
         &DisplayDebug(2, "GenOpponent $name file: $$Game{'Opponent'}{$name}{0}");
      }
      return 0;
   }

   # -x option specified.
   my($file) = join('/', $modelDir, '0_models.txt');
   
   # Unzip opponent distribution file(s) if necessary.
   my(@zFiles) = glob ("$modelDir/*.zip");
   if (not -e $file and $#zFiles >= 0) {
      foreach my $zfile (@zFiles) {
         return 1 if (&UnzipFile($zfile, $modelDir));
         rename $zfile, join('-', $zfile, 'save');
      } 
   }

   # Setup working data.   
   $$MsgData{'01'} =~ s/Draw/Strip/;
   $$MsgData{'02'} =~ s/Draw/Strip/;
   foreach my $file (sort grep {/\.(png|jpg|jpeg)$/i} glob ("$modelDir/*")) {
      if ($file =~ m/models\/(.+)-(\d)/) {  
         # print "name $1, seq nmbr $2 \n";
         $$Game{'Opponent'}{$1}{$2} = $file unless (grep (/$1/,@defNames));
      }
   }
   if (-e $file) {
      if (open(INPUT, "<".$file)) {
         @info = <INPUT>;
         close(INPUT);
         foreach my $rec (@info) {
            chomp($rec);
            # print "rec: '$rec'\n";            
            next if ($rec =~ m/^#/ or $rec eq '');  # Skip comment records.
            my(@temp) = split(',', $rec);
            if (exists($$Game{'Opponent'}{$temp[0]})) {
               for (my $x = 1; $x <=$#temp; $x++) {
                  $$Game{'Opponent'}{$temp[0]}{'C'}{$x} = $temp[$x];
               }
            }
         }
      }
      &DisplayDebug(1, "GenOpponent count: " . scalar keys %{$$Game{'Opponent'}});
   }
   else {
      &ColorMessage("File not found: $file", 'RED');
      return 1;
   }
   
   # Report inconsistencies. Defaults are used for missing 0_models.txt record.
   # Model not selectable if missing image record.
   foreach my $key (keys(%{ $$Game{'Opponent'} })) {
      unless (exists($$Game{'Opponent'}{$key}{'C'})) {
         &ColorMessage("Model $key: no 0_models.txt record.", 'YELLOW');
      }
   }
   foreach my $rec (@info) {
      next if ($rec =~ m/^#/ or $rec eq '');     # Skip comment records.
      # print "rec: '$rec'\n";            
      my(@temp) = split(',', $rec);
      unless (exists($$Game{'Opponent'}{$temp[0]})) {
         &ColorMessage("0_models.txt $temp[0]: no image record.", 'YELLOW');
      }
   }

   # Establish clothing for player 1.
   my(%p1) = ('1' => 'hat,socks,cap', '2' => 'shirt,top,t-shirt', 
              '3' => 'pants,jeans,shorts', '4' => 'boxers,briefs');
   my(@items) = ();
   foreach my $key (sort keys(%p1)) {
      my(@temp) = split(',', $p1{$key});
      $$Game{'Player1'}{'Wear'}{$key} = $temp[int(rand(@temp))];
      push(@items, $$Game{'Player1'}{'Wear'}{$key});
   }            
   &DisplayDebug(1, "GenOpponent p1 items: @items");
   
   # Establish default for player 2. These will be overwritten if clothing 
   # items are available for the selected opponent. 
   my(%p2) = ('1' => 'shirt,top,peek', '2' => 'bra,better view', 
              '3' => 'pants,shorts', '4' => 'panties,undies');
   my(@items) = ();
   foreach my $key (sort keys(%p2)) {
      my(@temp) = split(',', $p2{$key});
      $$Game{'Player2'}{'Wear'}{$key} = $temp[int(rand(@temp))];
      push(@items, $$Game{'Player2'}{'Wear'}{$key});
   }            
   &DisplayDebug(1, "GenOpponent p2 items: @items");

   # Show hashes if running in debug mode.
   if ($main::opt_d == 3) {
      $Data::Dumper::Sortkeys = 1;
      $Data::Dumper::Terse = 1;
      if ($main::Logfile ne '') {
         open(my $FH, '>>', $main::Logfile);
         print $FH "Game{'Opponent'} ", Dumper($$Game{'Opponent'}), "\n";
         print $FH "Game{'Image'} ", Dumper($$Game{'Image'}), "\n";
         print $FH "Game{Player1'}{'Wear'} ", Dumper($$Game{'Player1'}{'Wear'}), "\n";
         print $FH "Game{Player2'}{'Wear'} ", Dumper($$Game{'Player2'}{'Wear'}), "\n";
         close($FH);
      }
      else {
         print "Game{'Opponent'} ", Dumper($$Game{'Opponent'}), "\n";
         print "Game{'Image'} ", Dumper($$Game{'Image'}), "\n";
         print "Game{Player1'}{'Wear'} ", Dumper($$Game{'Player1'}{'Wear'}), "\n";
         print "Game{Player2'}{'Wear'} ", Dumper($$Game{'Player2'}{'Wear'}), "\n";
      }
   }
   return 0;
}

# =============================================================================
# FUNCTION:  ItemMsg
#
# DESCRIPTION:
#    This routine returns a game message associated with the players current
#    loancount trend.
#
#    LoanCount and PreLoanCount are used to determine if a loan was taken and 
#    then paid back in the same hand. PreLoanCount is set to LoanCount during
#    the 'deal' state of each hand.
# 
# CALLING SYNTAX:
#    $msg = &ItemMsg($Game, $Player, $Trend);
#
# ARGUMENTS:
#    $Game            Pointer to the game hash.
#    $Player          'Player1' or 'Player2'.
#    $Trend           'payback' or 'loan'.
#
# RETURNED VALUES:
#    Message string.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ItemMsg {
   my($Game, $Player, $Trend) = @_;
   my($msg, $item);
   my(@p1Payback) = ("You won your %item% back.","You won't have your " .
      "%item% back for long.","Got your %item% back ... for now.","Aw, you " .
      "won back your %item%.");
   my(@p2Payback) = ('mystery','secrets','mystique','charms','allure');

   &DisplayDebug(1, "ItemMsg ...   $Player, $Trend");
   
   if ($Trend eq 'payback') {
      $item = $$Game{$Player}{'Wear'}{ $$Game{$Player}{'LoanCount'} +1};
      &DisplayDebug(1, "$Player LoanCount: " . $$Game{$Player}{'LoanCount'} .
         "   PreLoanCount: $$Game{$Player}{'PreLoanCount'}   item: '$item'");
      if ($Player eq 'Player1') {
         if ($$Game{$Player}{'LoanCount'} == $$Game{$Player}{'PreLoanCount'}) {
            $msg = "You keep your $item.";
         }
         else {
            $msg = $p1Payback[int(rand(@p1Payback))];
            $msg =~ s/%item%/$item/;
         }
      }
      elsif ($Player eq 'Player2') {
         if ($item =~ m/peek/ or  $item =~ m/tease/ or $item =~ m/view/) {
            $item = $p2Payback[int(rand(@p2Payback))];
         }
         # Item message.
         if ($$Game{$Player}{'LoanCount'} == $$Game{$Player}{'PreLoanCount'}) {
            $msg = "I keep my $item.";
         }
         else {   
            $msg = "I won back my $item.";
         }
      }
   }
   elsif ($Trend eq 'loan') {
      $item = $$Game{$Player}{'Wear'}{ $$Game{$Player}{'LoanCount'} };
      &DisplayDebug(1, "ItemMsg LoanCount: " . $$Game{$Player}{'LoanCount'} .
                       "   item: '$item'");
      if ($Player eq 'Player1') {
         $msg = "For \$100 you offer your $item.";
      }
      elsif ($Player eq 'Player2') {
         $msg = "For \$100 I offer my $item.";
         $msg =~ s/my/a/ if ($item =~ m/peek/ or  $item =~ m/tease/ or 
                             $item =~ m/view/);
      }
   }
   &DisplayDebug(2, "ItemMsg returned msg: '$msg'");
   return $msg;
}

# =============================================================================
# FUNCTION:  FindInListbox
#
# DESCRIPTION:
#    This routine is used to process keysym a..z input. The input letter is
#    used to move to the listbox entries that begin with the letter.
#
# CALLING SYNTAX:
#    $Mw->bind( "<Key-$key>" => [\&FindInListbox, $ListboxObj, $Letter] );
#
# ARGUMENTS:
#    $ListboxObj           Listbox object to process.
#    $Letter               Letter to find.
#
# RETURNED VALUES:
#    None
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub FindInListbox {
   my($ListboxObj, $Letter) = @_;

   my @list = $ListboxObj->get(0, "end");
   foreach (0 .. $#list) { 
      if ($list[$_] =~ /^$Letter/) {
         $ListboxObj->see($_);
         $ListboxObj->selectionClear(0, "end");
         $ListboxObj->selectionSet($_);
         last; 
      }
   }
   return;
}

# =============================================================================
# FUNCTION:  PotLabelColor
#
# DESCRIPTION:
#    This routine is used to set the color of the pot label to indicate when
#    additional player2 images are available. This is accomplished by changing
#    the hex color definition in the $Header hash for the label and then calling
#    &DisplayLabel. Left, Right, Up and Down are used by &ArrowKey. Pref and Bonus
#    are used by &exitGamePref and &StateMachine 'End'.
#
# CALLING SYNTAX:
#    $result = &PotLabelColor($Mw, $Game, $Header, $Key);
#
# ARGUMENTS:
#    $Mw             Main window object pointer.
#    $Game           Pointer to game hash.
#    $Header         Pointer to header hash.
#    $Key            Arrow key value.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub PotLabelColor {
   my($Mw, $Game, $Header, $Key) = @_;
   my($colorDefault) = '#DCDCDC';
   my($colorBlue) = '#AED6F1';
   my($potLabelIndex) = '05';

   &DisplayDebug(1, "PotLabelColor: Mw: '$Mw'   Key: '$Key'"); 
   if ($Key =~ m/Right$/ or $Key =~ m/End$/) { 
      # Use LoanCount to determine current image.      
      my($chkFile) = $$Game{'Opponent'}{ $$Game{'Player2'}{'Name'} }
                     { $$Game{'Player2'}{'LoanCount'} +1 };
      if (-e $chkFile) {           # Image available?
         $$Header{$potLabelIndex}{'color'} = $colorBlue;
      }
      else {
         $$Header{$potLabelIndex}{'color'} = $colorDefault;
      }
      &DisplayDebug(1, "PotLabelColor: set color: $$Header{$potLabelIndex}{'color'}"); 
      &DisplayLabel($Mw, $Game, $Header, $potLabelIndex);
   }
   elsif ($Key =~ m/Left$/ or $Key =~ m/Up$/ or $Key =~ m/Down$/ or $Key =~ m/Pref$/) {   
      if (exists($$Game{'Opponent'}{ $$Game{'Player2'}{'Name'} }{5}) and 
            $$Game{'Opponent'}{ $$Game{'Player2'}{'Name'} }{'C'}{5} =~ m/bonus/i) {
         $$Header{$potLabelIndex}{'color'} = $colorBlue;
      }
      else {
         $$Header{$potLabelIndex}{'color'} = $colorDefault;
      }
      &DisplayDebug(1, "PotLabelColor: set color: $$Header{$potLabelIndex}{'color'}"); 
      &DisplayLabel($Mw, $Game, $Header, $potLabelIndex);
   }
   return 0;
}
# =============================================================================
# FUNCTION:  UnzipFile
#
# DESCRIPTION:
#    This routine decompresses the user specified zip file. The output file(s)
#    are written to the specified output directory. An optional directory path
#    may be included for either argument. The current working directory is used
#    if not specified.
#
# CALLING SYNTAX:
#    $result = &UnzipFile($InputFile, $OutputDir);
#
# ARGUMENTS:
#    $InputFile       [path/]File to unzip.
#    $OutputDir       [path/]Directory for output.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub UnzipFile {
   my($InputFile, $OutputDir) = @_;
   my($status, $u, $fh, $buffer);
   
   &DisplayDebug(1, "UnzipFile ...  InputFile: $InputFile  OutputDir: $OutputDir");
# Check that output directory exists.
   unless (-e $OutputDir and -d $OutputDir) {
      &ColorMessage("UnzipFile: Directory not found: $OutputDir", 'BRIGHT_RED');
      return 1;
   }
# Open input file.
   unless ($u = IO::Uncompress::Unzip->new( $InputFile )) {
      &ColorMessage("UnzipFile: Can't open file: $InputFile. $!", 'BRIGHT_RED');
      return 1;
   }
# Decompress the input file.
   for ($status = 1; $status > 0; $status = $u->nextStream()) {
      my $header = $u->getHeaderInfo();
      my (undef, $path, $name) = splitpath($header->{Name});
      $name =~ s#/|\\$##;      
      my $destFile = join('/', $OutputDir, $name);
      &DisplayDebug(2, "UnzipFile: destFile: $destFile");
      unless ($fh = IO::File->new($destFile, "w")) {  # Open output file for write.
         &ColorMessage("UnzipFile: Can't open $destFile. $!", 'BRIGHT_RED');
         return 1;
      }
      $fh->binmode();
      while (($status = $u->read($buffer)) > 0) {
        $fh->write($buffer);
      }
      $fh->close();
      if ($status < 0) {
         &ColorMessage("UnzipFile: Error $destFile. $!", 'BRIGHT_RED');
         last;
      }
      unless (-e $destFile) {
         &ColorMessage("UnzipFile: $destFile not found.", 'BRIGHT_RED');
      }
   }
   undef $buffer;   # Free up memory.
   return 0;
}

# =============================================================================
# FUNCTION:  ArrowKey
#
# DESCRIPTION:
#    This routine is used to process the keysym code returned by the arrow
#    keys. Only the arrow keys are checked so as not to interfere with the 
#    Tk binding of other keys. The xev utility was used aide in initial code
#    developement.
#
# CALLING SYNTAX:
#    $Mw->bind('<KeyPress>' => [\&ArrowKey, $Mw, $Game, $Pref, $Header])
#
# ARGUMENTS:
#    $widget         Keysym object
#    $Mw             Toplevel object pointer.
#    $Game           Pointer to game hash.
#    $Pref           Pointer to preferences hash.
#    $Header         Pointer to header hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::opt_x
# =============================================================================
sub ArrowKey {
   my(@names);

   # Get arguments off calling stack. @_ is not used as it interferes with the
   # accessing of the keysym data.
   my($widget) = shift;
   my($Mw) = shift;
   my($Game) = shift;
   my($Pref) = shift;
   my($Header) = shift;
   
   my($e) = $widget->XEvent;
   my($keysym_text, $keysym_decimal) = ($e->K, $e->N);
   &DisplayDebug(1, "ArrowKey: $keysym_text   $$Game{'Player2'}{'Name'}" . 
      "   GameState: $$Game{'State'}");
   
   if ($keysym_text =~ m/Right$/ and defined($main::opt_x) and
      ($$Game{'State'} eq 'table' or $$Game{'State'} eq 'next' or
       $$Game{'State'} eq 'end')) {
      if ($$Game{'Player2'}{'LoanCount'} < 9) {
         $$Game{'Player2'}{'LoanCount'} += 1;
         my($file) = $$Game{'Opponent'}{ $$Game{'Player2'}{'Name'} }
                     { $$Game{'Player2'}{'LoanCount'} };
         if (-e $file) {            
            &DisplayImage($Mw, $Game);   # Display image
            &PotLabelColor($Mw, $Game, $Header, $keysym_text);
         }
         else {
            $$Game{'Player2'}{'LoanCount'} -= 1;
         }
      }   
   }
   elsif ($keysym_text =~ m/Left$/ and defined($main::opt_x) and
         ($$Game{'State'} eq 'table' or $$Game{'State'} eq 'next' or
          $$Game{'State'} eq 'end')) {
      $$Game{'Player2'}{'LoanCount'} -= 1 if ($$Game{'Player2'}{'LoanCount'} > 0);
      my($file) = $$Game{'Opponent'}{ $$Game{'Player2'}{'Name'} }
                  { $$Game{'Player2'}{'LoanCount'} };
      &DisplayImage($Mw, $Game) if (-e $file);
      &PotLabelColor($Mw, $Game, $Header, $keysym_text);
   }
   elsif ($keysym_text =~ m/Up$/) {
      if ($$Game{'State'} eq 'gamepref') {     # Opponent selection
         my($idx) = $$Pref{'p12'}{'obj'}->curselection;
         $idx -= 1 if ($idx > 0);
         $$Pref{'p12'}{'obj'}->see($idx);
         $$Pref{'p12'}{'obj'}->selectionClear(0, "end");
         $$Pref{'p12'}{'obj'}->selectionSet($idx);
         $$Game{'Player2'}{'Name'} = 
            $$Pref{'p12'}{'obj'}->get($$Pref{'p12'}{'obj'}->curselection());      
         $$Game{'Player2'}{'Name'} =~ s/^\s+|\s+$//g;
         if (exists($$Game{'Image'}{'Obj'})) {
            $$Pref{'p13'}{'file'} = $$Game{'Opponent'}{ $$Game{'Player2'}{'Name'} }{0}; 
            &DisplayCard($Mw, $Game, $Pref, 'p13');      # Show player image
         }
      }
      elsif (defined($main::opt_x) and ($$Game{'State'} eq 'table' or 
             $$Game{'State'} eq 'next' or $$Game{'State'} eq 'end')) {
         @names = sort keys(%{ $$Game{'Opponent'} });
         for (my $x = 0; $x <= $#names; $x++) {
            if ($names[$x] eq $$Game{'Player2'}{'Name'}) {
               if ($x > 0) {
                  $$Game{'Player2'}{'Name'} = $names[$x-1];
                  $$Game{'Player2'}{'LoanCount'} = 0;
                  # Update 'Wear'items.
                  my($name) = $$Game{'Player2'}{'Name'};
                  if (exists($$Game{'Opponent'}{$name}{'C'})) {
                     foreach my $i (keys(%{ $$Game{'Opponent'}{$name}{'C'} })) {
                        $$Game{'Player2'}{'Wear'}{$i} = $$Game{'Opponent'}
                           {$name}{'C'}{$i};
                     }
                  }
                  my($file) = $$Game{'Opponent'}{ $$Game{'Player2'}{'Name'} }
                              { $$Game{'Player2'}{'LoanCount'} };
                  &DisplayImage($Mw, $Game) if (-e $file);
                  &PotLabelColor($Mw, $Game, $Header, $keysym_text);
               }
               last;
            }
         }
      }        
   }
   elsif ($keysym_text =~ m/Down$/) {
      if ($$Game{'State'} eq 'gamepref') {     # Opponent selection
         my($last) = $$Pref{'p12'}{'obj'}->index('end') -1;
         my($idx) = $$Pref{'p12'}{'obj'}->curselection;
         $idx += 1 if ($idx < $last);
         $$Pref{'p12'}{'obj'}->see($idx);
         $$Pref{'p12'}{'obj'}->selectionClear(0, "end");
         $$Pref{'p12'}{'obj'}->selectionSet($idx);
         $$Game{'Player2'}{'Name'} = 
            $$Pref{'p12'}{'obj'}->get($$Pref{'p12'}{'obj'}->curselection());      
         $$Game{'Player2'}{'Name'} =~ s/^\s+|\s+$//g;
         if (exists($$Game{'Image'}{'Obj'})) {
            $$Pref{'p13'}{'file'} = $$Game{'Opponent'}{ $$Game{'Player2'}{'Name'} }{0}; 
            &DisplayCard($Mw, $Game, $Pref, 'p13');      # Show player image
         }
      }
      elsif (defined($main::opt_x) and ($$Game{'State'} eq 'table' or 
             $$Game{'State'} eq 'next' or $$Game{'State'} eq 'end')) {
         @names = sort keys(%{ $$Game{'Opponent'} });
         for ($x = 0; $x <= $#names; $x++) {
            if ($names[$x] eq $$Game{'Player2'}{'Name'}) {
               if ($x < $#names) {
                  $$Game{'Player2'}{'Name'} = $names[$x+1];
                  $$Game{'Player2'}{'LoanCount'} = 0;
                  # Update 'Wear'items.
                  my($name) = $$Game{'Player2'}{'Name'};
                  if (exists($$Game{'Opponent'}{$name}{'C'})) {
                     foreach my $i (keys(%{ $$Game{'Opponent'}{$name}{'C'} })) {
                        $$Game{'Player2'}{'Wear'}{$i} = $$Game{'Opponent'}
                           {$name}{'C'}{$i};
                     }
                  }
                  my($file) = $$Game{'Opponent'}{ $$Game{'Player2'}{'Name'} }
                              { $$Game{'Player2'}{'LoanCount'} };
                  &DisplayImage($Mw, $Game) if (-e $file);
                  &PotLabelColor($Mw, $Game, $Header, $keysym_text);
               }
               last;
            }
         }
      }      
   }
   elsif ($keysym_text eq 'less' and defined($main::opt_x)) {
      $$Game{'Player1'}{'LoanCount'} = 0;
      $$Game{'Player1'}{'Bankroll'} = 450;
      $$Game{'Player2'}{'LoanCount'} = $$Game{'LoanLimit'};
      $$Game{'Player2'}{'Bankroll'} = 50;
      $$Game{'GameEnd'} = 500;
      delete $$Game{'Image'}{'Bonus'} if (exists($$Game{'Image'}{'Bonus'}));
      &DisplayImage($Mw, $Game);
   }
   elsif ($keysym_text eq 'greater' and defined($main::opt_x)) {
      $$Game{'Player2'}{'LoanCount'} = 0;
      $$Game{'Player2'}{'Bankroll'} = 450;
      $$Game{'Player1'}{'LoanCount'} = $$Game{'LoanLimit'};
      $$Game{'Player1'}{'Bankroll'} = 50;
      $$Game{'GameEnd'} = 500;
      delete $$Game{'Image'}{'Bonus'} if (exists($$Game{'Image'}{'Bonus'}));
      &DisplayImage($Mw, $Game);
   }
   elsif ($keysym_text eq 'question' and defined($main::opt_x)) {
      &DisplayGameMsg($$Game{'Player1'}{'RankDebug'}, 'Player1', $Game, 1);
      &DisplayGameMsg($$Game{'Player2'}{'RankDebug'}, 'Player2', $Game, 1);
   }
   return;
}

1;
