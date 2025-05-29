# ============================================================================
# FILE: DrawPoker.pm                                                3/27/2023
#
# SERVICES:  Functions that support draw poker
#
# DESCRIPTION:
#    This perl module provides draw poker related functions. 
#
# PERL VERSION: 5.28.1
#
# =============================================================================
use strict;
# -----------------------------------------------------------------------------
# Package Declaration
# -----------------------------------------------------------------------------
package DrawPoker;
require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
   Newdeck
   Shuffle
   DrawCards
   RankHand
   Winner
   SelectHold
   AutoHold
   ChangeCards
   PlayerAnte
   PlayerBet
   ProcessPlayerBet
   ComputerBet
   CheckBankroll
   PlayerNames
   GetKeyboardInput
   Ctrl_C
   DisplayMessage
   DisplayDebug
   ColorMessage
   DisplayGameMsg
   DisplayCards
);

use Term::ANSIColor;
use utf8;
use Term::ReadKey;
use Storable qw(store retrieve dclone);
#use DrawPokerMsg;

# =============================================================================
# FUNCTION:  Newdeck
#
# DESCRIPTION:
#    This routine loads the specified array with a full deck of cards. Cards
#    are set in 'new pack' order. Card values are as follows.
#
#     A   2   3   4   5   6   7   8   9  10   J   Q   K
#    14c 02c 03c 04c 05c 06c 07c 08c 09c 10c 11c 12c 13c  clubs
#    14h 02h 03h 04h 05h 06h 07h 08h 09h 10h 11h 12h 13h  hearts
#    14d 02d 03d 04d 05d 06d 07d 08d 09d 10d 11d 12d 13d  diamonds
#    14s 02s 03s 04s 05s 06s 07s 08s 09s 10s 11s 12s 13s  spades
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

   &DisplayDebug(1, "Newdeck ...");

   @$Deck = ();
   foreach my $suit ('c','h','d','s') {
      foreach my $value ('14','02','03','04','05','06','07',
                         '08','09','10','11','12','13') {
         push (@$Deck, join('', $value, $suit));
      }
   }
   &DisplayDebug(3, "Newdeck: '@$Deck'");
   return 0;
}

# =============================================================================
# FUNCTION:  Shuffle
#
# DESCRIPTION:
#    This routine shuffles the specified array of cards using the Fisher-Yates
#    shuffle algorithm.
#
# CALLING SYNTAX:
#    $dPos = &Shuffle(\@Deck, $Iter);
#
# ARGUMENTS:
#    $Deck          Pointer to working deck array.
#    $Iter          Number of shuffle iterations; default random 5-15
#
# RETURNED VALUES:
#    0 = top card of the deck
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub Shuffle {
   my($Deck, $Iter) = @_;
   my($i, $j, $k, @temp);
   
   $Iter = 5 + int(rand(11))+1 if ($Iter eq '');

   &DisplayDebug(1, "Shuffle $Iter ...");
   
   if ($#$Deck > -1) {
      &DisplayDebug(3, "Shuffle, pre-shuffle: '@$Deck'");
      $k = @$Deck;                                   # Get the deck length.
      while ($Iter--) {
         $i = $k;
         while (--$i) {
            $j = int rand ($i + 1);
            @$Deck[$i,$j] = @$Deck[$j,$i];
         }
         @temp = splice(@$Deck, 0, int(rand($k)));   # Random deck cut.
         push (@$Deck, @temp); 
      }
      &DisplayDebug(3, "Shuffle, post-shuffle: '@$Deck'");
   }
   return 0;
}

