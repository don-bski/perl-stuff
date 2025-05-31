# ==============================================================================
# FILE: DrawPokerGuiData.pl                                          11-25-2024
#
# SERVICES: Draw Poker Perl-Tk Widget Position Data
#
# DESCRIPTION:
#   This program provides widget position data for Perl-Tk DrawPokerGUI.
#
# PERL VERSION:  5.28.1
#
# ==============================================================================
# -----------------------------------------------------------------------------
# Package Declaration
# -----------------------------------------------------------------------------
package DrawPokerGuiData;
require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
   LoadGuiData
);

use DrawPokerGuiLib;
use Storable qw(store retrieve dclone);

# =============================================================================
# FUNCTION:  LoadGuiData
#
# DESCRIPTION:
#    This routine loads the data used for positioning the screen widgets into
#    the the game working hashes. There are dedicated settings for each of the
#    four supported vertical resolutions: 2160, 1440, 1080, 720. Within each 
#    resolution a verical and horizontal card orientation is supported.
#
# CALLING SYNTAX:
#    $result = &LoadGuiData($Res, $Ornt, \%Header, \%Card, \%Footer, \%Pref,
#                           \%Game, $MsgData);
#
# ARGUMENTS:
#    $Res           Vertical screen size.
#    $Ornt          Game card orientation.
#    $Header        Pointer to header section hash.
#    $Cards         Pointer to cards section hash.
#    $Footer        Pointer to footer section hash.
#    $Pref          Pointer to preferences screen hash.
#    $Game          Pointer to game play hash.
#    $MsgData       Pointer to game play message hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub LoadGuiData {
   my($Res, $Ornt, $Header, $Cards, $Footer, $Pref, $Game, $MsgData) = @_;

   &DisplayDebug(1, "LoadGuiData ...   $Res   $Ornt");

   if ($Res >= 2160) {
      if ($Ornt =~ m/^v/i) {
         &DisplayDebug(1, "LoadGuiData header2160v");
         my(%header2160v) = (
            '01' => {'text' => 'frame', 'color' => '#010101', 'relx' => 0.113,
                     'rely' => 0.05, 'width' => 240, 'height' => 105, 
                     'borderWidth' => 2, 'obj' => 0}, 
            '02' => {'text' => 'frame', 'color' => '#010101', 'relx' => 0.5,
                     'rely' => 0.05, 'width' => 170, 'height' => 105, 
                     'borderWidth' => 2, 'obj' => 0}, 
            '03' => {'text' => 'frame', 'color' => '#010101', 'relx' => 0.885,
                     'rely' => 0.05, 'width' => 240, 'height' => 105, 
                     'borderWidth' => 2, 'obj' => 0}, 
                     
            '04' => {'text' => 'Player1,Name', 'color' => '#DCDCDC',
                     'relx' => 0.108, 'rely' => 0.038, 'width' => 200, 'height' => 36,
                     'font' => 'Ariel 24 bold', 'obj' => 0}, 
            '05' => {'text' => '-Pot-', 'color' => '#DCDCDC', 'relx' => 0.5,
                     'rely' => 0.038, 'width' => 100, 'height' => 40, 'obj' => 0,
                     'font' => 'Ariel 24 bold'}, 
            '06' => {'text' => 'Player2,Name', 'color' => '#DCDCDC', 'relx' => 0.885,
                     'rely' => 0.038, 'width' => 200, 'height' => 40, 'obj' => 0,
                     'font' => 'Ariel 24 bold'},
                     
            '07' => {'text' => 'Player1,Bankroll', 'color' => '#70E397', 
                     'relx' => 0.108, 'rely' => 0.06, 'width' => 100, 'height' => 40,
                     'font' => 'Ariel 24 bold', 'obj' => 0},
            '08' => {'text' => 'Pot', 'color' => '#FFC04A', 'relx' => 0.5, 
                     'rely' => 0.06, 'width' => 100, 'height' => 40, 'obj' => 0,
                     'font' => 'Ariel 24 bold'},
            '09' => {'text' => 'Player2,Bankroll', 'color' => '#6FE296', 'relx' => 0.885,
                     'rely' => 0.06, 'width' => 100, 'height' => 40, 'obj' => 0,
                     'font' => 'Ariel 24 bold'}, 
                     
            '10' => {'text' => 'Player1,Msg', 'color' => '#70E397', 'relx' => 0.12,
                     'rely' => 0.93, 'width' => 450, 'height' => 40, 'obj' => 0,
                     'font' => 'Ariel 24 normal'},
            '11' => {'text' => 'Player2,Msg', 'color' => '#70E397', 'relx' => 0.875,
                     'rely' => 0.925, 'width' => 450, 'height' => 40,
                     'font' => 'Ariel 24 normal', 'obj' => 0},
            '12' => {'text' => 'Msg', 'color' => '#DCDCDC', 'relx' => 0.5, 
                     'rely' => 0.89, 'width' => 1400, 'height' => 40, 'obj' => 0,
                     'font' => 'Ariel 24 normal'});
         my(%cards2160v) = (
            '01' => {'relx' => 0.068, 'rely' => 0.09, 'obj' => 0}, 
            '02' => {'relx' => 0.068, 'rely' => 0.25, 'obj' => 0}, 
            '03' => {'relx' => 0.068, 'rely' => 0.41, 'obj' => 0}, 
            '04' => {'relx' => 0.068, 'rely' => 0.57, 'obj' => 0}, 
            '05' => {'relx' => 0.068, 'rely' => 0.73, 'obj' => 0},
            '06' => {'relx' => 0.842, 'rely' => 0.09, 'obj' => 0}, 
            '07' => {'relx' => 0.842, 'rely' => 0.25, 'obj' => 0}, 
            '08' => {'relx' => 0.842, 'rely' => 0.41, 'obj' => 0}, 
            '09' => {'relx' => 0.842, 'rely' => 0.57, 'obj' => 0}, 
            '10' => {'relx' => 0.842, 'rely' => 0.73, 'obj' => 0}); 
         my(%footer2160v) = (
            '1' => {'text' => '$5', 'relx' => 0.355, 'rely' => 0.91, 'btnW' => 100,
                    'btnH' => 60, 'obj' => 0}, 
            '2' => {'text' => '$10', 'relx' => 0.415, 'rely' => 0.91, 'btnW' => 100,
                    'btnH' => 60, 'obj' => 0}, 
            '3' => {'text' => '$15', 'relx' => 0.475, 'rely' => 0.91, 'btnW' => 100,
                    'btnH' => 60, 'obj' => 0}, 
            '4' => {'text' => '$20', 'relx' => 0.535, 'rely' => 0.91, 'btnW' => 100,
                    'btnH' => 60, 'obj' => 0}, 
            '5' => {'text' => '$25', 'relx' => 0.595, 'rely' => 0.91, 'btnW' => 100,
                    'btnH' => 60, 'obj' => 0},
            '6' => {'text' => 'Deal', 'relx' => 0.36, 'rely' => 0.95, 'btnWh' => 130,
                    'btnH' => 60, 'obj' => 0}, 
            '7' => {'text' => 'Discard', 'relx' => 0.43, 'rely' => 0.95,
                    'btnW' => 140, 'btnH' => 60, 'obj' => 0}, 
            '8' => {'text' => 'Call', 'relx' => 0.502, 'rely' => 0.95, 'btnW' => 130,
                    'btnH' => 60, 'obj' => 0}, 
            '9' => {'text' => 'Drop', 'relx' => 0.575, 'rely' => 0.95, 'btnW' => 130,
                    'btnH' => 60, 'obj' => 0}); 
         my(%pref2160v) = (
            'p0' => {'width' => 2400, 'height' => 1000, 'obj' => 0, 
                     'backImg' => 'Felt_2400x1000.jpg', 'font' => 'Ariel 24 bold'},
            'p1' => {'text' => '--', 'color' => '#DCDCDC', 'font' => 'Ariel 24 bold',
                     'relx' => 0.5, 'rely' => 0.06, 'width' => 650, 'height' => 40,
                     'obj' => 0}, 
            'p2' => {'text' => '--', 'color' => '#DCDCDC', 'relx' => 0.08, 
                     'rely' => 0.09, 'width' => 2000, 'height' => 270, 
                     'font' => 'Ariel 24 bold', 'obj' => 0},
            'p3' => {'text' => '-Cardback-', 'color' => '#DCDCDC', 
                     'font' => 'Ariel 24 bold', 'relx' => 0.192, 'rely' => 0.64,
                     'width' => 200, 'height' => 40, 'obj' => 0},
            'p4' => {'text' => "-What's your name?-", 'color' => '#DCDCDC',
                     'font' => 'Ariel 24 bold', 'relx' => 0.498, 'rely' => 0.64,
                     'width' => 400, 'height' => 40, 'obj' => 0},
            'p5' => {'text' => '-Opponents-', 'color' => '#DCDCDC', 'relx' => 0.78, 
                     'font' => 'Ariel 24 bold', 'rely' => 0.64, 'width' => 550,
                     'height' => 40, 'obj' => 0},
            'p6' => {'relx' => 0.12, 'rely' => 0.75, 'width' => 20, 'btnW' => 70,
                     'btnH' => 50, 'obj' => 0}, 
            'p7' => {'relx' => 0.157, 'rely' => 0.675, 'cw' => 160, 'ch' => 210,
                     'backs' => [], 'card' => 'back', 'obj' => 0},
            'p8' => {'relx' => 0.233, 'rely' => 0.75, 'width' => 20, 'btnW' => 70,
                     'btnH' => 50, 'obj' => 0},
            'p9' => {'relx' => 0.403, 'rely' => 0.91, 'width' => 25, 'btnW' => 90,
                     'btnH' => 60, 'obj' => 0},
            'p10' => {'relx' => 0.595, 'rely' => 0.91, 'width' => 25, 'btnW' => 90,
                      'btnH' => 60, 'obj' => 0},
            'p11' => {'relx' => 0.424, 'rely' => 0.67, 'width' => 350, 'height' => 46,
                      'obj' => 0},
            'p12' => {'relx' => 0.69, 'rely' => 0.67, 'width' => 500, 'height' => 160,
                      'obj' => 0},
            'p13' => {'relx' => 0.46, 'rely' => 0.74, 'color' => '#DCDCDC', 
                      'cw' => 160, 'ch' => 210, 'card' => 'oppnt', 'obj' => 0},
            'p14' => {'text' => '-Auto-Play-', 'color' => '#DCDCDC',
                      'font' => 'Ariel 24 bold', 'relx' => 0.78, 'rely' => 0.90, 
                      'width' => 180, 'height' => 30, 'btnW' => 30, 'btnH' => 25,
                      'btnX' => 0.73, 'btnY' => 0.90, 'obj' => 0});
         my(%game2160v) = (
            'State' => 'start',
            'Pot' => 0,
            'Msg' => '',
            'FirstBet' => 'Player1',   # 'Player1' or 'Player2'
            'RaiseCount' => 0,
            'RaiseLimit' => 3,
            'BankLoan' => 100,
            'LoanLimit' => 3,
            'GameEnd' => 500,
            'AutoPlay' => 0,
            'GameCount' => 0,
            'WinHistory' => [],
            'AllHands' => [],    # n=1,2,3,4  c1c2c3c4c5:n, ...  &RankHand
            'Main' => {'Width' => 2400, 'Height' => 1900, 'Font' => 'Ariel 22 normal',
                       'FontB' => 'Ariel 22 bold', 'CardW' => 210, 'CardH' => 280,
                       'FontLB' => 'Ariel 24 bold', 'BackImg' => 'Felt_2400x1900.jpg',
                       'BackObj' => 0},
            'Deck' => {'Cards' => [], 'Drawn' => [], 'dPos' => 0, 'Back' => '',
                       'File' => ''},
            'Player1' => {'Name' => 'Player', 'Bankroll' => 100, 'LoanCount' => 0, 
                          'Value' => 0, 'Hand' => [], 'HandScore' => 0, 'Msg' => '', 
                          'HandRank' => '', 'OpponentBet' => 0, 'PreLoadCount' => 0},
            'Player2' => {'Name' => 'Computer', 'Bankroll' => 100, 'LoanCount' => 0, 
                          'Value' => 0, 'Hand' => [], 'HandScore' => 0, 'Msg' => '', 
                          'HandRank' => '', 'OpponentBet' => 0, 'PreLoadCount' => 0},
            'Opponent' => {'Brian' => 3, 'Vicky' => 3, 'Mark' => 4, 'Ashley' => 2,
                           'Bob' => 2, 'Nadia' => 5});  # Value is skill level
         %$Header = %{ dclone(\%header2160v) };
         %$Cards = %{ dclone(\%cards2160v) };
         %$Footer = %{ dclone(\%footer2160v) };
         %$Pref = %{ dclone(\%pref2160v) };
         %$Game = %{ dclone(\%game2160v) };
      }
      else {
         &DisplayDebug(1, "LoadGuiData header2160h");
         my(%header2160h) = (
            '01' => {'text' => 'frame', 'color' => '#010101', 'relx' => 0.132,
                     'rely' => 0.103, 'width' => 266, 'height' => 114, 
                     'borderWidth' => 2, 'obj' => 0}, 
            '02' => {'text' => 'frame', 'color' => '#010101', 'relx' => 0.494,
                     'rely' => 0.103, 'width' => 130, 'height' => 114, 
                     'borderWidth' => 2, 'obj' => 0}, 
            '03' => {'text' => 'frame', 'color' => '#010101', 'relx' => 0.862,
                     'rely' => 0.103, 'width' => 266, 'height' => 114, 
                     'borderWidth' => 2, 'obj' => 0}, 
                     
            '04' => {'text' => 'Player1,Name', 'color' => '#DCDCDC',
                     'relx' => 0.13, 'rely' => 0.08, 'width' => 240, 'height' => 44,
                     'font' => 'Ariel 28 bold', 'obj' => 0}, 
            '05' => {'text' => '-Pot-', 'color' => '#DCDCDC', 'relx' => 0.495,
                     'rely' => 0.08, 'width' => 100, 'height' => 44, 'obj' => 0,
                     'font' => 'Ariel 28 bold'}, 
            '06' => {'text' => 'Player2,Name', 'color' => '#DCDCDC', 'relx' => 0.86,
                     'rely' => 0.08, 'width' => 240, 'height' => 44, 'obj' => 0,
                     'font' => 'Ariel 28 bold'},
                     
            '07' => {'text' => 'Player1,Bankroll', 'color' => '#70E397', 
                     'relx' => 0.13, 'rely' => 0.13, 'width' => 120, 'height' => 44,
                     'font' => 'Ariel 28 bold', 'obj' => 0},
            '08' => {'text' => 'Pot', 'color' => '#FFC04A', 'relx' => 0.495, 
                     'rely' => 0.13, 'width' => 120, 'height' => 44, 'obj' => 0,
                     'font' => 'Ariel 28 bold'},
            '09' => {'text' => 'Player2,Bankroll', 'color' => '#6FE296', 'relx' => 0.86,
                     'rely' => 0.13, 'width' => 120, 'height' => 44, 'obj' => 0,
                     'font' => 'Ariel 28 bold'}, 
                     
            '10' => {'text' => 'Player1,Msg', 'color' => '#70E397', 'relx' => 0.138,
                     'rely' => 0.84, 'width' => 450, 'height' => 44, 'obj' => 0,
                     'font' => 'Ariel 26 normal'},
            '11' => {'text' => 'Player2,Msg', 'color' => '#70E397', 
                     'relx' => 0.86, 'rely' => 0.82, 'width' => 450, 'height' => 44,
                     'font' => 'Ariel 26 normal', 'obj' => 0},
            '12' => {'text' => 'Msg', 'color' => '#DCDCDC', 'relx' => 0.5, 
                     'rely' => 0.715, 'width' => 1200, 'height' => 44, 'obj' => 0,
                     'font' => 'Ariel 26 normal'});
         my(%cards2160h) = (
            '01' => {'relx' => 0.158, 'rely' => 0.226, 'obj' => 0}, 
            '02' => {'relx' => 0.297, 'rely' => 0.226, 'obj' => 0}, 
            '03' => {'relx' => 0.436, 'rely' => 0.226, 'obj' => 0}, 
            '04' => {'relx' => 0.575, 'rely' => 0.226, 'obj' => 0}, 
            '05' => {'relx' => 0.714, 'rely' => 0.226, 'obj' => 0},
            '06' => {'relx' => 0.198, 'rely' => 0.226, 'obj' => 0}, 
            '07' => {'relx' => 0.322, 'rely' => 0.226, 'obj' => 0}, 
            '08' => {'relx' => 0.446, 'rely' => 0.226, 'obj' => 0}, 
            '09' => {'relx' => 0.570, 'rely' => 0.226, 'obj' => 0}, 
            '10' => {'relx' => 0.694, 'rely' => 0.226, 'obj' => 0});
         my(%footer2160h) = (
            '1' => {'text' => '$5', 'relx' => 0.355, 'rely' => 0.80, 'btnW' => 100,
                    'btnH' => 60, 'obj' => 0}, 
            '2' => {'text' => '$10', 'relx' => 0.415, 'rely' => 0.80, 'btnW' => 100,
                    'btnH' => 60, 'obj' => 0}, 
            '3' => {'text' => '$15', 'relx' => 0.475, 'rely' => 0.80, 'btnW' => 100,
                    'btnH' => 60, 'obj' => 0}, 
            '4' => {'text' => '$20', 'relx' => 0.535, 'rely' => 0.80, 'btnW' => 100,
                    'btnH' => 60, 'obj' => 0}, 
            '5' => {'text' => '$25', 'relx' => 0.595, 'rely' => 0.80, 'btnW' => 100,
                    'btnH' => 60, 'obj' => 0},
            '6' => {'text' => 'Deal', 'relx' => 0.36, 'rely' => 0.885, 'btnW' => 130,
                    'btnH' => 60, 'obj' => 0}, 
            '7' => {'text' => 'Discard', 'relx' => 0.424, 'rely' => 0.885,
                    'btnW' => 166, 'btnH' => 60, 'obj' => 0}, 
            '8' => {'text' => 'Call', 'relx' => 0.507, 'rely' => 0.885, 'btnW' => 130,
                    'btnH' => 60, 'obj' => 0}, 
            '9' => {'text' => 'Drop', 'relx' => 0.575, 'rely' => 0.885, 'btnW' => 130,
                    'btnH' => 60, 'obj' => 0}); 
         my(%pref2160h) = (
            'p0' => {'width' => 2400, 'height' => 1000, 'obj' => 0, 
                     'backImg' => 'Felt_2400x1000.jpg', 'font' => 'Ariel 24 bold'},
            'p1' => {'text' => '--', 'color' => '#DCDCDC', 'font' => 'Ariel 24 bold',
                     'relx' => 0.5, 'rely' => 0.06, 'width' => 650, 'height' => 40,
                     'obj' => 0}, 
            'p2' => {'text' => '--', 'color' => '#DCDCDC', 'relx' => 0.08, 
                     'rely' => 0.09, 'width' => 2000, 'height' => 270, 
                     'font' => 'Ariel 24 bold', 'obj' => 0},
            'p3' => {'text' => '-Cardback-', 'color' => '#DCDCDC', 
                     'font' => 'Ariel 24 bold', 'relx' => 0.191, 'rely' => 0.635,
                     'width' => 200, 'height' => 40, 'obj' => 0},
            'p4' => {'text' => "-What's your name?-", 'color' => '#DCDCDC',
                     'font' => 'Ariel 24 bold', 'relx' => 0.5, 'rely' => 0.635,
                     'width' => 400, 'height' => 40, 'obj' => 0},
            'p5' => {'text' => '-Opponents-', 'color' => '#DCDCDC', 'relx' => 0.78, 
                     'font' => 'Ariel 24 bold', 'rely' => 0.635, 'width' => 500,
                     'height' => 40, 'obj' => 0},
            'p6' => {'relx' => 0.12, 'rely' => 0.75, 'width' => 20, 'btnW' => 70,
                     'btnH' => 50, 'obj' => 0}, 
            'p7' => {'relx' => 0.157, 'rely' => 0.675, 'cw' => 160, 'ch' => 210,
                     'backs' => [], 'card' => 'back', 'obj' => 0},
            'p8' => {'relx' => 0.233, 'rely' => 0.75, 'width' => 20, 'btnW' => 70,
                     'btnH' => 50, 'obj' => 0},
            'p9' => {'relx' => 0.46, 'rely' => 0.91, 'width' => 25, 'btnW' => 90,
                     'btnH' => 60, 'obj' => 0},
            'p10' => {'relx' => 0.54, 'rely' => 0.91, 'width' => 25, 'btnW' => 90,
                      'btnH' => 60, 'obj' => 0},
            'p11' => {'relx' => 0.427, 'rely' => 0.67, 'width' => 350, 'height' => 46,
                      'obj' => 0},
            'p12' => {'relx' => 0.69, 'rely' => 0.67, 'width' => 500, 'height' => 166,
                      'obj' => 0},
            'p13' => {'relx' => 0.452, 'rely' => 0.70, 'color' => '#DCDCDC', 
                      'cw' => 120, 'ch' => 160, 'card' => 'oppnt', 'obj' => 0},
            'p14' => {'text' => '-Auto-Play-', 'color' => '#DCDCDC',
                      'font' => 'Ariel 24 bold', 'relx' => 0.508, 'rely' => 0.78, 
                      'width' => 180, 'height' => 30, 'btnW' => 30, 'btnH' => 25,
                      'btnX' => 0.458, 'btnY' => 0.78, 'obj' => 0});
         my(%game2160h) = (
            'State' => 'start',
            'Pot' => 0,
            'Msg' => '',
            'FirstBet' => 'Player1',   # 'Player1' or 'Player2'
            'RaiseCount' => 0,
            'RaiseLimit' => 3,
            'BankLoan' => 100,
            'LoanLimit' => 3,
            'GameEnd' => 500,
            'AutoPlay' => 0,
            'GameCount' => 0,
            'WinHistory' => [],
            'AllHands' => [],    # n=1,2,3,4  c1c2c3c4c5:n, ...  &RankHand
            'Main' => {'Width' => 2400, 'Height' => 1000, 'Font' => 'Ariel 24 normal',
                       'FontB' => 'Ariel 24 bold', 'CardW' => 300, 'CardH' => 400,
                       'FontLB' => 'Ariel 26 bold', 'BackImg' => 'Felt_2400x1000.jpg',
                       'BackObj' => 0},
            'Deck' => {'Cards' => [], 'Drawn' => [], 'dPos' => 0, 'Back' => '',
                       'File' => ''},
            'Player1' => {'Name' => 'Player', 'Bankroll' => 100, 'LoanCount' => 0, 
                          'Value' => 0, 'Hand' => [], 'HandScore' => 0, 'Msg' => '', 
                          'HandRank' => '', 'OpponentBet' => 0, 'PreLoadCount' => 0},
            'Player2' => {'Name' => 'Computer', 'Bankroll' => 100, 'LoanCount' => 0, 
                          'Value' => 0, 'Hand' => [], 'HandScore' => 0, 'Msg' => '', 
                          'HandRank' => '', 'OpponentBet' => 0, 'PreLoadCount' => 0},
            'Opponent' => {'Brian' => 3, 'Vicky' => 3, 'Mark' => 4, 'Ashley' => 2,
                           'Bob' => 2, 'Nadia' => 5});  # Value is skill level
            
         %$Header = %{ dclone(\%header2160h) };
         %$Cards = %{ dclone(\%cards2160h) };
         %$Footer = %{ dclone(\%footer2160h) };
         %$Pref = %{ dclone(\%pref2160h) };
         %$Game = %{ dclone(\%game2160h) };
      }    
   }
   elsif ($Res >= 1440) {
      if ($Ornt =~ m/^v/i) {
         &DisplayDebug(1, "LoadGuiData header1440v");
         my(%header1440v) = (
            '01' => {'text' => 'frame', 'color' => '#181818', 'relx' => 0.125,
                     'rely' => 0.043, 'width' => 160, 'height' => 76, 
                     'borderWidth' => 1, 'obj' => 0}, 
            '02' => {'text' => 'frame', 'color' => '#181818', 'relx' => 0.498, 
                     'rely' => 0.044, 'width' => 90, 'height' => 76, 
                     'borderWidth' => 1, 'obj' => 0}, 
            '03' => {'text' => 'frame', 'color' => '#181818', 'relx' => 0.856,
                     'rely' => 0.043, 'width' => 160, 'height' => 76, 
                     'borderWidth' => 1, 'obj' => 0}, 
                     
            '04' => {'text' => 'Player1,Name', 'color' => '#DCDCDC', 'relx' => 0.124,
                     'rely' => 0.03, 'width' => 148, 'height' => 36,
                     'font' => 'Ariel 14 bold', 'obj' => 0}, 
            '05' => {'text' => '-Pot-', 'color' => '#DCDCDC', 'relx' => 0.498, 
                     'rely' => 0.03, 'width' => 80, 'height' => 36, 'obj' => 0,
                     'font' => 'Ariel 14 bold'}, 
            '06' => {'text' => 'Player2,Name', 'color' => '#DCDCDC', 'relx' => 0.856,
                     'rely' => 0.03, 'width' => 148, 'height' => 36,
                     'font' => 'Ariel 14 bold', 'obj' => 0}, 
                     
            '07' => {'text' => 'Player1,Bankroll', 'color' => '#70E397',
                     'relx' => 0.123, 'rely' => 0.055, 'width' => 79, 'height' => 36,
                     'font' => 'Ariel 14 bold', 'obj' => 0}, 
            '08' => {'text' => 'Pot', 'color' => '#FFC04A', 'relx' => 0.498, 
                     'rely' => 0.058, 'width' => 80, 'height' => 36,
                     'font' => 'Ariel 14 bold', 'obj' => 0}, 
            '09' => {'text' => 'Player2,Bankroll', 'color' => '#6FE296', 
                     'relx' => 0.85, 'rely' => 0.055, 'width' => 79, 'height' => 36,
                     'font' => 'Ariel 14 bold', 'obj' => 0},
                     
            '10' => {'text' => 'Player1,Msg', 'color' => '#70E397', 'relx' => 0.135,
                     'rely' => 0.943, 'width' => 350, 'height' => 36, 
                     'font' => 'Ariel 12 bold', 'obj' => 0},
            '11' => {'text' => 'Player2,Msg', 'color' => '#70E397', 'relx' => 0.85,
                     'rely' => 0.94, 'width' => 350, 'height' => 36, 
                     'font' => 'Ariel 12 bold', 'obj' => 0},
            '12' => {'text' => 'Msg', 'relx' => 0.491, 'rely' => 0.885, 
                     'width' => 920, 'height' => 32, 'color' => '#DCDCDC', 
                     'font' => 'Ariel 12 normal', 'obj' => 0});
         my(%cards1440v) = (
            '01' => {'relx' => 0.0782, 'rely' => 0.09, 'obj' => 0}, 
            '02' => {'relx' => 0.0782, 'rely' => 0.25, 'obj' => 0}, 
            '03' => {'relx' => 0.0782, 'rely' => 0.41, 'obj' => 0}, 
            '04' => {'relx' => 0.0782, 'rely' => 0.57, 'obj' => 0}, 
            '05' => {'relx' => 0.0782, 'rely' => 0.73, 'obj' => 0},
            '06' => {'relx' => 0.815, 'rely' => 0.09, 'obj' => 0}, 
            '07' => {'relx' => 0.815, 'rely' => 0.25, 'obj' => 0}, 
            '08' => {'relx' => 0.815, 'rely' => 0.41, 'obj' => 0}, 
            '09' => {'relx' => 0.815, 'rely' => 0.57, 'obj' => 0}, 
            '10' => {'relx' => 0.815, 'rely' => 0.73, 'obj' => 0});
         my(%footer1440v) = (
            '1' => {'text' => '$5', 'relx' => 0.355, 'rely' => 0.91, 'btnW' => 60,
                    'btnH' => 32, 'obj' => 0}, 
            '2' => {'text' => '$10', 'relx' => 0.415, 'rely' => 0.91, 'btnW' => 60,
                    'btnH' => 32, 'obj' => 0}, 
            '3' => {'text' => '$15', 'relx' => 0.475, 'rely' => 0.91, 'btnW' => 60,
                    'btnH' => 32, 'obj' => 0}, 
            '4' => {'text' => '$20', 'relx' => 0.535, 'rely' => 0.91, 'btnW' => 60,
                    'btnH' => 32, 'obj' => 0}, 
            '5' => {'text' => '$25', 'relx' => 0.595, 'rely' => 0.91, 'btnW' => 60,
                    'btnH' => 32, 'obj' => 0},
            '6' => {'text' => 'Deal', 'relx' => 0.36, 'rely' => 0.95, 'btnW' => 82,
                    'btnH' => 32, 'obj' => 0}, 
            '7' => {'text' => 'Discard', 'relx' => 0.427, 'rely' => 0.95,
                    'btnW' => 96, 'btnH' => 32, 'obj' => 0}, 
            '8' => {'text' => 'Call', 'relx' => 0.506, 'rely' => 0.95, 'btnW' => 82,
                    'btnH' => 32, 'obj' => 0}, 
            '9' => {'text' => 'Drop', 'relx' => 0.575, 'rely' => 0.95, 'btnW' => 82,
                    'btnH' => 32, 'obj' => 0}); 
         my(%pref1440v) = (
            'p0' => {'width' => 1500, 'height' => 670, 'backImg' => 'Felt_1500x670.jpg',
                     'font' => 'Ariel 12 bold', 'obj' => 0},
            'p1' => {'text' => '--', 'color' => '#DCDCDC', 'font' => 'Ariel 12 bold',
                     'relx' => 0.495, 'rely' => 0.07, 'width' => 600, 'height' => 30,
                     'obj' => 0}, 
            'p2' => {'text' => '', 'color' => '#DCDCDC', 'relx' => 0.09, 
                     'rely' => 0.10, 'width' => 1220, 'height' => 270, 
                     'font' => 'Ariel 12 bold', 'obj' => 0},
            'p3' => {'text' => '-Cardback-', 'color' => '#DCDCDC', 
                     'font' => 'Ariel 12 bold', 'relx' => 0.192, 'rely' => 0.57, 
                     'width' => 120, 'height' => 30, 'obj' => 0},
            'p4' => {'text' => "-What's your name?-", 'color' => '#DCDCDC', 
                     'font' => 'Ariel 12 bold', 'relx' => 0.494, 'rely' => 0.57, 
                     'width' => 200, 'height' => 30, 'obj' => 0},
            'p5' => {'text' => '-Opponents-', 'color' => '#DCDCDC',
                     'font' => 'Ariel 12 bold', 'relx' => 0.772, 'rely' => 0.57, 
                     'width' => 300, 'height' => 30, 'obj' => 0},
            'p6' => {'relx' => 0.126, 'rely' => 0.665, 'width' => 16, 'btnW' => 45,
                     'btnH' => 36, 'obj' => 0}, 
            'p7' => {'relx' => 0.16, 'rely' => 0.60, 'cw' => 96, 'ch' => 128,
                     'backs' => [], 'card' => 'back', 'obj' => 0},
            'p8' => {'relx' => 0.23, 'rely' => 0.665, 'width' => 16, 'btnW' => 45,
                     'btnH' => 36, 'obj' => 0},
            'p9' => {'relx' => 0.39, 'rely' => 0.9, 'width' => 20, 'btnW' => 66,
                     'btnH' => 36, 'obj' => 0},
            'p10' => {'relx' => 0.60, 'rely' => 0.9, 'width' => 20, 'btnW' => 66,
                      'btnH' => 36, 'obj' => 0},
            'p11' => {'relx' => 0.452, 'rely' => 0.601, 'width' => 120, 'obj' => 0},
            'p12' => {'relx' => 0.70, 'rely' => 0.60, 'width' => 250, 'height' => 104,
                      'obj' => 0},
            'p13' => {'relx' => 0.452, 'rely' => 0.70, 'color' => '#DCDCDC', 
                      'cw' => 120, 'ch' => 160, 'card' => 'oppnt', 'obj' => 0},
            'p14' => {'text' => '-Auto-Play-', 'color' => '#DCDCDC',
                      'font' => 'Ariel 12 bold', 'relx' => 0.769, 'rely' => 0.82, 
                      'width' => 90, 'height' => 30, 'btnW' => 18, 'btnH' => 15,
                      'btnX' => 0.73, 'btnY' => 0.82, 'obj' => 0});
         my(%game1440v) = (
            'State' => 'start',
            'Pot' => 0,
            'Msg' => '',
            'FirstBet' => 'Player1',   # 'Player1' or 'Player2'
            'RaiseCount' => 0,
            'RaiseLimit' => 3,
            'BankLoan' => 100,
            'LoanLimit' => 3,
            'GameEnd' => 500,
            'AutoPlay' => 0,
            'GameCount' => 0,
            'WinHistory' => [],
            'AllHands' => [],    # n=1,2,3,4  c1c2c3c4c5:n, ...  &RankHand
            'Main' => {'Width' => 1500, 'Height' => 1200, 'Font' => 'Ariel 12 normal',
                       'FontB' => 'Ariel 12 bold', 'CardW' => 136, 'CardH' => 184,
                       'FontLB' => 'Ariel 14 bold', 'BackImg' => 'Felt_1500x1200.jpg',
                       'BackObj' => 0},
            'Deck' => {'Cards' => [], 'Drawn' => [], 'dPos' => 0, 'Back' => '',
                       'File' => ''},
            'Player1' => {'Name' => 'Player', 'Bankroll' => 100, 'LoanCount' => 0, 
                          'Value' => 0, 'Hand' => [], 'HandScore' => 0, 'Msg' => '', 
                          'HandRank' => '', 'OpponentBet' => 0, 'PreLoadCount' => 0},
            'Player2' => {'Name' => 'Computer', 'Bankroll' => 100, 'LoanCount' => 0, 
                          'Value' => 0, 'Hand' => [], 'HandScore' => 0, 'Msg' => '', 
                          'HandRank' => '', 'OpponentBet' => 0, 'PreLoadCount' => 0},
            'Opponent' => {'Brian' => 3, 'Vicky' => 3, 'Mark' => 4, 'Ashley' => 2,
                           'Bob' => 2, 'Nadia' => 5});  # Value is skill level
            
         %$Header = %{ dclone(\%header1440v) };
         %$Cards = %{ dclone(\%cards1440v) };
         %$Footer = %{ dclone(\%footer1440v) };
         %$Pref = %{ dclone(\%pref1440v) };
         %$Game = %{ dclone(\%game1440v) };
      }
      else {
         &DisplayDebug(1, "LoadGuiData header1440h");
         my(%header1440h) = (
            '01' => {'text' => 'frame', 'color' => '#181818', 'relx' => 0.139,
                     'rely' => 0.097, 'width' => 160, 'height' => 76, 
                     'borderWidth' => 1, 'obj' => 0}, 
            '02' => {'text' => 'frame', 'color' => '#181818', 'relx' => 0.495, 
                     'rely' => 0.097, 'width' => 90, 'height' => 76, 
                     'borderWidth' => 1, 'obj' => 0}, 
            '03' => {'text' => 'frame', 'color' => '#181818', 'relx' => 0.85,
                     'rely' => 0.097, 'width' => 160, 'height' => 76, 
                     'borderWidth' => 1, 'obj' => 0}, 
                     
            '04' => {'text' => 'Player1,Name', 'color' => '#DCDCDC', 'relx' => 0.139,
                    'rely' => 0.075, 'width' => 150, 'height' => 36,
                    'font' => 'Ariel 14 bold', 'obj' => 0}, 
            '05' => {'text' => '-Pot-', 'color' => '#DCDCDC', 'relx' => 0.495, 
                    'rely' => 0.075, 'width' => 80, 'height' => 36, 'obj' => 0,
                    'font' => 'Ariel 14 bold'}, 
            '06' => {'text' => 'Player2,Name', 'color' => '#DCDCDC', 'relx' => 0.85,
                    'rely' => 0.075, 'width' => 150, 'height' => 36,
                    'font' => 'Ariel 14 bold', 'obj' => 0}, 
                    
            '07' => {'text' => 'Player1,Bankroll', 'color' => '#70E397',
                    'relx' => 0.14, 'rely' => 0.121, 'width' => 80, 'height' => 36,
                    'font' => 'Ariel 14 bold', 'obj' => 0}, 
            '08' => {'text' => 'Pot', 'color' => '#FFC04A', 'relx' => 0.495, 
                    'rely' => 0.121, 'width' => 80, 'height' => 36,
                    'font' => 'Ariel 14 bold', 'obj' => 0}, 
            '09' => {'text' => 'Player2,Bankroll', 'color' => '#6FE296', 
                    'relx' => 0.85, 'rely' => 0.121, 'width' => 80, 'height' => 36,
                    'font' => 'Ariel 14 bold', 'obj' => 0},
                    
            '10' => {'text' => 'Player1,Msg', 'color' => '#70E397', 'relx' => 0.14,
                    'rely' => 0.86, 'width' => 350, 'height' => 36, 
                    'font' => 'Ariel 12 bold', 'obj' => 0},
            '11' => {'text' => 'Player2,Msg', 'color' => '#70E397', 'relx' => 0.85,
                    'rely' => 0.85, 'width' => 350, 'height' => 36, 
                    'font' => 'Ariel 12 bold', 'obj' => 0},
            '12' => {'text' => 'Msg', 'relx' => 0.495, 'rely' => 0.73, 
                    'width' => 1200, 'height' => 32, 'color' => '#DCDCDC', 
                    'font' => 'Ariel 12 normal', 'obj' => 0});
         my(%cards1440h) = (
            '01' => {'relx' => 0.158, 'rely' => 0.245, 'obj' => 0}, 
            '02' => {'relx' => 0.298, 'rely' => 0.245, 'obj' => 0}, 
            '03' => {'relx' => 0.438, 'rely' => 0.245, 'obj' => 0}, 
            '04' => {'relx' => 0.578, 'rely' => 0.245, 'obj' => 0}, 
            '05' => {'relx' => 0.718, 'rely' => 0.245, 'obj' => 0},
            '06' => {'relx' => 0.158, 'rely' => 0.245, 'obj' => 0}, 
            '07' => {'relx' => 0.298, 'rely' => 0.245, 'obj' => 0}, 
            '08' => {'relx' => 0.438, 'rely' => 0.245, 'obj' => 0}, 
            '09' => {'relx' => 0.578, 'rely' => 0.245, 'obj' => 0}, 
            '10' => {'relx' => 0.718, 'rely' => 0.245, 'obj' => 0});
         my(%footer1440h) = (
            '1' => {'text' => '$5', 'relx' => 0.355, 'rely' => 0.80, 'btnW' => 60,
                    'btnH' => 32, 'obj' => 0}, 
            '2' => {'text' => '$10', 'relx' => 0.415, 'rely' => 0.80, 'btnW' => 60,
                    'btnH' => 32, 'obj' => 0}, 
            '3' => {'text' => '$15', 'relx' => 0.475, 'rely' => 0.80, 'btnW' => 60,
                    'btnH' => 32, 'obj' => 0}, 
            '4' => {'text' => '$20', 'relx' => 0.535, 'rely' => 0.80, 'btnW' => 60,
                    'btnH' => 32, 'obj' => 0}, 
            '5' => {'text' => '$25', 'relx' => 0.595, 'rely' => 0.80, 'btnW' => 60,
                    'btnH' => 32, 'obj' => 0},
            '6' => {'text' => 'Deal', 'relx' => 0.36, 'rely' => 0.885, 'btnW' => 82,
                    'btnH' => 32, 'obj' => 0}, 
            '7' => {'text' => 'Discard', 'relx' => 0.427, 'rely' => 0.885,
                    'btnW' => 96, 'btnH' => 32, 'obj' => 0}, 
            '8' => {'text' => 'Call', 'relx' => 0.506, 'rely' => 0.885, 'btnW' => 82,
                    'btnH' => 32, 'obj' => 0}, 
            '9' => {'text' => 'Drop', 'relx' => 0.575, 'rely' => 0.885, 'btnW' => 82,
                    'btnH' => 32, 'obj' => 0}); 
         my(%pref1440h) = (
            'p0' => {'width' => 1500, 'height' => 670, 'backImg' => 'Felt_1500x670.jpg',
                     'font' => 'Ariel 12 bold', 'obj' => 0},
            'p1' => {'text' => '--', 'color' => '#DCDCDC', 'font' => 'Ariel 12 bold',
                     'relx' => 0.495, 'rely' => 0.07, 'width' => 600, 'height' => 30,
                     'obj' => 0}, 
            'p2' => {'text' => '', 'color' => '#DCDCDC', 'relx' => 0.09, 
                     'rely' => 0.10, 'width' => 1220, 'height' => 270, 
                     'font' => 'Ariel 12 bold', 'obj' => 0},
            'p3' => {'text' => '-Cardback-', 'color' => '#DCDCDC', 
                     'font' => 'Ariel 12 bold', 'relx' => 0.192, 'rely' => 0.57, 
                     'width' => 120, 'height' => 30, 'obj' => 0},
            'p4' => {'text' => "-What's your name?-", 'color' => '#DCDCDC', 
                     'font' => 'Ariel 12 bold', 'relx' => 0.494, 'rely' => 0.57, 
                     'width' => 200, 'height' => 30, 'obj' => 0},
            'p5' => {'text' => '-Opponents-', 'color' => '#DCDCDC',
                     'font' => 'Ariel 12 bold', 'relx' => 0.77, 'rely' => 0.57, 
                     'width' => 300, 'height' => 30, 'obj' => 0},
            'p6' => {'relx' => 0.126, 'rely' => 0.665, 'width' => 16, 'btnW' => 45,
                     'btnH' => 36, 'obj' => 0}, 
            'p7' => {'relx' => 0.16, 'rely' => 0.60, 'cw' => 96, 'ch' => 128,
                     'backs' => [], 'card' => 'back', 'obj' => 0},
            'p8' => {'relx' => 0.23, 'rely' => 0.665, 'width' => 16, 'btnW' => 45,
                     'btnH' => 36, 'obj' => 0},
            'p9' => {'relx' => 0.45, 'rely' => 0.9, 'width' => 20, 'btnW' => 66,
                     'btnH' => 36, 'obj' => 0},
            'p10' => {'relx' => 0.53, 'rely' => 0.9, 'width' => 20, 'btnW' => 66,
                      'btnH' => 36, 'obj' => 0},
            'p11' => {'relx' => 0.452, 'rely' => 0.601, 'width' => 120, 'obj' => 0},
            'p12' => {'relx' => 0.70, 'rely' => 0.60, 'width' => 250, 'height' => 104,
                      'obj' => 0},
            'p13' => {'relx' => 0.452, 'rely' => 0.70, 'color' => '#DCDCDC', 
                      'cw' => 120, 'ch' => 160, 'card' => 'oppnt', 'obj' => 0},
            'p14' => {'text' => '-Auto-Play-', 'color' => '#DCDCDC',
                      'font' => 'Ariel 12 bold', 'relx' => 0.5, 'rely' => 0.71, 
                      'width' => 90, 'height' => 30, 'btnW' => 18, 'btnH' => 15,
                      'btnX' => 0.46, 'btnY' => 0.71, 'obj' => 0});
         my(%game1440h) = (
            'State' => 'start',
            'Pot' => 0,
            'Msg' => '',
            'FirstBet' => 'Player1',   # 'Player1' or 'Player2'
            'RaiseCount' => 0,
            'RaiseLimit' => 3,
            'BankLoan' => 100,
            'LoanLimit' => 3,
            'GameEnd' => 500,
            'AutoPlay' => 0,
            'GameCount' => 0,
            'WinHistory' => [],
            'AllHands' => [],    # n=1,2,3,4  c1c2c3c4c5:n, ...  &RankHand
            'Main' => {'Width' => 1500, 'Height' => 670, 'Font' => 'Ariel 12 normal',
                       'FontB' => 'Ariel 12 bold', 'CardW' => 190, 'CardH' => 270,
                       'FontLB' => 'Ariel 14 bold', 'BackImg' => 'Felt_1500x670.jpg',
                       'BackObj' => 0},
            'Deck' => {'Cards' => [], 'Drawn' => [], 'dPos' => 0, 'Back' => '',
                       'File' => ''},
            'Player1' => {'Name' => 'Player', 'Bankroll' => 100, 'LoanCount' => 0, 
                          'Value' => 0, 'Hand' => [], 'HandScore' => 0, 'Msg' => '', 
                          'HandRank' => '', 'OpponentBet' => 0, 'PreLoadCount' => 0},
            'Player2' => {'Name' => 'Computer', 'Bankroll' => 100, 'LoanCount' => 0, 
                          'Value' => 0, 'Hand' => [], 'HandScore' => 0, 'Msg' => '', 
                          'HandRank' => '', 'OpponentBet' => 0, 'PreLoadCount' => 0},
            'Opponent' => {'Brian' => 3, 'Vicky' => 3, 'Mark' => 4, 'Ashley' => 2,
                           'Bob' => 2, 'Nadia' => 5});  # Value is skill level
            
         %$Header = %{ dclone(\%header1440h) };
         %$Cards = %{ dclone(\%cards1440h) };
         %$Footer = %{ dclone(\%footer1440h) };
         %$Pref = %{ dclone(\%pref1440h) };
         %$Game = %{ dclone(\%game1440h) };
      }
   }
   elsif ($Res >= 1080) {
      if ($Ornt =~ m/^v/i) {
         &DisplayDebug(1, "LoadGuiData header1080v");
         my(%header1080v) = (
            '01' => {'text' => 'frame', 'color' => '#010101', 'relx' => 0.113,
                     'rely' => 0.048, 'width' => 120, 'height' => 55, 
                     'borderWidth' => 2, 'obj' => 0}, 
            '02' => {'text' => 'frame', 'color' => '#010101', 'relx' => 0.5,
                     'rely' => 0.048, 'width' => 85, 'height' => 55, 
                     'borderWidth' => 2, 'obj' => 0}, 
            '03' => {'text' => 'frame', 'color' => '#010101', 'relx' => 0.885,
                     'rely' => 0.048, 'width' => 120, 'height' => 55, 
                     'borderWidth' => 2, 'obj' => 0}, 

            '04' => {'text' => 'Player1,Name', 'color' => '#DCDCDC',
                     'relx' => 0.108, 'rely' => 0.038, 'width' => 100, 'height' => 20,
                     'font' => 'Ariel 12 bold', 'obj' => 0}, 
            '05' => {'text' => '-Pot-', 'color' => '#DCDCDC', 'relx' => 0.5,
                     'rely' => 0.038, 'width' => 80, 'height' => 20, 'obj' => 0,
                     'font' => 'Ariel 12 bold'}, 
            '06' => {'text' => 'Player2,Name', 'color' => '#DCDCDC', 'relx' => 0.885,
                     'rely' => 0.038, 'width' => 100, 'height' => 20, 'obj' => 0,
                     'font' => 'Ariel 12 bold'},
                     
            '07' => {'text' => 'Player1,Bankroll', 'color' => '#70E397', 
                     'relx' => 0.108, 'rely' => 0.06, 'width' => 50, 'height' => 20,
                     'font' => 'Ariel 12 bold', 'obj' => 0},
            '08' => {'text' => 'Pot', 'color' => '#FFC04A', 'relx' => 0.5, 
                     'rely' => 0.06, 'width' => 50, 'height' => 20, 'obj' => 0,
                     'font' => 'Ariel 12 bold'},
            '09' => {'text' => 'Player2,Bankroll', 'color' => '#6FE296', 'relx' => 0.885,
                     'rely' => 0.06, 'width' => 50, 'height' => 20, 'obj' => 0,
                     'font' => 'Ariel 12 bold'}, 
                     
            '10' => {'text' => 'Player1,Msg', 'color' => '#70E397', 'relx' => 0.12,
                     'rely' => 0.93, 'width' => 225, 'height' => 20, 'obj' => 0,
                     'font' => 'Ariel 12 normal'},
            '11' => {'text' => 'Player2,Msg', 'color' => '#70E397', 'relx' => 0.875,
                     'rely' => 0.925, 'width' => 225, 'height' => 20,
                     'font' => 'Ariel 12 normal', 'obj' => 0},
            '12' => {'text' => 'Msg', 'color' => '#DCDCDC', 'relx' => 0.5, 
                     'rely' => 0.89, 'width' => 700, 'height' => 20, 'obj' => 0,
                     'font' => 'Ariel 12 normal'});
         my(%cards1080v) = (
            '01' => {'relx' => 0.068, 'rely' => 0.09, 'obj' => 0}, 
            '02' => {'relx' => 0.068, 'rely' => 0.25, 'obj' => 0}, 
            '03' => {'relx' => 0.068, 'rely' => 0.41, 'obj' => 0}, 
            '04' => {'relx' => 0.068, 'rely' => 0.57, 'obj' => 0}, 
            '05' => {'relx' => 0.068, 'rely' => 0.73, 'obj' => 0},
            '06' => {'relx' => 0.842, 'rely' => 0.09, 'obj' => 0}, 
            '07' => {'relx' => 0.842, 'rely' => 0.25, 'obj' => 0}, 
            '08' => {'relx' => 0.842, 'rely' => 0.41, 'obj' => 0}, 
            '09' => {'relx' => 0.842, 'rely' => 0.57, 'obj' => 0}, 
            '10' => {'relx' => 0.842, 'rely' => 0.73, 'obj' => 0}); 
         my(%footer1080v) = (
            '1' => {'text' => '$5', 'relx' => 0.355, 'rely' => 0.91, 'btnW' => 50,
                    'btnH' => 30, 'obj' => 0}, 
            '2' => {'text' => '$10', 'relx' => 0.415, 'rely' => 0.91, 'btnW' => 50,
                    'btnH' => 30, 'obj' => 0}, 
            '3' => {'text' => '$15', 'relx' => 0.475, 'rely' => 0.91, 'btnW' => 50,
                    'btnH' => 30, 'obj' => 0}, 
            '4' => {'text' => '$20', 'relx' => 0.535, 'rely' => 0.91, 'btnW' => 50,
                    'btnH' => 30, 'obj' => 0}, 
            '5' => {'text' => '$25', 'relx' => 0.595, 'rely' => 0.91, 'btnW' => 50,
                    'btnH' => 30, 'obj' => 0},
            '6' => {'text' => 'Deal', 'relx' => 0.36, 'rely' => 0.95, 'btnWh' => 65,
                    'btnH' => 30, 'obj' => 0}, 
            '7' => {'text' => 'Discard', 'relx' => 0.43, 'rely' => 0.95,
                    'btnW' => 70, 'btnH' => 30, 'obj' => 0}, 
            '8' => {'text' => 'Call', 'relx' => 0.502, 'rely' => 0.95, 'btnW' => 65,
                    'btnH' => 30, 'obj' => 0}, 
            '9' => {'text' => 'Drop', 'relx' => 0.575, 'rely' => 0.95, 'btnW' => 65,
                    'btnH' => 30, 'obj' => 0}); 
         my(%pref1080v) = (
            'p0' => {'width' => 1200, 'height' => 600, 'obj' => 0, 
                     'backImg' => 'Felt_1200x600.jpg', 'font' => 'Ariel 13 bold'},
            'p1' => {'text' => '--', 'color' => '#DCDCDC', 'font' => 'Ariel 13 bold',
                     'relx' => 0.5, 'rely' => 0.06, 'width' => 335, 'height' => 20,
                     'obj' => 0}, 
            'p2' => {'text' => '--', 'color' => '#DCDCDC', 'relx' => 0.08, 
                     'rely' => 0.09, 'width' => 1000, 'height' => 135, 
                     'font' => 'Ariel 13 bold', 'obj' => 0},
            'p3' => {'text' => '-Cardback-', 'color' => '#DCDCDC', 
                     'font' => 'Ariel 13 bold', 'relx' => 0.18, 'rely' => 0.605,
                     'width' => 100, 'height' => 20, 'obj' => 0},
            'p4' => {'text' => "-What's your name?-", 'color' => '#DCDCDC',
                     'font' => 'Ariel 13 bold', 'relx' => 0.479, 'rely' => 0.605,
                     'width' => 200, 'height' => 20, 'obj' => 0},
            'p5' => {'text' => '-Opponents-', 'color' => '#DCDCDC', 'relx' => 0.78, 
                     'font' => 'Ariel 13 bold', 'rely' => 0.605, 'width' => 250,
                     'height' => 20, 'obj' => 0},
            'p6' => {'relx' => 0.11, 'rely' => 0.69, 'width' => 10, 'btnW' => 35,
                     'btnH' => 30, 'obj' => 0}, 
            'p7' => {'relx' => 0.147, 'rely' => 0.632, 'cw' => 80, 'ch' => 105,
                     'backs' => [], 'card' => 'back', 'obj' => 0},
            'p8' => {'relx' => 0.22, 'rely' => 0.69, 'width' => 10, 'btnW' => 35,
                     'btnH' => 30, 'obj' => 0},
            'p9' => {'relx' => 0.375, 'rely' => 0.91, 'width' => 15, 'btnW' => 48,
                     'btnH' => 35, 'obj' => 0},
            'p10' => {'relx' => 0.575, 'rely' => 0.91, 'width' => 15, 'btnW' => 48,
                      'btnH' => 35, 'obj' => 0},
            'p11' => {'relx' => 0.405, 'rely' => 0.632, 'width' => 175, 'height' => 23,
                      'obj' => 0},
            'p12' => {'relx' => 0.68, 'rely' => 0.63, 'width' => 250, 'height' => 133,
                      'obj' => 0},
            'p13' => {'relx' => 0.43, 'rely' => 0.70, 'color' => '#DCDCDC', 
                      'cw' => 110, 'ch' => 140, 'card' => 'oppnt', 'obj' => 0},
            'p14' => {'text' => '-Auto-Play-', 'color' => '#DCDCDC',
                      'font' => 'Ariel 13 bold', 'relx' => 0.76, 'rely' => 0.91, 
                      'width' => 96, 'height' => 18, 'btnW' => 15, 'btnH' => 13,
                      'btnX' => 0.708, 'btnY' => 0.91, 'obj' => 0});
         my(%game1080v) = (
            'State' => 'start',
            'Pot' => 0,
            'Msg' => '',
            'FirstBet' => 'Player1',   # 'Player1' or 'Player2'
            'RaiseCount' => 0,
            'RaiseLimit' => 3,
            'BankLoan' => 100,
            'LoanLimit' => 3,
            'GameEnd' => 500,
            'AutoPlay' => 0,
            'GameCount' => 0,
            'WinHistory' => [],
            'AllHands' => [],    # n=1,2,3,4  c1c2c3c4c5:n, ...  &RankHand
            'Main' => {'Width' => 1200, 'Height' => 950, 'Font' => 'Ariel 11 normal',
                       'FontB' => 'Ariel 11 bold', 'CardW' => 105, 'CardH' => 140,
                       'FontLB' => 'Ariel 12 bold', 'BackImg' => 'Felt_1200x950.jpg',
                       'BackObj' => 0},
            'Deck' => {'Cards' => [], 'Drawn' => [], 'dPos' => 0, 'Back' => '',
                       'File' => ''},
            'Player1' => {'Name' => 'Player', 'Bankroll' => 100, 'LoanCount' => 0, 
                          'Value' => 0, 'Hand' => [], 'HandScore' => 0, 'Msg' => '', 
                          'HandRank' => '', 'OpponentBet' => 0, 'PreLoadCount' => 0},
            'Player2' => {'Name' => 'Computer', 'Bankroll' => 100, 'LoanCount' => 0, 
                          'Value' => 0, 'Hand' => [], 'HandScore' => 0, 'Msg' => '', 
                          'HandRank' => '', 'OpponentBet' => 0, 'PreLoadCount' => 0},
            'Opponent' => {'Brian' => 3, 'Vicky' => 3, 'Mark' => 4, 'Ashley' => 2,
                           'Bob' => 2, 'Nadia' => 5});  # Value is skill level
         %$Header = %{ dclone(\%header1080v) };
         %$Cards = %{ dclone(\%cards1080v) };
         %$Footer = %{ dclone(\%footer1080v) };
         %$Pref = %{ dclone(\%pref1080v) };
         %$Game = %{ dclone(\%game1080v) };
      }
      else {
         &DisplayDebug(1, "LoadGuiData header1080h");
         my(%header1080h) = (
            '01' => {'text' => 'frame', 'color' => '#010101', 'relx' => 0.132,
                     'rely' => 0.103, 'width' => 133, 'height' => 65, 
                     'borderWidth' => 2, 'obj' => 0}, 
            '02' => {'text' => 'frame', 'color' => '#010101', 'relx' => 0.494,
                     'rely' => 0.103, 'width' => 75, 'height' => 65, 
                     'borderWidth' => 2, 'obj' => 0}, 
            '03' => {'text' => 'frame', 'color' => '#010101', 'relx' => 0.862,
                     'rely' => 0.103, 'width' => 133, 'height' => 65, 
                     'borderWidth' => 2, 'obj' => 0}, 
                     
            '04' => {'text' => 'Player1,Name', 'color' => '#DCDCDC',
                     'relx' => 0.13, 'rely' => 0.08, 'width' => 120, 'height' => 22,
                     'font' => 'Ariel 14 bold', 'obj' => 0}, 
            '05' => {'text' => '-Pot-', 'color' => '#DCDCDC', 'relx' => 0.495,
                     'rely' => 0.08, 'width' => 50, 'height' => 22, 'obj' => 0,
                     'font' => 'Ariel 14 bold'}, 
            '06' => {'text' => 'Player2,Name', 'color' => '#DCDCDC', 'relx' => 0.86,
                     'rely' => 0.08, 'width' => 120, 'height' => 22, 'obj' => 0,
                     'font' => 'Ariel 14 bold'},
                     
            '07' => {'text' => 'Player1,Bankroll', 'color' => '#70E397', 
                     'relx' => 0.13, 'rely' => 0.13, 'width' => 120, 'height' => 22,
                     'font' => 'Ariel 14 bold', 'obj' => 0},
            '08' => {'text' => 'Pot', 'color' => '#FFC04A', 'relx' => 0.495, 
                     'rely' => 0.13, 'width' => 60, 'height' => 22, 'obj' => 0,
                     'font' => 'Ariel 14 bold'},
            '09' => {'text' => 'Player2,Bankroll', 'color' => '#6FE296', 'relx' => 0.86,
                     'rely' => 0.13, 'width' => 60, 'height' => 22, 'obj' => 0,
                     'font' => 'Ariel 14 bold'}, 
                     
            '10' => {'text' => 'Player1,Msg', 'color' => '#70E397', 'relx' => 0.138,
                     'rely' => 0.84, 'width' => 225, 'height' => 22, 'obj' => 0,
                     'font' => 'Ariel 13 normal'},
            '11' => {'text' => 'Player2,Msg', 'color' => '#70E397', 
                     'relx' => 0.86, 'rely' => 0.82, 'width' => 225, 'height' => 22,
                     'font' => 'Ariel 13 normal', 'obj' => 0},
            '12' => {'text' => 'Msg', 'color' => '#DCDCDC', 'relx' => 0.5, 
                     'rely' => 0.715, 'width' => 600, 'height' => 22, 'obj' => 0,
                     'font' => 'Ariel 13 normal'});
         my(%cards1080h) = (
            '01' => {'relx' => 0.098, 'rely' => 0.226, 'obj' => 0}, 
            '02' => {'relx' => 0.258, 'rely' => 0.226, 'obj' => 0}, 
            '03' => {'relx' => 0.418, 'rely' => 0.226, 'obj' => 0}, 
            '04' => {'relx' => 0.578, 'rely' => 0.226, 'obj' => 0}, 
            '05' => {'relx' => 0.738, 'rely' => 0.226, 'obj' => 0},
            '06' => {'relx' => 0.198, 'rely' => 0.226, 'obj' => 0}, 
            '07' => {'relx' => 0.322, 'rely' => 0.226, 'obj' => 0}, 
            '08' => {'relx' => 0.446, 'rely' => 0.226, 'obj' => 0}, 
            '09' => {'relx' => 0.570, 'rely' => 0.226, 'obj' => 0}, 
            '10' => {'relx' => 0.694, 'rely' => 0.226, 'obj' => 0});
         my(%footer1080h) = (
            '1' => {'text' => '$5', 'relx' => 0.355, 'rely' => 0.80, 'btnW' => 50,
                    'btnH' => 30, 'obj' => 0}, 
            '2' => {'text' => '$10', 'relx' => 0.415, 'rely' => 0.80, 'btnW' => 50,
                    'btnH' => 30, 'obj' => 0}, 
            '3' => {'text' => '$15', 'relx' => 0.475, 'rely' => 0.80, 'btnW' => 50,
                    'btnH' => 30, 'obj' => 0}, 
            '4' => {'text' => '$20', 'relx' => 0.535, 'rely' => 0.80, 'btnW' => 50,
                    'btnH' => 30, 'obj' => 0}, 
            '5' => {'text' => '$25', 'relx' => 0.595, 'rely' => 0.80, 'btnW' => 50,
                    'btnH' => 30, 'obj' => 0},
            '6' => {'text' => 'Deal', 'relx' => 0.36, 'rely' => 0.885, 'btnW' => 65,
                    'btnH' => 30, 'obj' => 0}, 
            '7' => {'text' => 'Discard', 'relx' => 0.424, 'rely' => 0.885,
                    'btnW' => 88, 'btnH' => 30, 'obj' => 0}, 
            '8' => {'text' => 'Call', 'relx' => 0.507, 'rely' => 0.885, 'btnW' => 65,
                    'btnH' => 30, 'obj' => 0}, 
            '9' => {'text' => 'Drop', 'relx' => 0.575, 'rely' => 0.885, 'btnW' => 65,
                    'btnH' => 30, 'obj' => 0}); 
         my(%pref1080h) = (
            'p0' => {'width' => 1200, 'height' => 600, 'obj' => 0, 
                     'backImg' => 'Felt_1200x600.jpg', 'font' => 'Ariel 13 bold'},
            'p1' => {'text' => '--', 'color' => '#DCDCDC', 'font' => 'Ariel 13 bold',
                     'relx' => 0.5, 'rely' => 0.06, 'width' => 335, 'height' => 20,
                     'obj' => 0}, 
            'p2' => {'text' => '--', 'color' => '#DCDCDC', 'relx' => 0.08, 
                     'rely' => 0.09, 'width' => 1000, 'height' => 135, 
                     'font' => 'Ariel 13 bold', 'obj' => 0},
            'p3' => {'text' => '-Cardback-', 'color' => '#DCDCDC', 
                     'font' => 'Ariel 13 bold', 'relx' => 0.18, 'rely' => 0.615,
                     'width' => 100, 'height' => 20, 'obj' => 0},
            'p4' => {'text' => "-What's your name?-", 'color' => '#DCDCDC',
                     'font' => 'Ariel 13 bold', 'relx' => 0.479, 'rely' => 0.615,
                     'width' => 200, 'height' => 20, 'obj' => 0},
            'p5' => {'text' => '-Opponents-', 'color' => '#DCDCDC', 'relx' => 0.78, 
                     'font' => 'Ariel 13 bold', 'rely' => 0.615, 'width' => 250,
                     'height' => 20, 'obj' => 0},
            'p6' => {'relx' => 0.11, 'rely' => 0.70, 'width' => 10, 'btnW' => 35,
                     'btnH' => 30, 'obj' => 0}, 
            'p7' => {'relx' => 0.147, 'rely' => 0.642, 'cw' => 80, 'ch' => 105,
                     'backs' => [], 'card' => 'back', 'obj' => 0},
            'p8' => {'relx' => 0.22, 'rely' => 0.70, 'width' => 10, 'btnW' => 35,
                     'btnH' => 30, 'obj' => 0},
            'p9' => {'relx' => 0.41, 'rely' => 0.90, 'width' => 15, 'btnW' => 48,
                     'btnH' => 35, 'obj' => 0},
            'p10' => {'relx' => 0.54, 'rely' => 0.90, 'width' => 15, 'btnW' => 48,
                      'btnH' => 35, 'obj' => 0},
            'p11' => {'relx' => 0.405, 'rely' => 0.642, 'width' => 175, 'height' => 23,
                      'obj' => 0},
            'p12' => {'relx' => 0.68, 'rely' => 0.64, 'width' => 250, 'height' => 133,
                      'obj' => 0},
            'p13' => {'relx' => 0.43, 'rely' => 0.70, 'color' => '#DCDCDC', 
                      'cw' => 110, 'ch' => 140, 'card' => 'oppnt', 'obj' => 0},
            'p14' => {'text' => '-Auto-Play-', 'color' => '#DCDCDC',
                      'font' => 'Ariel 13 bold', 'relx' => 0.486, 'rely' => 0.76, 
                      'width' => 96, 'height' => 18, 'btnW' => 15, 'btnH' => 13,
                      'btnX' => 0.43, 'btnY' => 0.76, 'obj' => 0});
         my(%game1080h) = (
            'State' => 'start',
            'Pot' => 0,
            'Msg' => '',
            'FirstBet' => 'Player1',   # 'Player1' or 'Player2'
            'RaiseCount' => 0,
            'RaiseLimit' => 3,
            'BankLoan' => 100,
            'LoanLimit' => 3,
            'GameEnd' => 500,
            'AutoPlay' => 0,
            'GameCount' => 0,
            'WinHistory' => [],
            'AllHands' => [],    # n=1,2,3,4  c1c2c3c4c5:n, ...  &RankHand
            'Main' => {'Width' => 1200, 'Height' => 600, 'Font' => 'Ariel 12 normal',
                       'FontB' => 'Ariel 12 bold', 'CardW' => 175, 'CardH' => 250,
                       'FontLB' => 'Ariel 13 bold', 'BackImg' => 'Felt_1200x600.jpg',
                       'BackObj' => 0},
            'Deck' => {'Cards' => [], 'Drawn' => [], 'dPos' => 0, 'Back' => '',
                       'File' => ''},
            'Player1' => {'Name' => 'Player', 'Bankroll' => 100, 'LoanCount' => 0, 
                          'Value' => 0, 'Hand' => [], 'HandScore' => 0, 'Msg' => '', 
                          'HandRank' => '', 'OpponentBet' => 0, 'PreLoadCount' => 0},
            'Player2' => {'Name' => 'Computer', 'Bankroll' => 100, 'LoanCount' => 0, 
                          'Value' => 0, 'Hand' => [], 'HandScore' => 0, 'Msg' => '', 
                          'HandRank' => '', 'OpponentBet' => 0, 'PreLoadCount' => 0},
            'Opponent' => {'Brian' => 3, 'Vicky' => 3, 'Mark' => 4, 'Ashley' => 2,
                           'Bob' => 2, 'Nadia' => 5});  # Value is skill level
            
         %$Header = %{ dclone(\%header1080h) };
         %$Cards = %{ dclone(\%cards1080h) };
         %$Footer = %{ dclone(\%footer1080h) };
         %$Pref = %{ dclone(\%pref1080h) };
         %$Game = %{ dclone(\%game1080h) };
      }    
   }
   else {
      if ($Ornt =~ m/^v/i) {
         &DisplayDebug(1, "LoadGuiData header720v");
         my(%header720v) = (
            '01' => {'text' => 'frame', 'color' => '#303030', 'relx' => 0.13,
                     'rely' => 0.055, 'width' => 108, 'height' => 46, 
                     'borderWidth' => 0.5, 'obj' => 0}, 
            '02' => {'text' => 'frame', 'color' => '#303030', 'relx' => 0.495, 
                     'rely' => 0.055, 'width' => 87, 'height' => 46, 
                     'borderWidth' => 0.5, 'obj' => 0}, 
            '03' => {'text' => 'frame', 'color' => '#303030', 'relx' => 0.86,
                     'rely' => 0.055, 'width' => 107, 'height' => 46, 
                     'borderWidth' => 0.5, 'obj' => 0}, 
                     
            '04' => {'text' => 'Player1,Name', 'color' => '#DCDCDC',
                    'relx' => 0.13, 'rely' => 0.04, 'width' => 100, 
                    'height' => 20, 'font' => 'Ariel 11 bold', 'obj' => 0}, 
            '05' => {'text' => '-Pot-', 'color' => '#DCDCDC', 'relx' => 0.495,
                    'rely' => 0.04, 'width' => 80, 'height' => 20,
                    'font' => 'Ariel 11 bold', 'obj' => 0}, 
            '06' => {'text' => 'Player2,Name', 'color' => '#DCDCDC',
                    'relx' => 0.86, 'rely' => 0.04, 'width' => 100,
                    'height' => 20, 'font' => 'Ariel 11 bold', 'obj' => 0}, 
                    
            '07' => {'text' => 'Player1,Bankroll', 'color' => '#70E397',
                    'relx' => 0.13, 'rely' => 0.07, 'width' => 100, 
                    'height' => 20, 'font' => 'Ariel 11 bold', 'obj' => 0}, 
            '08' => {'text' => 'Pot', 'color' => '#FFC04A',
                    'relx' => 0.495, 'rely' => 0.07, 'width' => 80,
                    'height' => 20, 'font' => 'Ariel 11 bold', 'obj' => 0}, 
            '09' => {'text' => 'Player2,Bankroll', 'color' => '#6FE296',
                    'relx' => 0.86, 'rely' => 0.07, 'width' => 100, 
                    'height' => 20,'font' => 'Ariel 11 bold', 'obj' => 0},
                    
            '10' => {'text' => 'Player1,Msg', 'color' => '#70E397',
                    'relx' => 0.14, 'rely' => 0.95, 'width' => 180,
                    'height' => 20, 'font' => 'Ariel 10 normal', 'obj' => 0},
            '11' => {'text' => 'Player2,Msg', 'color' => '#70E397',
                    'relx' => 0.85, 'rely' => 0.94, 'width' => 180, 
                    'height' => 20, 'font' => 'Ariel 10 normal', 'obj' => 0},
            '12' => {'text' => 'Msg', 'relx' => 0.497, 'rely' => 0.886, 
                    'width' => 504, 'height' => 20, 'color' => '#DCDCDC', 
                    'font' => 'Ariel 10 normal', 'obj' => 0});
        my(%cards720v) = (
            '01' => {'relx' => 0.08, 'rely' => 0.11, 'obj' => 0}, 
            '02' => {'relx' => 0.08, 'rely' => 0.27, 'obj' => 0}, 
            '03' => {'relx' => 0.08, 'rely' => 0.43, 'obj' => 0}, 
            '04' => {'relx' => 0.08, 'rely' => 0.59, 'obj' => 0}, 
            '05' => {'relx' => 0.08, 'rely' => 0.75, 'obj' => 0},
            '06' => {'relx' => 0.82, 'rely' => 0.11, 'obj' => 0}, 
            '07' => {'relx' => 0.82, 'rely' => 0.27, 'obj' => 0}, 
            '08' => {'relx' => 0.82, 'rely' => 0.43, 'obj' => 0}, 
            '09' => {'relx' => 0.82, 'rely' => 0.59, 'obj' => 0}, 
            '10' => {'relx' => 0.82, 'rely' => 0.75, 'obj' => 0}); 
         my(%footer720v) = (
            '1' => {'text' => '$5', 'relx' => 0.345, 'rely' => 0.91, 'btnW' => 40,
                    'btnH' => 22, 'obj' => 0}, 
            '2' => {'text' => '$10', 'relx' => 0.405, 'rely' => 0.91, 'btnW' => 40,
                    'btnH' => 22, 'obj' => 0}, 
            '3' => {'text' => '$15', 'relx' => 0.465, 'rely' => 0.91, 'btnW' => 40,
                    'btnH' => 22, 'obj' => 0},
            '4' => {'text' => '$20', 'relx' => 0.525, 'rely' => 0.91, 'btnW' => 40,
                    'btnH' => 22, 'obj' => 0}, 
            '5' => {'text' => '$25', 'relx' => 0.585, 'rely' => 0.91, 'btnW' => 40,
                    'btnH' => 22, 'obj' => 0},
            '6' => {'text' => 'Deal', 'relx' => 0.344, 'rely' => 0.95, 'btnW' => 48,
                    'btnH' => 22, 'obj' => 0}, 
            '7' => {'text' => 'Discard', 'relx' => 0.412, 'rely' => 0.95,
                    'btnW' => 65, 'btnH' => 22, 'obj' => 0}, 
            '8' => {'text' => 'Call', 'relx' => 0.50, 'rely' => 0.95, 'btnW' => 50,
                    'btnH' => 22, 'obj' => 0}, 
            '9' => {'text' => 'Drop', 'relx' => 0.571, 'rely' => 0.95, 'btnW' => 50,
                    'btnH' => 22, 'obj' => 0}); 
         my(%pref720v) = (
            'p0' => {'width' => 800, 'height' => 360, 'backImg' => 'Felt_800x360.jpg',
                     'font' => 'Ariel 10 bold', 'obj' => 0},
            'p1' => {'text' => '--', 'color' => '#DCDCDC', 'relx' => 0.49, 
                     'rely' => 0.059, 'width' => 260, 'height' => 20, 
                     'font' => 'Ariel 10 bold', 'obj' => 0}, 
            'p2' => {'text' => '', 'color' => '#DCDCDC', 'relx' => 0.055, 
                     'rely' => 0.09, 'width' => 680, 'height' => 20, 
                     'font' => 'Ariel 10 bold', 'obj' => 0},
            'p3' => {'text' => '-Cardback-', 'color' => '#DCDCDC', 
                     'relx' => 0.171, 'rely' => 0.629, 'width' => 120, 'height' => 20, 
                     'font' => 'Ariel 10 bold', 'obj' => 0},
            'p4' => {'text' => "-What's your name?-", 'color' => '#DCDCDC',
                     'relx' => 0.485, 'rely' => 0.629, 'width' => 150, 'height' => 20, 
                     'font' => 'Ariel 10 bold', 'obj' => 0},
            'p5' => {'text' => '-Opponents-', 'color' => '#DCDCDC',
                     'relx' => 0.78, 'rely' => 0.629, 'width' => 190, 
                     'height' => 20, 'font' => 'Ariel 10 bold', 'obj' => 0},
            'p6' => {'relx' => 0.09, 'rely' => 0.72, 'btnW' => 30, 'btnH' => 26,
                     'obj' => 0}, 
            'p7' => {'relx' => 0.136, 'rely' => 0.66, 'cw' => 56, 'ch' => 72, 
                     'backs' => [], 'card' => 'back', 'obj' => 0},
            'p8' => {'relx' => 0.215, 'rely' => 0.72, 'btnW' => 30, 'btnH' => 26,
                     'obj' => 0},
            'p9' => {'relx' => 0.375, 'rely' => 0.92, 'btnW' => 38, 'btnH' => 26,
                     'obj' => 0},
            'p10' => {'relx' => 0.59, 'rely' => 0.92, 'btnW' => 38, 'btnH' => 26,
                      'obj' => 0},
            'p11' => {'relx' => 0.419, 'rely' => 0.66, 'width' => 100, 'obj' => 0},
            'p12' => {'relx' => 0.69, 'rely' => 0.66, 'width' => 170, 'height' => 70,
                      'obj' => 0},
            'p13' => {'relx' => 0.435, 'rely' => 0.74, 'color' => '#DCDCDC', 
                      'cw' => 70, 'ch' => 84, 'card' => 'oppnt', 'obj' => 0},                     
            'p14' => {'text' => '-Auto-Play-', 'color' => '#DCDCDC',
                      'font' => 'Ariel 10 bold', 'relx' => 0.782, 'rely' => 0.92, 
                      'width' => 70, 'height' => 20, 'btnW' => 12, 'btnH' => 10,
                      'btnX' => 0.725, 'btnY' => 0.92, 'obj' => 0});
         my(%game720v) = (
            'State' => 'start',
            'Pot' => 0,
            'Msg' => '',
            'FirstBet' => 'Player1',   # 'Player1' or 'Player2'
            'RaiseCount' => 0,
            'RaiseLimit' => 3,
            'BankLoan' => 100,
            'LoanLimit' => 3,
            'GameEnd' => 500,
            'AutoPlay' => 0,
            'GameCount' => 0,
            'WinHistory' => [],
            'AllHands' => [],    # n=1,2,3,4  c1c2c3c4c5:n, ...  &RankHand
            'Main' => {'Width' => 800, 'Height' => 650, 'Font' => 'Ariel 10 normal',
                       'FontB' => 'Ariel 10 bold', 'CardW' => 70, 'CardH' => 92,
                       'FontLB' => 'Ariel 11 bold', 'BackImg' => 'Felt_800x650.jpg',
                       'BackObj' => 0},
            'Deck' => {'Cards' => [], 'Drawn' => [], 'dPos' => 0, 'Back' => '',
                       'File' => ''},
            'Player1' => {'Name' => 'Player', 'Bankroll' => 100, 'LoanCount' => 0, 
                          'Value' => 0, 'Hand' => [], 'HandScore' => 0, 'Msg' => '', 
                          'HandRank' => '', 'OpponentBet' => 0, 'PreLoadCount' => 0},
            'Player2' => {'Name' => 'Computer', 'Bankroll' => 100, 'LoanCount' => 0, 
                          'Value' => 0, 'Hand' => [], 'HandScore' => 0, 'Msg' => '', 
                          'HandRank' => '', 'OpponentBet' => 0, 'PreLoadCount' => 0},
            'Opponent' => {'Brian' => 3, 'Vicky' => 3, 'Mark' => 4, 'Ashley' => 2,
                           'Bob' => 2, 'Nadia' => 5});  # Value is skill level
            
         %$Header = %{ dclone(\%header720v) };
         %$Cards = %{ dclone(\%cards720v) };
         %$Footer = %{ dclone(\%footer720v) };
         %$Pref = %{ dclone(\%pref720v) };
         %$Game = %{ dclone(\%game720v) };
      }
      else {
         &DisplayDebug(1, "LoadGuiData header720h");
         my(%header720h) = (
            '01' => {'text' => 'frame', 'color' => '#303030', 'relx' => 0.155,
                     'rely' => 0.115, 'width' => 88, 'height' => 46, 
                     'borderWidth' => 0.5, 'obj' => 0}, 
            '02' => {'text' => 'frame', 'color' => '#303030', 'relx' => 0.495, 
                     'rely' => 0.115, 'width' => 60, 'height' => 46, 
                     'borderWidth' => 0.5, 'obj' => 0}, 
            '03' => {'text' => 'frame', 'color' => '#303030', 'relx' => 0.84,
                     'rely' => 0.115, 'width' => 88, 'height' => 46, 
                     'borderWidth' => 0.5, 'obj' => 0}, 
            '04' => {'text' => 'Player1,Name', 'color' => '#DCDCDC',
                    'relx' => 0.155, 'rely' => 0.09, 'width' => 80, 
                    'height' => 20, 'font' => 'Ariel 11 bold', 'obj' => 0}, 
            '05' => {'text' => '-Pot-', 'color' => '#DCDCDC', 'relx' => 0.495,
                    'rely' => 0.09, 'width' => 50, 'height' => 20,
                    'font' => 'Ariel 11 bold', 'obj' => 0}, 
            '06' => {'text' => 'Player2,Name', 'color' => '#DCDCDC',
                    'relx' => 0.84, 'rely' => 0.09, 'width' => 80,
                    'height' => 20, 'font' => 'Ariel 11 bold', 'obj' => 0}, 
            '07' => {'text' => 'Player1,Bankroll', 'color' => '#70E397',
                    'relx' => 0.155, 'rely' => 0.14, 'width' => 80, 
                    'height' => 20, 'font' => 'Ariel 11 bold', 'obj' => 0}, 
            '08' => {'text' => 'Pot', 'color' => '#FFC04A', 
                    'relx' => 0.494, 'rely' => 0.14, 'width' => 50,
                    'height' => 20, 'font' => 'Ariel 11 bold', 'obj' => 0}, 
            '09' => {'text' => 'Player2,Bankroll', 'color' => '#6FE296',
                    'relx' => 0.84, 'rely' => 0.14, 'width' => 80, 
                    'height' => 20,'font' => 'Ariel 11 bold', 'obj' => 0},
            '10' => {'text' => 'Player1,Msg', 'color' => '#70E397',
                    'relx' => 0.16, 'rely' => 0.835, 'width' => 180,
                    'height' => 20, 'font' => 'Ariel 10 bold', 'obj' => 0},
            '11' => {'text' => 'Player2,Msg', 'color' => '#70E397', 
                    'relx' => 0.84, 'rely' => 0.835, 'width' => 180, 
                    'height' => 20, 'font' => 'Ariel 10 bold', 'obj' => 0},
            '12' => {'text' => 'Msg', 'relx' => 0.5, 'rely' => 0.74, 
                    'width' => 600, 'height' => 20, 'color' => '#DCDCDC', 
                    'font' => 'Ariel 10 normal', 'obj' => 0});
         my(%cards720h) = (
            '01' => {'relx' => 0.099, 'rely' => 0.24, 'obj' => 0}, 
            '02' => {'relx' => 0.263, 'rely' => 0.24, 'obj' => 0}, 
            '03' => {'relx' => 0.427, 'rely' => 0.24, 'obj' => 0}, 
            '04' => {'relx' => 0.591, 'rely' => 0.24, 'obj' => 0}, 
            '05' => {'relx' => 0.755, 'rely' => 0.24, 'obj' => 0},
            '06' => {'relx' => 0.099, 'rely' => 0.24, 'obj' => 0}, 
            '07' => {'relx' => 0.263, 'rely' => 0.24, 'obj' => 0}, 
            '08' => {'relx' => 0.427, 'rely' => 0.24, 'obj' => 0}, 
            '09' => {'relx' => 0.591, 'rely' => 0.24, 'obj' => 0}, 
            '10' => {'relx' => 0.755, 'rely' => 0.24, 'obj' => 0});
         my(%footer720h) = (
            '1' => {'text' => '$5', 'relx' => 0.345, 'rely' => 0.80, 'btnW' => 40,
                    'btnH' => 22, 'obj' => 0}, 
            '2' => {'text' => '$10', 'relx' => 0.405, 'rely' => 0.80, 'btnW' => 40,
                    'btnH' => 22, 'obj' => 0}, 
            '3' => {'text' => '$15', 'relx' => 0.465, 'rely' => 0.80, 'btnW' => 40,
                    'btnH' => 22, 'obj' => 0}, 
            '4' => {'text' => '$20', 'relx' => 0.525, 'rely' => 0.80, 'btnW' => 40,
                    'btnH' => 22, 'obj' => 0}, 
            '5' => {'text' => '$25', 'relx' => 0.585, 'rely' => 0.80, 'btnW' => 40,
                    'btnH' => 22, 'obj' => 0},
            '6' => {'text' => 'Deal', 'relx' => 0.345, 'rely' => 0.885, 'btnW' => 50,
                    'btnH' => 22, 'obj' => 0}, 
            '7' => {'text' => 'Discard', 'relx' => 0.415, 'rely' => 0.885, 
                    'btnW' => 64, 'btnH' => 22, 'obj' => 0}, 
            '8' => {'text' => 'Call', 'relx' => 0.503, 'rely' => 0.885, 'btnW' => 50,
                    'btnH' => 22, 'obj' => 0}, 
            '9' => {'text' => 'Drop', 'relx' => 0.573, 'rely' => 0.885, 'btnW' => 50,
                    'btnH' => 22, 'obj' => 0}); 
         my(%pref720h) = (
            'p0' => {'width' => 800, 'height' => 360, 'backImg' => 'Felt_800x360.jpg',
                     'font' => 'Ariel 10 bold', 'obj' => 0},
            'p1' => {'text' => '--', 'color' => '#DCDCDC', 'relx' => 0.49, 
                     'rely' => 0.06, 'width' => 260, 'height' => 20, 
                     'font' => 'Ariel 10 bold', 'obj' => 0}, 
            'p2' => {'text' => '', 'color' => '#DCDCDC', 'relx' => 0.055, 
                     'rely' => 0.09, 'width' => 680, 'height' => 20, 
                     'font' => 'Ariel 10 bold', 'obj' => 0},
            'p3' => {'text' => '-Cardback-', 'color' => '#DCDCDC', 
                     'relx' => 0.171, 'rely' => 0.64, 'width' => 150, 'height' => 20, 
                     'font' => 'Ariel 10 bold', 'obj' => 0},
            'p4' => {'text' => "-What's your name?-", 'color' => '#DCDCDC',
                     'relx' => 0.485, 'rely' => 0.64, 'width' => 150, 'height' => 20, 
                     'font' => 'Ariel 10 bold', 'obj' => 0},
            'p5' => {'text' => '-Opponents-', 'color' => '#DCDCDC',
                     'relx' => 0.78, 'rely' => 0.64, 'width' => 190, 
                     'height' => 20, 'font' => 'Ariel 10 bold', 'obj' => 0},
            'p6' => {'relx' => 0.09, 'rely' => 0.73, 'btnW' => 30, 'btnH' => 26,
                     'obj' => 0}, 
            'p7' => {'relx' => 0.136, 'rely' => 0.67, 'cw' => 56, 'ch' => 72, 
                     'backs' => [], 'card' => 'back', 'obj' => 0},
            'p8' => {'relx' => 0.215, 'rely' => 0.73, 'btnW' => 30, 'btnH' => 26,
                     'obj' => 0},
            'p9' => {'relx' => 0.423, 'rely' => 0.92, 'btnW' => 38, 'btnH' => 26,
                     'obj' => 0},
            'p10' => {'relx' => 0.539, 'rely' => 0.92, 'btnW' => 38, 'btnH' => 26,
                      'obj' => 0},
            'p11' => {'relx' => 0.415, 'rely' => 0.67, 'width' => 100, 'obj' => 0},
            'p12' => {'relx' => 0.69, 'rely' => 0.67, 'width' => 170, 'height' => 70,
                      'obj' => 0},
            'p13' => {'relx' => 0.435, 'rely' => 0.74, 'color' => '#DCDCDC', 
                      'cw' => 70, 'ch' => 84, 'card' => 'oppnt', 'obj' => 0},                     
            'p14' => {'text' => '-Auto-Play-', 'color' => '#DCDCDC',
                      'font' => 'Ariel 10 bold', 'relx' => 0.488, 'rely' => 0.78, 
                      'width' => 70, 'height' => 20, 'btnW' => 12, 'btnH' => 10,
                      'btnX' => 0.43, 'btnY' => 0.78, 'obj' => 0});
         my(%game720h) = (
            'State' => 'start',
            'Pot' => 0,
            'Msg' => '',
            'FirstBet' => 'Player1',   # 'Player1' or 'Player2'
            'RaiseCount' => 0,
            'RaiseLimit' => 3,
            'BankLoan' => 100,
            'LoanLimit' => 3,
            'GameEnd' => 500,
            'AutoPlay' => 0,
            'GameCount' => 0,
            'WinHistory' => [],
            'AllHands' => [],    # n=1,2,3,4  c1c2c3c4c5:n, ...  &RankHand
            'Main' => {'Width' => 800, 'Height' => 360, 'Font' => 'Ariel 10 normal',
                       'FontB' => 'Ariel 10 bold', 'CardW' => 110, 'CardH' => 155,
                       'FontLB' => 'Ariel 11 bold', 'BackImg' => 'Felt_800x360.jpg',
                       'BackObj' => 0},
            'Deck' => {'Cards' => [], 'dPos' => 0, 'Back' => '', 'File' => ''},
            'Player1' => {'Name' => 'Player', 'Bankroll' => 100, 'LoanCount' => 0, 
                          'Value' => 0, 'Hand' => [], 'HandScore' => 0, 'Msg' => '', 
                          'HandRank' => '', 'OpponentBet' => 0, 'PreLoadCount' => 0},
            'Player2' => {'Name' => 'Computer', 'Bankroll' => 100, 'LoanCount' => 0, 
                          'Value' => 0, 'Hand' => [], 'HandScore' => 0, 'Msg' => '', 
                          'HandRank' => '', 'OpponentBet' => 0, 'PreLoadCount' => 0},
            'Opponent' => {'Brian' => 3, 'Vicky' => 3, 'Mark' => 4, 'Ashley' => 2,
                           'Bob' => 2, 'Nadia' => 5});  # Value is skill level
            
         %$Header = %{ dclone(\%header720h) };
         %$Cards = %{ dclone(\%cards720h) };
         %$Footer = %{ dclone(\%footer720h) };
         %$Pref = %{ dclone(\%pref720h) };
         %$Game = %{ dclone(\%game720h) };
      }
   } 

   # ----------------------------------------------------------------------------      
   # Messages used during game play. These are common to all display resolutions.
   %GameMsgs = (
      '01' => "Welcome to Five Card Draw Poker",
      '02' => "Five Card Draw Poker",
      '03' => "%alt%You're a skilled poker player %name%. What else can you show me?" .
              "_You played a great game. What should we do now?_How about a rematch " .
              "%name%. I'll make it worth your while._Best two out of three? Or " .
              "perhaps ... something else?_Enough cards. Where's my consolation prize?_" .
              "I feel a bit chilly. Can you help me warm up?",
      '04' => "%alt%Better luck next time %name%._%name%, maybe you need some poker " .
              "lessons._%name%, next time I'll go easier with you._Thanks for " .
              "the enjoyable game %name%._Hope you enjoyed the game as much " .
              "as I did %name%._%name%, can I interest you in a consolation prize?_" .
              "%name% you look cold. Can I help you warm up?",
      '05' => "%name%, what do you wager?",
      '06' => "%alt%Fair warning %opnt%, I've been on a winning streak._" .
              "Best of luck %opnt%, you'll need it._Hi %opnt%. I've been " .
              "looking forward to playing with you._Hi %opnt%. You're goin' " .
              "down._Hi %opnt%. I've been waiting for you._Hi %opnt%. Are you " .
              "ready to play?_Hi %opnt%. I've heard tell of your prowess._I'll " .
              "make it a quick game so you don't get too cold.",
      '07' => "Tie hand score. Pot will roll to next round.",
      '08' => "%name% bets \$%value%",
      '09' => "%name% sees your \$%see% and raises you \$%value%",
      '10' => "%name% calls.",
      '11' => "%name% drops.",
      '12' => "%name% wins!",
      '13' => "Let's play a bonus round. Win another \$%value% to see more.",
      '14' => "Congratulations %name%, you've won the bonus round!",
      '15' => "%name%, mark cards with X to discard.",
      '16' => "%value% cards replaced",
      '17' => "%value% card replaced",
      '18' => "Congratulations %name%, you also won the bonus round!",
      '19' => "Gameplay:\n\nEach player starts with a \$100 bankroll. After " .
              "each hand, the winning player is awarded the value in the pot. " .
              "Up to four \$100 loans are credited to each player when their " .
              "bankroll reaches \$0. The game ends when either player wins " .
              "\$500.\n\nCards are shuffled before each hand. Players " .
              "automatically ante \$5 at the start of a hand and have the " .
              "opportunity to wager before and after card exchange. Players " .
              "bet \$5 to \$25 and may raise the bet up to three times. " .
              "Keyboard keys 1-5 can be used for bet entry and discard " .
              "identification. Cards can also be clicked to mark for " .
              "discard.\n\nUse this window to select the desired game play " .
              "options. Then click OK to begin game play.",
      '20' => "  %name%, that's all I want to see.",
      '21' => "  %name% lost it all.",
      '22' => "Sorry %name%, you lost the bonus round."
   );
   %$MsgData = %{ dclone(\%GameMsgs) };
   return 0;   
}
1;
