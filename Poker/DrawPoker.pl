#!/usr/bin/perl
# ==============================================================================
# FILE: DrawPoker.pl                                                  4-01-2023
#
# SERVICES: Five Card Draw Poker  
#
# DESCRIPTION:
#   This program is a perl implementation of the card game five card draw
#   poker. Game play is between the computer and a single user. This version
#   is the initial proof of concept code. It is CLI based and targeted for 
#   linux terminals that support ANSI color.
#
# PERL VERSION:  5.28.1
# ==============================================================================

BEGIN {
   use Cwd;
   our ($ExecutableName) = ($0 =~ /([^\/\\]*)$/);
   our $WorkingDir = cwd();
   if (length($ExecutableName) != length($0)) {
      $WorkingDir = substr($0, 0, rindex($0, "/"));
   }
   unshift (@INC, $WorkingDir);
}

# -------------------------------------------------------------------------
# Seed random number generator.
srand(time);

# -------------------------------------------------------------------------
# External module definitions.
use Getopt::Std;
use Term::ANSIColor;
use Term::ReadKey;
use DrawPoker;
use DrawPokerMsg;
use Time::HiRes qw(sleep);

# -------------------------------------------------------------------------
# Global variables.
$MainRun = 1;          # Main loop control variable.
%MsgData = ();         # Gameplay messages
@DeckOfCards = ();     # Working card deck.
@Drawn = ();           # Cards currently drawn from deck.
@P1Hand = ();          # Current cards for player 1.
@P1Hold = ();          # Player 1 cards to hold.
@P2Hand = ();          # Current cards for player 2.
@P2Hold = ();          # Player 2 cards to hold.

$BankLoan = 100;       # Bank loan amount.
$LoanLimit = 4;        # Bank loan limit.
$RaiseLimit = 3;       # Bet raise limit.
$Pot = 0;              # Pot for each round.
$FirstBet = 1;         # Player making first bet. Alternates each game.

# The following hashs define gameplay working variables and player data.
%Player1 = ('Name' => 'Player', 'Bankroll' => 100, 'LoanCount' => 0,
            'Player' => '1', 'BankLoan' => $BankLoan, 'Value' => 0,
            'LoanLimit' => $LoanLimit, 'RaiseLimit' => $RaiseLimit,
            'HandRank' => '', 'OpponentBet' => 0);
%Player2 = ('Name' => 'Computer', 'Bankroll' => 100, 'LoanCount' => 0,
            'Player' => '2', 'BankLoan' => $BankLoan, 'Value' => 0,
            'LoanLimit' => $LoanLimit, 'RaiseLimit' => $RaiseLimit,
            'HandRank' => '', 'OpponentBet' => 0);

%Opponent = ('1' => {'Name' => 'Brian', 'Skill' => 5},
             '2' => {'Name' => 'Vicky', 'Skill' => 5},
             '3' => {'Name' => 'Mark', 'Skill' => 4},
             '4' => {'Name' => 'Ashley', 'Skill' => 3},
             '5' => {'Name' => 'Bob', 'Skill' => 3},
             '6' => {'Name' => 'Nadia', 'Skill' => 4});

# -------------------------------------------------------------------------
# Program help text.
$UsageText = (qq(
===== Help for $ExecutableName ================================================

GENERAL DESCRIPTION
   This program is a perl implementation of the card game five card draw
   poker. Game play is between the computer and a single user.
   
   Wagers are in \$5 increments, 0-\$25, using keyboard keys 0 and 1-5.
   
   Cards are held/unheld using keys 1-5. All cards are initially marked as
   held; H H H H H. Press of the corresponding key will toggle the card
   position between H and x. Cards marked x will be replaced when the enter
   key is pressed to confirm the selections.

USAGE:
   $ExecutableName  [-h] [-q] [-d <lvl>] [-a] [-t]
   
   -h             Displays program usage text.
   -q             Suppress all program message output.
   -d <lvl>       Run at specified debug level; 0-3.
   
   -a             Auto-ante \$5.
   -t             Show cards as text. Default is symbols (unicode).

EXAMPLES:
   $ExecutableName -a

===============================================================================
));

# =============================================================================
# MAIN PROGRAM
# =============================================================================
# Process user specified CLI options.
getopts("hqatd:");

# ==========
# Display program help if -h specified.
if (defined($opt_h)) {
	 print"$UsageText\n";
	 exit(0);  
}

# ==========
# Setup for processing keyboard entered signals.                              
foreach ('INT','QUIT','TERM') {     # Catch termination signals
   $SIG{$_} = \&Ctrl_C;
}

# ==========
# Setup gameplay messages.                              
if (&GameMsg(\%MsgData, '')) {
   &DisplayMessage("Can't load gameplay messages.");
   exit(1);
}
else {
   &DisplayGameMsg($MsgData{'00'}, BRIGHT_YELLOW);  # Welcome
   sleep 1;
}