# =============================================================================
# FUNCTION:  DrawCards
#
# DESCRIPTION:
#    This routine draws five cards from the specified deck for each player.
#    Cards are drawn from the top of the deck and stored in each player's
#    @Hand array. 
#
# CALLING SYNTAX:
#    $Dpos = &DrawCards(\@Deck, $Dpos, \@P1Hand, \@P2Hand);
#
# ARGUMENTS:
#    $Deck          Pointer to working deck array.
#    $Dpos          Position in card array.
#    $P1Hand        Pointer to player 1 hand array.
#    $P2Hand        Pointer to player 2 hand array.
#
# RETURNED VALUES:
#    Updated position in deck.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub DrawCards {
   my($Deck, $Dpos, $P1Hand, $P2Hand) = @_;
   my($player) = 0;

   &DisplayDebug(1, "DrawCards ...");

   @$P1Hand = ();   @$P2Hand = ();  
   foreach (1 .. 10) {
      if ($_ % 2 == 1) {
         push (@$P1Hand, $$Deck[$Dpos++]);
      }
      else {
         push (@$P2Hand, $$Deck[$Dpos++]);
      }
   }
   # Test data injection point.
   # @$P1Hand = ('02c','02s','04c','07h','08d');
   # @$P2Hand = ('11c','11d','12c','13h','13d');
   
   @$P1Hand = sort(@$P1Hand);
   @$P2Hand = sort(@$P2Hand);
   &DisplayDebug(3, "P1Hand: @$P1Hand");
   &DisplayDebug(3, "P2Hand: @$P1Hand");
   
   return $Dpos;
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
# CALLING SYNTAX:
#   $rank = &RankHand($Hand, $Player);
#
# ARGUMENTS:
#    $Hand          Pointer to card array.
#    $Player        Pointer to player hash
#
# RETURNED VALUES:
#    Poker rank.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub RankHand {
   my($Hand, $Player) = @_;
   my($rank) = '';   my(@tallyR) = ();
   my(@straight) = ('0203040514','0203040506','0304050607','0405060708','0506070809',
                    '0607080910','0708091011','0809101112','0910111213','1011121314');
   my(%xlat) = ('02' => '2', '03' => '3', '04' => '4', '05' => '5', '06' => '6',
                '07' => '7', '08' => '8', '09' => '9', '10' => 'T', '11' => 'J',
                '12' => 'Q', '13' => 'K', '14' => 'A');

   &DisplayDebug(1, "RankHand ...   @$Hand");
   my($value) = join('', sort @$Hand);
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
         if ($rank eq 'Flush') {                # All same suit
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
         my(@check) = grep(/${i}c|${i}d|${i}h|${i}s/, @$Hand);
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
   $$Player{'HandRank'} = $rank;
   &DisplayDebug(1, "RankHand rank:  $$Player{'HandRank'}");
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
#   $winner = &Winner(\%Player1, \@P1Hand, \%Player2, \@P2Hand);
#
# ARGUMENTS:
#    $Player1        Pointer to Player1 hash
#    $Player2        Pointer to Player2 hash
#
# RETURNED VALUES:
#    'Player1', 'Player2', or 'Draw'
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub Winner {
   my($Player1, $P1Hand, $Player2, $P2Hand) = @_;
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
   &DisplayDebug(2, "Winner p1 hand: '@$P1Hand'");
   &DisplayDebug(2, "Winner p2 hand: '@$P2Hand'");
  
   # Do a basic rank check. Higher rank wins.
   foreach my $rank (sort keys(%ranks)) {
      $p1Rank = $rank if ($$Player1{'HandRank'} =~ m/^$ranks{$rank}/);
      $p2Rank = $rank if ($$Player2{'HandRank'} =~ m/^$ranks{$rank}/);
      last if ($p1Rank ne '' and $p2Rank ne '');
   }
   &DisplayDebug(2, "Winner p1Rank: '$p1Rank'   p2Rank: '$p2Rank'");
   return 'Player1' if ($p1Rank > $p2Rank);
   return 'Player2' if ($p1Rank < $p2Rank);
  
   # Ranks are the same so more detailed checks are needed.
   $p1Cards = join('', reverse sort @$P1Hand); 
   $p1Cards =~ s/[cdhs]//g;       # Remove suit characters.
   $p2Cards = join('', reverse sort @$P2Hand); 
   $p2Cards =~ s/[cdhs]//g;       # Remove suit characters.
   &DisplayDebug(2, "Winner p1Cards: '$p1Cards'   p2Cards: '$p2Cards'");

   # High-Card or Straight or Flush or Straight-Flush
   if ($p1Rank == 0 or $p1Rank == 4 or $p1Rank == 5 or $p1Rank == 8) {
      return 'Player1' if ($p1Cards gt $p2Cards);
      return 'Player2' if ($p1Cards lt $p2Cards);
   }
   # One-Pair J's or Three-of-a-Kind J's or Four-of-a-Kind J's
   elsif ($p1Rank == 1 or $p1Rank == 3 or $p1Rank == 7) {
      $p1Val1 = $xlat{ substr($$Player1{'HandRank'}, -3, 1) };
      $p2Val1 = $xlat{ substr($$Player2{'HandRank'}, -3, 1) };
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
      $p1Val1 = $xlat{ substr($$Player1{'HandRank'}, -7, 1) }; # High value
      $p2Val1 = $xlat{ substr($$Player2{'HandRank'}, -7, 1) }; # High value
      $p1Val2 = $xlat{ substr($$Player1{'HandRank'}, -3, 1) }; # Low value
      $p2Val2 = $xlat{ substr($$Player2{'HandRank'}, -3, 1) }; # Low value
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
# FUNCTION:  SelectHold
#
# DESCRIPTION:
#    This routine gets user keyboard input for the cards to hold in the 
#    specified @Hand. The corresponding @Hold array locations are set to 1.
#
#    Keyboard keys 1 - 5 correspond to the as displayed card order. Each key
#    can be pressed to toggle the card's hold state. The Enter key confirms
#    the selections.  
#
# CALLING SYNTAX:
#    $holdCount = &SelectHold(\@Hand, \@Hold, \%Player, \%MsgData);
#
# ARGUMENTS:
#    $Hand          Pointer to player hand array.
#    $Hold          Pointer to player hold array.
#    $Player        Pointer to player hash.
#    $MsgData       Pointer to message hash.
#
# RETURNED VALUES:
#    Number of cards held.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::MainRun
# =============================================================================
sub SelectHold {
   my($Hand, $Hold, $Player, $MsgData) = @_;
   my($work, $bspc, $hCnt);
   my($key) = 0;
   
   &DisplayDebug(1, "SelectHold ...  @$Hand");   
   @$Hold = (1,1,1,1,1);                          # Default hold all cards.
   
   &DisplayGameMsg($$MsgData{'15'},'BRIGHT_YELLOW',$Player,'nocr');
   while ($main::MainRun) {      # Break out if program ctrl+c abort.
      ($work, $bspc, $hCnt) = ('','',0);
      foreach (@$Hold) {
         if ($_ == 1) {
            $work = join('', $work, 'H ');
            $hCnt++;
         }
         else {
            $work = join('', $work, 'x ');
         }
         $bspc = join('', $bspc, "\b\b")
      }
      &DisplayGameMsg("$work",'WHITE',$Player,'nocr');
      sleep .1 while (($key = &GetKeyboardInput()) == 0);

      # GetKeyboardInput filters for 0-5 and enter.
      last if ($key == 10 or $key == 48);      # End looping if enter or 0.
      $key = $key - 49;                        # array index 0-4
      if ($$Hold[$key] == 0) {
         $$Hold[$key] = 1;
      }
      else {
         $$Hold[$key] = 0;
      }
      &DisplayGameMsg("$bspc",'WHITE',$Player,'nocr');
   }
   &DisplayGameMsg("");
   return $hCnt;
}

# =============================================================================
# FUNCTION:  AutoHold
#
# DESCRIPTION:
#    This routine determines the cards to hold and sets the corresponding 
#    @Hold array locations to 1. Depends on sorted @Hand done by DrawCards.
#
# CALLING SYNTAX:
#    $result = &AutoHold(\@Hand, \@Hold, \%Player);
#
# ARGUMENTS:
#    $Hand          Pointer to player hand array.
#    $Hold          Pointer to player hold array.
#    $Player        Pointer to player hash for HandRank
#
# RETURNED VALUES:
#    Number of cards held.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub AutoHold {
   my($Hand, $Hold, $Player) = @_;
   my($suits, $values, $count, @temp);
   
   &DisplayDebug(1, "AutoHold ...  @$Hand");   
   @$Hold = (0,0,0,0,0);     # Default change all cards.

   if ($$Player{'HandRank'} =~ m/Royal-Flush/i or 
       $$Player{'HandRank'} =~ m/Straight-Flush/i or
       $$Player{'HandRank'} =~ m/Four-of-a-Kind/i or 
       $$Player{'HandRank'} =~ m/Full-House/i or
       $$Player{'HandRank'} =~ m/Flush/i or 
       $$Player{'HandRank'} =~ m/Straight/i) {
      @$Hold = (1,1,1,1,1);  # Hold all cards; stand pat
      return 5;
   }
   if ($$Player{'HandRank'} =~ m/Three-of-a-Kind/i) {
      # Find three of a kind and hold it.
      foreach (0..2) {
         if (substr($$Hand[$_],0,2) eq substr($$Hand[$_+1],0,2) and
             substr($$Hand[$_+1],0,2) eq substr($$Hand[$_+2],0,2)) {
            $$Hold[$_] = 1;
            $$Hold[$_+1] = 1;
            $$Hold[$_+2] = 1;
            return 3;
         }
      }
   }
   if ($$Player{'HandRank'} =~ m/Two-Pair/i) {
      # Find pairs and hold them.
      foreach (0..3) {
         if (substr($$Hand[$_],0,2) eq substr($$Hand[$_+1],0,2)) {
            $$Hold[$_] = 1;
            $$Hold[$_+1] = 1;
         }
      }
      return 4;
   }
   if ($$Player{'HandRank'} =~ m/One-Pair/i) {
      # Find pair and hold it.
      foreach (0..3) {
         if (substr($$Hand[$_],0,2) eq substr($$Hand[$_+1],0,2)) {
            $$Hold[$_] = 1;
            $$Hold[$_+1] = 1;
            return 2;
         }
      }
   }

   # Find 3-4 cards of flush
   $suits = join('', @$Hand);
   $suits =~ s/\d//g;
   foreach ('c','d','h','s') {
      $count = ($suits =~ tr/$_//);
      if ($count > 2) {
         $suits =~ s/$_/1/g;
         $suits =~ s/[cdhs]/0/g;
         @$Hold = split('', $suits);
         return $count;
      }
   }
   
   # Find 3-4 of straight
   $values = join('', @$Hand);
   $values =~ s/[cdhs]//g; 
   @temp = ($values =~ m/../g);
   foreach (0..2) {
      if (($temp[$_] +1) == $temp[$_+1] and ($temp[$_+1] +1) == $temp[$_+2]) {
         $$Hold[$_] = 1;
         $$Hold[$_+1] = 1;
         $$Hold[$_+2] = 1;
      # Check for 4th card
         if (($temp[$_+2] +1) == $temp[$_+3]) {      
            $$Hold[$_+3] = 1;
            return 4;
         }
         return 3;
      }
   }

   # High card is always the last. Keep it if > 9.
   if (substr($$Hand[-1],0,2) > 9) { 
      $$Hold[-1] = 1;
      return 1;
   }
   return 0;   # Replace all cards.
}

# =============================================================================
# FUNCTION:  ChangeCards
#
# DESCRIPTION:
#    This routine replaces cards based on the setting of the players @Hold
#    array. Cards are drawn from the deck and stored into the players @Hand
#    array overwritting the previous card. A card is replaced if its coores-
#    ponding @Hold location is 0. 
#
# CALLING SYNTAX:
#    $Dpos = &ChangeCards(\@Deck, $Dpos, \@Hand, \@Hold);
#
# ARGUMENTS:
#    $Deck          Pointer to working deck array.
#    $Dpos          Position in card array.
#    $Hand          Pointer to player hand array.
#    $Hold          Pointer to player hold array.
#
# RETURNED VALUES:
#    Updated position in deck.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ChangeCards {
   my($Deck, $Dpos, $Hand, $Hold) = @_;

   &DisplayDebug(1, "ChangeCards ...");

   foreach (0 .. 4) {
      $$Hand[$_] = $$Deck[$Dpos++] if ($$Hold[$_] == 0);
   }
   @$Hand = sort(@$Hand);
   return $Dpos;
}

# =============================================================================
# FUNCTION:  PlayerAnte
#
# DESCRIPTION:
#    This routine gets each player's ante of $5. The pot and player bankrolls
#    are updated. The player's bankroll is loaned the $BankLoan amount up to
#    $LoanLimit times for a negative balance.
#
#    The -a program option ($opt_a) will cause auto-ante operation. Ante will
#    occur without manual action.
#
#    If $loanlimit is reached or an ante of $0 is entered, the terminate game
#    return is used.
#
# CALLING SYNTAX:
#    $result = &PlayerAnte(\$Pot, $FirstAnte, \%Player1, \%Player2, \%MsgData);
#
# ARGUMENTS:
#    $Pot           Pointer to betting pot.
#    $FirstAnte     Which player antes first; 1 or 2.
#    $Player1       Pointer to player 1 hash.
#    $Player2       Pointer to player 2 hash.
#    $MsgData       Pointer to message hash.
#
# RETURNED VALUES:
#    0 = both players ante, 1 or 2 = player drop.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::opt_a
# =============================================================================
sub PlayerAnte {
   my($Pot, $FirstAnte, $Player1, $Player2, $MsgData) = @_;
   my(@anteOrder);
   my($amount) = 5;                                 # Ante amount
   my($ante, $key);

   &DisplayDebug(1, "PlayerAnte ...");

   # Determine ante order.   
   if ($FirstAnte == 1) {
      @anteOrder = ($Player1, $Player2);
   }
   else {
      @anteOrder = ($Player2, $Player1);
   }

   # Get each players ante.
   foreach my $player (@anteOrder) {
      ($ante, $key) = (0,0);
      return 1 if (&CheckBankroll($amount, $player) == -1);  # Insufficient funds.
      
      if (defined($main::opt_a) or $$player{Player} eq '2') {         
         &DisplayGameMsg($$MsgData{'05'},'BRIGHT_YELLOW',$player,'nocr');
         $ante = $amount;
         &DisplayGameMsg("$ante");
         sleep .75;
      }
      else {
         &DisplayGameMsg($$MsgData{'05'},'BRIGHT_YELLOW',$player,'nocr');
         sleep .1 while (($key = &GetKeyboardInput()) == 0);

         # GetKeyboardInput filters for 0-5 and enter.
         unless ($key == 10 or $key == 48) {     # Not enter or 0.
            $ante = $amount;                     # Key 1-5 is $amount
         }
         &DisplayGameMsg("$ante");               # Echo ante amount
         return 1 if ($ante == 0);
      }

      $$player{'Bankroll'} -= $ante;
      $$Pot += $ante;
      &DisplayDebug(2, "$$player{'Name'} ante: $ante   bankroll: " .
                        $$player{'Bankroll'});
   }
   return 0;
} 

# =============================================================================
# FUNCTION:  PlayerBet
#
# DESCRIPTION:
#    This routine gets each player's bet. The pot and player bankrolls are
#    updated. The player's bankroll is loaned the $BankLoan amount up to
#    $LoanLimit times for a negative balance.
#
#    FirstBet specifies which player bets first. During betting, if a
#    loanlimit is reached, a 'drop' occurs.
#
#    $betState controls the betting loop, 'bet', 'raise', 'call' or 'drop'.
#
# CALLING SYNTAX:
#    $betState = &PlayerBet(\$Pot, $FirstBet, \%Player1, \%Player2, \%MsgData)
#
# ARGUMENTS:
#    $Pot           Pointer to betting pot.
#    $FirstBet      Which player bets first; 1 or 2.
#    $Player1       Pointer to player 1 hash.
#    $Player2       Pointer to player 2 hash.
#    $MsgData       Pointer to message hash.
#
# RETURNED VALUES:
#    $betState
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub PlayerBet {
   my($Pot, $FirstBet, $Player1, $Player2, $MsgData) = @_;
   my($key, $bet, $see, $newState);
   my($bettor) = $FirstBet;
   my($betState) = 'bet';
   my($raiseCount) = 0; 

   &DisplayDebug(1, "PlayerBet ...   first bet Player $bettor");

   while ($betState ne 'call' and $betState ne 'drop') {
      ($key, $bet, $see) = (0,0,0);
      $newState = '';
      $raiseCount++ if ($betState eq 'raise');
      &DisplayDebug(1, "PlayerBet ...   raiseCount: $raiseCount   bettor: $bettor -----");
      if ($bettor == 1) {         
         if ($betState eq 'raise') {
            $see = $$Player1{'OpponentBet'};
            &DisplayGameMsg($$MsgData{'09'},'BRIGHT_YELLOW',$Player1, 'nocr');
         }
         else {
            &DisplayGameMsg($$MsgData{'08'},'BRIGHT_YELLOW',$Player1,'nocr');
         }
         sleep .1 while (($key = &GetKeyboardInput()) == 0);
      
         # Get bet. GetKeyboardInput filters for 0-5 and enter.
         if ($key == 10 or $key == 48) {       # Enter or 0.
            if ($betState eq 'raise') {
               $betState = 'call';
            }
            else {
               $betState = 'drop';
            }
            &DisplayGameMsg("$bet");
         }
         else {
            $bet = ($key - 48) * 5;         # Compute bet: $5 - $25
            $newState = 'raise';
            &DisplayGameMsg("$bet");
         }

         # If player has insufficient funds to cover bet, return 'end1'. 
         # A loan is added to player's bankroll up to LoanLimit.         
         return 'end1' if (&CheckBankroll(($bet + $see), $Player1) == -1);
         
         # Update player's bankroll and show bet to opponent.         
         $bet = &ProcessPlayerBet($betState, $bet, $see, $Player1, $MsgData);
         $betState = $newState if ($newState ne '');
         return 'drop1' if ($betState eq 'drop');
         $$Player2{'OpponentBet'} = $bet;      # Show bet to opponent
         $bettor = 2;
      }
      elsif ($bettor == 2) {
         $bet = &ComputerBet($$Player2{'HandRank'}, $$Player1{'OpponentBet'},
                             $FirstBet);
         if ($betState eq 'bet') {
            &DisplayGameMsg($$MsgData{'08'},'BRIGHT_YELLOW',$Player2,'nocr');
            # When first bettor, provide an initial bet.
            $bet = (int(rand(2))+1)*5 if ($bet == 0);      # Random $5 $10
            $newState = 'raise';
            &DisplayGameMsg("$bet");
         }
         else {
            $see = $$Player2{'OpponentBet'};
            if ($raiseCount >= $$Player2{'RaiseLimit'}) {
               $betState = 'call';
            }
            else {
               if ($bet == -1) {
                  $betState = 'drop';
                  $bet = 0;
               }
               elsif ($bet == 0) {   
                  $betState = 'call';
               }
               else {
                  &DisplayGameMsg($$MsgData{'09'},'BRIGHT_YELLOW',$Player2, 'nocr');
                  &DisplayGameMsg("$bet");
                  $betState = 'raise';
               }
            }
         }

         # If player has insufficient funds to cover bet, return 'end2'. 
         # A loan is added to player's bankroll up to LoanLimit.         
         return 'end2' if (&CheckBankroll(($bet + $see), $Player2) == -1);

         # Update player's bankroll and show bet to opponent.         
         $bet = &ProcessPlayerBet($betState, $bet, $see, $Player2, $MsgData);
         $betState = $newState if ($newState ne '');
         return 'drop2' if ($betState eq 'drop');
         $$Player1{'OpponentBet'} = $bet;      # Show bet to opponent
         $bettor = 1;
      }
      
      $$Pot += ($see + $bet);                       # Update the Pot
      # while exit when 'call' or 'drop'.
   } 
   &DisplayDebug(1, "PlayerBet ...   exit. Pot: $$Pot   P1: $$Player1{'Bankroll'}" .
                    "   P2: $$Player2{'Bankroll'}   betState: $betState");
   return $betState;
}

# =============================================================================
# FUNCTION:  ProcessPlayerBet
#
# DESCRIPTION:
#    This routine processes the bet and see amounts for the specified player.
#    It also outputs the associated message based on betState. 
#
# CALLING SYNTAX:
#    $bet = &ProcessPlayerBet($BetState, $Bet, $See, \%Player, \%MsgData)
#
# ARGUMENTS:
#    $BetState      'bet', 'raise', 'call', or 'drop'.
#    $Bet           Player bet amount.
#    $See           Player see amount.
#    $Player        Pointer to player hash.
#    $MsgData       Pointer to message hash.
#
# RETURNED VALUES:
#    $Bet           Possible updated value
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ProcessPlayerBet {
   my($BetState, $Bet, $See, $Player, $MsgData) = @_;

  # Display player action message.                        
   if ($BetState eq 'raise') {           # see/raise message
   }
   elsif ($BetState eq 'call') {         # call message
      $Bet = 0;                          # No bet adjustment, just see.
      &DisplayGameMsg($$MsgData{'10'},'BRIGHT_YELLOW',$Player);
   }
   elsif ($BetState eq 'drop') {         # drop message
      &DisplayGameMsg($$MsgData{'11'},'BRIGHT_YELLOW',$Player);
      &DisplayGameMsg("");
   }
   elsif ($BetState eq 'bet') {
   }

   # Update player's bankroll.
   $$Player{'Bankroll'} -= ($See + $Bet);   # Deduct any wagers
   &DisplayDebug(1, "ProcessPlayerBet ...   $$Player{'Name'} see: $See   " .
                    "bet: $Bet");
   return $Bet;
}

# =============================================================================
# FUNCTION:  ComputerBet
#
# DESCRIPTION:
#    This routine is used by player 2 (computer) to determine a bet based on
#    the specified HandScore and player 1 bet. 
#
# CALLING SYNTAX:
#    $bet = &ComputerBet($HandRank, $OpponentBet, $FirstBet);
#
# ARGUMENTS:
#    $HandRank         Player2's handrank.
#    $OpponentBet      Player1's bet.
#    $FirstBet         Player making first bet; 
#
# RETURNED VALUES:
#    $Bet           Computer's bet (0,5,10,15,20,25), -1 = 'drop'
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ComputerBet {
   my($HandRank, $OpponentBet, $FirstBet) = @_;
   my($bet) = 0;

   &DisplayDebug(1, "ComputerBet ...   HandRank: $HandRank   OpponentBet: " .
                    "$OpponentBet   FirstBet: $FirstBet");
      
   if ($HandRank =~ m/Flush/ or $HandRank =~ m/Full/ or
       $HandRank =~ m/Four/) {              # Very good hand
      if ($OpponentBet >= 15) {
         $bet = (int(rand(3))+1)*5+10;      # Random $15 $20 $25
      }
      else {
         $bet = (int(rand(3))+1)*5;         # Random $5 $10 $15
      }
      &DisplayDebug(1, "ComputerBet ...   Very good hand   bet: $bet");
   }
   elsif ($HandRank =~ m/Straight/ or $HandRank =~ m/Three/) {  # Good hand
      if ($OpponentBet >= 15) {
         $bet = (int(rand(3))+1)*5+5;       # Random $10 $15 $20
      }
      else {
         $bet = (int(rand(3))+1)*5;         # Random  $5 $10 $15
      }
      &DisplayDebug(1, "ComputerBet ...   Good hand   bet: $bet");
   }
   elsif ($HandRank =~ 'Two-Pair') {        # Mediocre hand
      $bet = (int(rand(3))+1)*5;            # Random $5 $10 $15
      &DisplayDebug(1, "ComputerBet ...   Mediocre hand   bet: $bet");
   }
   elsif ($HandRank =~ 'One-Pair') {        # Poor hand
      if (int(rand(10))+1 > 8) {            # 20% of the time
         $bet = (int(rand(2))+2)*5;         # Random $10 $15
      }
      else {
         $bet = (int(rand(3)))*5;           # Random $0 $5 $10
      }
      # If player2 bets first, and this is 1st bet, bet is minimum $5.
      $bet = 5 if ($FirstBet == 2 and $OpponentBet == 0);
      &DisplayDebug(1, "ComputerBet ...   Poor hand   bet: $bet");
   }
   else {                                   # Very poor hand
      if ($HandRank =~ m/High-Card J/ or $HandRank =~ m/High-Card Q/ or
          $HandRank =~ m/High-Card K/ or $HandRank =~ m/High-Card A/) {
         $bet = (int(rand(3)))*5;           # Random $0 $5 $10
         $bet = -1 if (int(rand(10))+1 > 8);  # Drop 20% of the time
      }
      else {
         $bet = (int(rand(2)))*5;           # Random $0 $5
         $bet = -1 if (int(rand(10))+1 > 5);  # Drop 50% of the time
      }
      # If player2 bets first, and this is 1st bet, bet is minimum $5.
      $bet = 5 if ($FirstBet == 2 and $OpponentBet == 0);
      &DisplayDebug(1, "ComputerBet ...   Very poor hand   bet: $bet");
   }
   return $bet;
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
#    amount is returned. Otherwise, amount is disapproved.
#
# CALLING SYNTAX:
#    $result = &CheckBankroll($Amount, \%Player, $Game);
#
# ARGUMENTS:
#    $Amount         Amount to check.
#    $Player         Pointer to player hash.
#    $Game           Pointer to game hash (GUI code)
#
# RETURNED VALUES:
#    -1 = Disapproved,  $Amount = Approved.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub CheckBankroll {
   my($Amount, $Player, $Game) = @_;
   my($pay) = 0;
   my($msg, $chk);

   &DisplayDebug(1, "CheckBankroll ...   Amount: $Amount   Player has: " .
                    $$Player{'Bankroll'});

   # Payback loan(s) if bankroll funds permit.
   if ($$Player{'Bankroll'} > 100 and $$Player{'LoanCount'} > 0) {
      $pay = 0;
      while ($$Player{'Bankroll'} > 100 and $$Player{'LoanCount'} > 0) {
         $$Player{'Bankroll'} -= $$Player{'BankLoan'};       # Payback loan.
         $$Player{'LoanCount'} -= 1;
         $pay += $$Player{'BankLoan'};
      }
      if ($pay > 0) {
         $msg = join('', $$Player{'Name'}, " loan payback \$", $pay, 
                     " Loans: ", $$Player{'LoanCount'});
         &DisplayGameMsg($msg,'YELLOW', $Player, '', $Game);
      }
   }

   # Debit bankroll.
   if (($$Player{'Bankroll'} - $Amount) < 0) {        # Insufficient funds?
      if ($$Player{'LoanCount'} < $$Player{'LoanLimit'}) {  # Good credit?
         $$Player{'Bankroll'} += $$Player{'BankLoan'};       # Grant loan.
         $$Player{'LoanCount'} += 1;
         $msg = join('', $$Player{'Name'}, " loaned \$", $$Player{'BankLoan'},
                     " Loans: ", $$Player{'LoanCount'});
         &DisplayGameMsg($msg,'YELLOW', $Player, '', $Game);
      }
      else {
         $$Player{'Bankroll'} = 0;
         &DisplayDebug(1, "CheckBankroll ...   Disapproved");
         return -1;
      }
   }
   &DisplayDebug(1, "CheckBankroll ...   Approved");
   return $Amount;
}

# =============================================================================
# FUNCTION:  PlayerNames
#
# DESCRIPTION:
#    This routine gets the player names. Default values remain in effect 
#    if just enter is pressed.
#
# CALLING SYNTAX:
#    $result = &PlayerNames(\%Player1, \%Player2, \%Opponent, \%MsgData);
#
# ARGUMENTS:
#    $Player1        Pointer to player1 hash.
#    $Player2        Pointer to player2 hash.
#    $Opponent       Pointer to Opponents hash.
#    $MsgData        Pointer to message hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub PlayerNames {
   my($Player1, $Player2, $Opponent, $MsgData) = @_;
   my($resp, $id, $temp);

   &DisplayDebug(1, "PlayerNames ...");

   unless (&ColorMessage("What's your name? ", 'BRIGHT_YELLOW', 'nocr')) {
      $resp = <>;
      chomp($resp);
      $$Player1{'Name'} = $resp if ($resp ne '');
      &DisplayGameMsg("Hi " . $$Player1{'Name'} . "\n");
      $resp = '';
      sleep 1;
   }

   &DisplayGameMsg("Select your opponent.\n", 'BRIGHT_YELLOW');
   foreach $id (sort keys(%$Opponent)) {
      &DisplayGameMsg("   $id - " . $$Opponent{$id}{'Name'});
   }
   unless (&ColorMessage("\nOpponent: ", '', 'nocr')) {
      $resp = <>;
      chomp($resp);
      if ($resp =~ m/(\d)/) {
         $id = $1;
         $temp = join(' ', ' ', keys(%$Opponent), ' ');
         if ($temp =~ m/\s$id\s/) {
            $$Player2{'Name'} = $$Opponent{$id}{'Name'};
         }
      }
      &DisplayGameMsg($$MsgData{'06'}, 'YELLOW', $Player2);   # Opponent
      &DisplayGameMsg("");     
      $resp = '';
      sleep 2;
   }
}

# =============================================================================
# FUNCTION:  GetKeyboardInput
#
# DESCRIPTION:
#    This routine is used to check for and read keyboard input. The
#    Term::ReadKey module is used. Use ReadMode('cbreak') in the main
#    code to enable processing. This setting is applied to the terminal
#    session that was used to launched this program. Use ReadMode('normal')
#    to restore default settings at program exit or abnormal termination.
#
#    Acceptable single key input is defined in this routine.
#
# CALLING SYNTAX:
#    $result = &GetKeyboardInput($KeyPtr);
#
# ARGUMENTS:
#    None.
#
# RETURNED VALUES:
#    0 = No input,  not 0 = New Input.
#
# ACCESSED GLOBAL VARIABLES:
#    $opt_d
# =============================================================================
sub GetKeyboardInput {
   my($KeyPtr) = @_;
   my($key) = 0;
   
   my($chk) = ReadKey(-1);
   
   # Accepted single keys 0-5 and enter. 
   if ((ord($chk) >= 48 and ord($chk) <= 53) or ord($chk) == 10) {
      $key = ord($chk);
      &DisplayDebug(1, "GetKeyboardInput ...   key: $key");
      while (defined($chk = ReadKey(-1))) {}; # Discard any other input
   }
   return $key;
}

# =============================================================================
# FUNCTION:  Ctrl_C
#
# DESCRIPTION:
#    This routine is used to perform final functions at program termination. 
#    The main code sets mutiple linux signal events to run this handler. 
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
#    $main::MainRun
# =============================================================================
sub Ctrl_C {
   $main::MainRun = 0;            # Stop the main loop.
   ReadMode('normal');            # Restore normal terminal input.
   return;
}

# =============================================================================
# FUNCTION:  DisplayMessage
#
# DESCRIPTION:
#    Displays a message to the user. Output of the message is suppressed if 
#    quiet (-q) has been specified on the startup CLI.
#
# CALLING SYNTAX:
#    $result = &DisplayMessage($Message, $Color);
#
# ARGUMENTS:
#    $Message         Message to be output.
#    $Color           Optional message color.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::opt_q
# =============================================================================
sub DisplayMessage {
   my($Message, $Color) = @_;

   &ColorMessage($Message, $Color) unless (defined($main::opt_q));
   return 0;
}

# =============================================================================
# FUNCTION:  DisplayDebug
#
# DESCRIPTION:
#    Displays a debug message to the user if the current program $DebugLevel 
#    is >= to the message debug level. Debug level colors message. Output of
#    the message is suppressed if quiet (-q) has been specified on the startup
#    CLI.
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
#    $main::opt_d, $main::opt_q
# =============================================================================
sub DisplayDebug {
   my($Level, $Message) = @_;

   if ($main::opt_d >= $Level) {
      unless (defined($main::opt_q)) {
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
   }
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
#    $Color           Optional color attributes to apply.
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
   if ($Color ne '' and $^O =~ m/linux/) {
      print STDOUT colored($Message . $cr, $Color);
   }
   else {
      print STDOUT $Message . $cr;
   }
   return 0;
}

# =============================================================================
# FUNCTION:  DisplayGameMsg
#
# DESCRIPTION:
#    Displays a game message to the user. Performs text substitutions to the
#    message of keywords are present. The following keywords are processed.  
#
#       Keyword   Description
#       -------   -----------
#       %alt%     Alternate messages; separated by '_'.
#       %name%    Replace with player name.
#       %bank%    Players current bankroll.
#       %see%     Acknowledge bet for raise.
#       %value%   An value to display.
#       %rank%    Rank of current hand.
#
# CALLING SYNTAX:
#    $result = &DisplayGameMsg($Message, $Color, \%Player, $Option, $Game);
#
# ARGUMENTS:
#    $Message         Message to be output.
#    $Color           Optional message color.
#    $Player          Pointer to player data hash.
#    $Option          'nocr' to suppress message final \n.
#    $Game            Pointer to game hash (GUI code)
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub DisplayGameMsg {
   my($Message, $Color, $Player, $Option, $Game) = @_;
   my(%keywords) = ('%name%' => 'Name', '%bank%' => 'Bankroll',
                    '%see%' => 'OpponentBet', '%value%' => 'Value', 
                    '%rank%' => 'HandRank');
   my($key, $sub, $idx, @temp);

   &DisplayDebug(1, "DisplayGameMsg ...   $Message");

   if ($Message =~ m/^%alt%(.+)/s) {
      @temp = split('_', $1);
      $idx = int(rand($#temp +1));
      $Message = $temp[$idx];
   }
   if (defined($Player)) { 
      foreach $key (keys(%keywords)) {
         if ($Message =~ m/$key/) {
            $sub = $$Player{ $keywords{$key} };
            $Message =~ s/$key/$sub/;
         }
      }
   }
   
   if ($Option) {
      &ColorMessage($Message, $Color, $Option);
   }
   else {
      &ColorMessage($Message, $Color);
   }
   return 0;
}

# =============================================================================
# FUNCTION:  DisplayCards
#
# DESCRIPTION:
#    Displays the cards for the specified hand. The cards are displayed using
#    unicode box drawing characters and ANSIColor codes for suits.
#
#    The card values are translated from 3 to 2 characters for display.
#
# CALLING SYNTAX:
#    $result = &DisplayCards(\@Hand);
#
# ARGUMENTS:
#    $Hand          Pointer to card array.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub DisplayCards {
   my($Hand) = @_;
   my($indent, $color, $reset, @top, @crd, @bot);
   my(%suitColor) = ('d' => 'YELLOW', 'h' => 'RED', 's' => 'BRIGHT_BLUE',
                     'c' => 'GREEN');
   my(%suitSym) = ('d' => "\x{2666}", 'h' => "\x{2665}", 's' => "\x{2660}",
                    'c' => "\x{2663}");
   my(%cardXlat) = ('02' => '2', '03' => '3', '04' => '4', '05' => '5', '06' => '6',
                    '07' => '7', '08' => '8', '09' => '9', '10' => 'T', '11' => 'J',
                    '12' => 'Q', '13' => 'K', '14' => 'A');

   &DisplayDebug(1, "DisplayCards ...   cards: @$Hand");
   $indent = "     ";
   $color = 'FAINT WHITE';
   $reset = 'RESET';
   
   foreach my $card (@$Hand) {
      if ($card =~ m/(\d\d)(\w)/) {
         push (@top, join('', color($color),"\x{250C}\x{2500}\x{2500}\x{2500}" .
                          "\x{2500}\x{2510}  "));
         push (@crd, join('', color($color),"\x{2502} ",color($reset),
                          color($suitColor{$2}),$cardXlat{$1},$suitSym{$2},
                          color($color)," \x{2502}  "));
         push (@bot, join('', color($color),"\x{2514}\x{2500}\x{2500}\x{2500}" .
                          "\x{2500}\x{2518}  "));
      }
   }
   
   binmode(STDOUT, ":utf8");   # Set for unicode.
   
   print STDOUT $indent, @top, color($reset), "\n";    # Top of cards.
   print STDOUT $indent, @crd, color($reset), "\n";
   print STDOUT $indent, @bot, color($reset), "\n";    # Bottom of cards.
   
   binmode(STDOUT, ":bytes");  # Restore to default.

   return 0;
}

return 1;
