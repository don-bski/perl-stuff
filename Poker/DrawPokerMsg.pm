# ============================================================================
# FILE: DrawPokerMsg.pm                                             2/08/2023
#
# SERVICES:  Provides draw poker gameplay messages
#
# DESCRIPTION:
#    This perl module provides draw poker gameplay messages. 
#
# PERL VERSION: 5.28.1
#
# =============================================================================
use strict;
# -----------------------------------------------------------------------------
# Package Declaration
# -----------------------------------------------------------------------------
package DrawPokerMsg;
require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
   GameMsg
);
use Storable qw(store retrieve dclone);

# =============================================================================
# FUNCTION:  GameMsg
#
# DESCRIPTION:
#    This module defines the game play interactive messages between the 
#    computer and player. The functions of perl module 'Storable' are used
#    to load the game play messages at program startup into a working hash.
#
#    %keyword% entries within the messages identify words/phrases that are
#    used to vary the program responses to the user. The keyword strings are
#    substituted by player specific dynamic data (e.g. player name). See 
#    the &DisplayGameMsg routine for supported keywords.
#
#    The %alt% keyword at the beginning of a message identifies two or more
#    alternates; seperated by %%. The &DisplayGameMsg routine will randomly
#    selects from the available alternatives.
#
# CALLING SYNTAX:
#    $result = &GameMsg($MsgData, $File);
#
# ARGUMENTS:
#    $MsgData             Pointer to working message hash.
#    $File                File containing program messages.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub GameMsg {
   my($MsgData, $File) = @_;
   my(%GameMsgs);

   if ($File ne '') {
      %GameMsgs = retrieve($File);
      return 1 unless (%GameMsgs);
   }
   else {
      %GameMsgs = (
         '00' => "\n===== Let's play draw poker! =====\n",
         '01' => "Shuffling ...",
         '02' => "\nThanks for the enjoyable game %name%.",
         '03' => "%alt%You've been a formitable poker opponent._You played " .
                 "a great game._I was a poor match for your poker skills.",
         '04' => "%alt%Better luck next time._Maybe you need some poker " .
                 "lessons._Next time I'll go easier with you.",
         '05' => "%name%, you have \$%bank%. Ante: ",
         '06' => "%alt%%name% is a worthy opponent._FYI, %name% has been on a " .
                 "winning streak._Good luck playing against %name%, you'll " .
                 "need it.",
         '07' => "%name%'s cards: ",
         '08' => "%name%, you have \$%bank%. Wager: ",
         '09' => "%name% sees your %see% and raises you: ",
         '10' => "%name% calls.",
         '11' => "%name% drops.",
         '12' => "%name% wins ",
         '13' => "%name% your credit is no longer accepted.",
         '14' => "Circuit overloaded! I need to cool down for a while.",
         '15' => "%name%, mark cards x to discard: ",
         '16' => "%name% replaced %value% cards.",
         '17' => "Press enter for another round or 0 to quit.",
         '18' => "Welcome to Five Card Draw Poker",
         '19' => "Gameplay:\n\nEach player starts with a \$100 bankroll. After " .
                 "each hand, the winning player is awarded the value in the pot. " .
                 "Up to four \$100 loans are credited to each player when their " .
                 "bankroll reaches \$0. The game ends when either player looses " .
                 "\$500.\n\nPlayers automatically ante \$5 at the start of a " .
                 "hand and have the opportunity to wager before and after card " .
                 "exchange. Players bet \$5 to \$25 and may raise the bet up to " .
                 "three times. Keyboard keys 1-5 can be used for bet entry.\n\n" .
                 "Use this window to select the desired game play options. " .
                 "Click OK when selections are complete to begin gameplay.",
         '20' => "%name% has:  %rank%",
      );
   }
      
   %$MsgData = %{ dclone(\%GameMsgs) };
   return 0;
}

return 1;