# ==========
# Get player names. 
&PlayerNames(\%Player1, \%Player2, \%Opponent, \%MsgData);

# ==========
# Enable program keyboard input and clear input buffer.
ReadMode('cbreak');                  
while (defined($char = ReadKey(-1))) {};

# ==========
# Load a new deck of cards.
&DisplayGameMsg("New deck of cards.", BRIGHT_YELLOW);
$result = &Newdeck(\@DeckOfCards);
$dPos = &Shuffle(\@DeckOfCards, int(rand(5))+1);   # Initial shuffle

# ==========
# Start main game loop. Loop is exit by:
#    1. User entered ante of $0 or Enter key.
#    2. Either player negative bankroll after $LoanLimit loans.
#
while ($MainRun) {
   
   # ==========
   # Shuffle the cards. Start position in deck returned.
   &DisplayGameMsg($MsgData{'01'}, YELLOW);  # Shuffling
   $dPos = &Shuffle(\@DeckOfCards);
   &DisplayDebug(3, "dPos: $dPos");
   &DisplayGameMsg("");     
   sleep 1;

   # ==========
   # Ante up.
   $anteResult = &PlayerAnte(\$Pot, $FirstBet, \%Player1, \%Player2, \%MsgData);
   if ($anteResult == 0) {
      &DisplayGameMsg("\nPot: ", BRIGHT_YELLOW, '', 'nocr');
      &DisplayGameMsg("\$" . $Pot,'BRIGHT_GREEN');
      &DisplayGameMsg("");     
      
      # ==========
      # Draw cards.
      $dPos = &DrawCards(\@DeckOfCards, $dPos, \@P1Hand, \@P2Hand);
      &DisplayDebug(3, "dPos: $dPos");
      
      # ==========
      # Score hands for first betting round.
      $P1Rank = &RankHand(\@P1Hand, \%Player1);
      &DisplayDebug(2, "$Player1{'Name'} cards: @P1Hand   rank: $P1Rank");
      $P2Rank = &RankHand(\@P2Hand, \%Player2);
      &DisplayDebug(2, "$Player2{'Name'} cards: @P2Hand   rank: $P2Rank");
   
      # ==========
      # Show player 1 cards for first betting round.
      &DisplayGameMsg($MsgData{'07'}, BRIGHT_YELLOW, \%Player1, 'nocr');
      if (defined($opt_t)) {
         &DisplayGameMsg("@P1Hand - ",'BRIGHT_WHITE', \%Player1, 'nocr');
         &DisplayGameMsg("$Player1{'HandRank'}");
      }
      else {
         &DisplayGameMsg("$Player1{'HandRank'}");
         $result = &DisplayCards(\@P1Hand);
      }
      &DisplayGameMsg("");     
     
      # ==========
      # Place first bets.
      $betState = &PlayerBet(\$Pot, $FirstBet, \%Player1, \%Player2, \%MsgData);
      
      if ($betState eq 'end1') {
         &DisplayGameMsg($MsgData{'13'}, BRIGHT_YELLOW, \%Player1, '');
      }
      elsif ($betState eq 'drop1') {
         $Player1{'HandRank'} = '';
      }
      elsif ($betState eq 'end2') {
         &DisplayGameMsg($MsgData{'14'}, BRIGHT_YELLOW, \%Player2, '');
      }
      elsif ($betState eq 'drop2') {
         $Player2{'HandRank'} = '';
      }
      sleep 1;
      
      unless ($betState =~ m/^end\d/ or $betState =~ m/^drop\d/) {
         
         # ==========
         # Select cards to exchange.
         &DisplayGameMsg("");
         $p1HoldCount = &SelectHold(\@P1Hand, \@P1Hold, \%Player1, \%MsgData);
         # $Player1{'Value'} = 5 - $p1HoldCount;
         # &DisplayGameMsg($MsgData{'16'}, BRIGHT_YELLOW, \%Player1, '');
         
         $p2HoldCount = &AutoHold(\@P2Hand, \@P2Hold, \%Player2);
         $Player2{'Value'} = 5 - $p2HoldCount;
         &DisplayGameMsg($MsgData{'16'}, BRIGHT_YELLOW, \%Player2, '');
         &DisplayGameMsg("");
      
         &DisplayDebug(1, "$Player1{'Name'} hold:  @P1Hold");
         &DisplayDebug(1, "$Player2{'Name'} hold:  @P2Hold");
         
         # ==========
         # Change cards.
         $dPos = &ChangeCards(\@DeckOfCards, $dPos, \@P1Hand, \@P1Hold);
         $dPos = &ChangeCards(\@DeckOfCards, $dPos, \@P2Hand, \@P2Hold);
         
         # ==========
         # Score hands.
         $P1Rank = &RankHand(\@P1Hand, \%Player1);
         &DisplayDebug(2, "$Player1{'Name'} cards: @P1Hand   rank: $P1Rank");
         $P2Rank = &RankHand(\@P2Hand, \%Player2);
         &DisplayDebug(2, "$Player2{'Name'} cards: @P2Hand   rank: $P2Rank");
      
         # ==========
         # Show player 1 cards for second betting round.
         &DisplayGameMsg($MsgData{'07'}, BRIGHT_YELLOW, \%Player1, 'nocr');
         if (defined($opt_t)) {
            &DisplayGameMsg("@P1Hand - ",'BRIGHT_WHITE', \%Player1, 'nocr');
            &DisplayGameMsg("$Player1{'HandRank'}");
         }
         else {
            &DisplayGameMsg("$Player1{'HandRank'}");
            $result = &DisplayCards(\@P1Hand);
         }
         &DisplayGameMsg("");     
        
         # ==========
         # Place second bets.
         $betState = &PlayerBet(\$Pot, $FirstBet, \%Player1, \%Player2, \%MsgData);
         
         if ($betState eq 'end1') {
            &DisplayGameMsg($MsgData{'13'}, BRIGHT_YELLOW, \%Player1, '');
         }
         elsif ($betState eq 'drop1') {
            $Player1{'HandRank'} = '';
         }
         elsif ($betState eq 'end2') {
            &DisplayGameMsg($MsgData{'14'}, BRIGHT_YELLOW, \%Player2, '');
         }
         elsif ($betState eq 'drop2') {
            $Player2{'HandRank'} = '';
         }
         sleep 1;
      
         unless ($betState =~ m/^end\d/ or $betState =~ m/^drop\d/) {
      
            # ==========
            # Show player 2 cards.
            &DisplayGameMsg("");
            &DisplayGameMsg($MsgData{'07'}, BRIGHT_YELLOW, \%Player2, 'nocr');
            if (defined($opt_t)) {
               &DisplayGameMsg("@P2Hand - ", BRIGHT_WHITE, \%Player2, 'nocr');
               &DisplayGameMsg("$Player2{'HandRank'}");
            }
            else {
               &DisplayGameMsg("$Player2{'HandRank'}");
               $result = &DisplayCards(\@P2Hand);
            }
         }
         &DisplayGameMsg("");
      }    
   }

   # ==========
   # Declair game outcome.
   my($winner) = &Winner(\%Player1, \@P1Hand, \%Player2, \@P2Hand);
   if ($winner eq 'Player1' or $anteResult == 2) {
      &DisplayGameMsg($MsgData{'12'}, BRIGHT_YELLOW, \%Player1, 'nocr');
      $Player1{'Bankroll'} += $Pot;
   }
   elsif ($winner eq 'Player2' or $anteResult == 1) {
      &DisplayGameMsg($MsgData{'12'}, BRIGHT_YELLOW, \%Player2, 'nocr');
      $Player2{'Bankroll'} += $Pot;
   }
   else {
      &DisplayMessage("Draw game.");
   }

   &DisplayGameMsg("\$" . $Pot,'BRIGHT_GREEN');
   &DisplayGameMsg("");     
   $Pot = 0;      # Pot was awarded to the winner.
      
   # ==========
   # Update/check players bankroll. End game if either is disapproved for $1.
   # This also updates the bankroll if the user has > $100 and a non-zero
   # LoadCount.
   if (&CheckBankroll(1, \%Player1) == -1) {
      &DisplayGameMsg($MsgData{'13'}, BRIGHT_YELLOW, \%Player1, '');
      last;
   }
   if (&CheckBankroll(1, \%Player2) == -1) {
      &DisplayGameMsg($MsgData{'14'}, BRIGHT_YELLOW, \%Player2, '');
      last;
   }
  
   # ==========
   # Move used cards to end of deck.
   @temp = splice(@DeckOfCards, 0, $dPos);
   push(@DeckOfCards, @temp);
   $dPos = 0;

   # ==========
   # Alternate first bet player.
   if ($FirstBet == 1) {
      $FirstBet = 2;
   }
   else {
      $FirstBet = 1;
   }
   
   &DisplayGameMsg($MsgData{'17'}, BRIGHT_YELLOW);
   sleep .1 while (($key = &GetKeyboardInput()) == 0);
   last if ($key == 48);                      # End looping if 0.
   &DisplayGameMsg("");     
}

ReadMode('normal');             # Restore default keyboard behavior.

&DisplayGameMsg($MsgData{'02'}, BRIGHT_YELLOW, \%Player1);  # Thanks
if ($P1Score > $P2Score) {
   &DisplayGameMsg($MsgData{'03'}, YELLOW);  # Awesome
}
else {
   &DisplayGameMsg($MsgData{'04'}, YELLOW);  # Better luck
}
&DisplayMessage("");

exit(0);
