# ============================================================================
# FILE: DnB_Yard.pm                                                10/18/2020
#
# SERVICES:  DnB YARD PROCESSING FUNCTIONS
#
# DESCRIPTION:
#    This perl module provides yard track processing related functions used 
#    by the DnB model railroad control program. 
#
# PERL VERSION: 5.24.1
#
# =============================================================================
use strict;
# -----------------------------------------------------------------------------
# Package Declaration
# -----------------------------------------------------------------------------
package DnB_Yard;
require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
   GetYardRoute
   YardRoute
   YardLiveOverlay
   TestSound
   TestRelay
);

use DnB_Message;
use DnB_Sensor;
use DnB_Turnout;
use Time::HiRes qw(sleep);

# =============================================================================
# FUNCTION:  GetYardRoute
#
# DESCRIPTION:
#    This routine processes yard route keypad input from the user. Input is
#    obtained by reading the stderr output of the KeypadChild process. This
#    data is a single character, 0 through F, corresponding to track numbers
#    1 through 16. Two track numbers define a from/to route. A route is valid
#    if present in the %YardRouteData hash. The route identifier is set for 
#    processing by the YardRoute routine. 
#
#    Some routes are special cases in that turnout positions are train move
#    direction dependent. In these cases, if the same route is consecutively 
#    entered, the turnouts for the alternate move direction are set.
#
#    Normally, only the turnouts specific to the entered route are set. If
#    routes for the ends of tracks 3, 4, or 5 are specified within five 
#    seconds of each other, the turnouts within the track will also be set
#    for yard pass-through. The local %routeCheck hash is used to check for
#    the possible user input permutations that are possible.
#
# CALLING SYNTAX:
#    $result = &GetYardRoute(\%YardRouteData, \%KeypadData, \%GpioData,
#                            $KeypadChildPid);
#
# ARGUMENTS:
#    $YardRouteData      Pointer to %YardRouteData hash.
#    $KeypadData         Pointer to %KeypadData hash.
#    $GpioData           Pointer to %GpioData hash.
#    $KeypadChildPid     Pid of Keypad child process.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub GetYardRoute {
   my($YardRouteData, $KeypadData, $GpioData, $KeypadChildPid) = @_;
   my($pressedKey, $route, $altRoute, @checkData);
   my($keypadId) = '01';
   my($cTime) = time;
   my(%routeCheck) = ('R02' => 'R12,R21,X02', 'R20' => 'R12,R21,X02',
                      'R12' => 'R02,R20,X12', 'R21' => 'R02,R20,X12',
                      'R03' => 'R13,R31,X03', 'R30' => 'R13,R31,X03', 
                      'R13' => 'R03,R30,X13', 'R31' => 'R03,R30,X13',   
                      'R04' => 'R14,R41,X04', 'R40' => 'R14,R41,X04', 
                      'R14' => 'R04,R40,X14', 'R41' => 'R04,R40,X14');

   &DisplayDebug(2, "GetYardRoute entry ...");

   if ($$YardRouteData{'Control'}{'Inprogress'} == 0) {
      $pressedKey = Forks::Super::read_stderr($KeypadChildPid);

      if ($pressedKey ne '') {
         $pressedKey = substr($pressedKey, 0, 1);      # 1st character only.
         &DisplayDebug(1, "GetYardRoute, pressedKey: $pressedKey");

         if ($$KeypadData{$keypadId}{'Entry1'} == -1) {
            $$KeypadData{$keypadId}{'Entry1'} = $pressedKey;

            # Turn on 1st entry LED.
            $$GpioData{ $$KeypadData{$keypadId}{'Gpio'} }{'Obj'}->write(1);
            $$KeypadData{$keypadId}{'PressTime'} = $cTime + 5;
            &PlaySound("C.wav");
         }
         
         # Got 'from' and 'to' entries.
         else {
            $route = join('', 'R', $$KeypadData{$keypadId}{'Entry1'}, 
                          $pressedKey);
            $altRoute = join('', 'r', $$KeypadData{$keypadId}{'Entry1'}, 
                             $pressedKey);
            if (exists $$YardRouteData{$route}) {
               &PlaySound("G.wav");

               # Handle special route cases which involve %YardRouteData
               # entries with Rxx and rxx keys. A consecutive route entry
               # uses the alternate route key if available.
               if (exists($$YardRouteData{$altRoute}) and
                   $$YardRouteData{'Control'}{'Route'} eq $route) {
                  $route = $altRoute;
               }
               
               # Handle track 3, 4, and 5 end-to end routes. If the yard track
               # opposite end was entered < 5 seconds ago, change the route to
               # include the extra turnouts.
               elsif (exists $routeCheck{$route}) {
                  if ($cTime < $$YardRouteData{'Control'}{'RouteTime'}) {
                     @checkData = split(',', $routeCheck{$route});
                     if ($$YardRouteData{'Control'}{'Route'} eq $checkData[0] or
                         $$YardRouteData{'Control'}{'Route'} eq $checkData[1]) {
                        $route = $checkData[2];
                     }    
                     $$YardRouteData{'Control'}{'RouteTime'} = $cTime;
                  }
                  else {
                     $$YardRouteData{'Control'}{'RouteTime'} = $cTime + 5;
                  } 
               }

               # Initiate turnout setting for specified route.
               $$YardRouteData{'Control'}{'Route'} = $route;   
               $$YardRouteData{'Control'}{'Inprogress'} = 1;
               $$YardRouteData{'Control'}{'Step'} = 0;
            }
            else {
               &PlaySound("CA.wav");
            }

            # Turn off 1st entry LED.
            $$GpioData{ $$KeypadData{$keypadId}{'Gpio'} }{'Obj'}->write(0);  
            $$KeypadData{$keypadId}{'Entry1'} = -1;
         }
      }
      elsif ($$KeypadData{$keypadId}{'Entry1'} != -1) {

         # Abort 1st entry if a second keypress is not entered before 
         # timeout expiration.
         if ($cTime > $$KeypadData{$keypadId}{'PressTime'}) {

            # Turn off 1st entry LED.
            $$GpioData{ $$KeypadData{$keypadId}{'Gpio'} }{'Obj'}->write(0); 
            $$KeypadData{$keypadId}{'Entry1'} = -1;            
         } 
      }
   } 
   return 0;
}

# =============================================================================
# FUNCTION:  YardRoute
#
# DESCRIPTION:
#    This routine performs the operational functions related to yard trackage
#    routing. Only one turnout of a valid route list is positioned for each 
#    call to minimize CPU loading. 'Inprogress' is reset when all turnouts for
#    the route have be positioned.
#
# CALLING SYNTAX:
#    $result = &YardRoute(\%YardRouteData, \%TurnoutData);
#
# ARGUMENTS:
#    $YardRouteData      Pointer to %YardRouteData hash.
#    $TurnoutData        Pointer to %TurnoutData hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub YardRoute {
   my($YardRouteData, $TurnoutData) = @_;
   my($route, @routeList, $step, $turnout, $position, $moveResult);

   &DisplayDebug(2, "YardRoute entry ...");

   if ($$YardRouteData{'Control'}{'Inprogress'} == 1) {
      $route = $$YardRouteData{'Control'}{'Route'};
      if ($route ne "") {
         @routeList = split(',', $$YardRouteData{$route});
         &DisplayDebug(2, "YardRoute, route: $route   routeList: @routeList");
         if ($#routeList >= 0) {
            $step = $$YardRouteData{'Control'}{'Step'};
            if ($step <= $#routeList) {
               if ($routeList[$step] =~ m/^T(\d\d):(.+)/) {
                  $turnout = $1;
                  $position = $2;
                  &DisplayMessage("YardRoute, Route: $route, Step: " .
                                            "$step - $turnout:$position");
                  $$YardRouteData{'Control'}{'Step'}++;   # Increment step.
                  $moveResult = &MoveTurnout($position, $turnout, $TurnoutData);
                  if ($moveResult == 1) {
                     &DisplayError("YardRoute, Failed to set turnout " .
                                   "$turnout to $position");
                  }
               }
               else {
                  &DisplayError("YardRoute, Invalid route: $route step: $step.");
                  $$YardRouteData{'Control'}{'Route'} = "";
                  $$YardRouteData{'Control'}{'Inprogress'} = 0;
               }
            }
            else {                        # === Route is fully processed. ===
               $$YardRouteData{'Control'}{'Inprogress'} = 0;   
               # Retain 'Route'. Last needed for detection of special cases.
            }
         }
         else {
            &DisplayError("YardRoute, No turnout entries in route '$route'.");
            $$YardRouteData{'Control'}{'Route'} = "";
            $$YardRouteData{'Control'}{'Inprogress'} = 0;
         }
      }
      else {
         $$YardRouteData{'Control'}{'Inprogress'} = 0;
      }
   }

   return 0;
}

# =============================================================================
# FUNCTION:  YardLiveOverlay
#
# DESCRIPTION:
#    This routine is periodically called by the main loop to set the image 
#    overlay files used by the Yard Live webpage. These overlay files color the
#    yard tracks to show the current turnout lined routes. This is accomplished
#    by reading the turnout positions within each yard section and selecting the
#    appropriate image overlay file.
#
#    The @turnout position array must be formatted as follows.
#
#       T01=<value1>:<value2>: ... <value8>
#       T02=<value1>:<value2>: ... <value8>
#       ...
#
#       value order = Pos, Rate, Open, Middle, Close, MinPos, MaxPos, Id
#
# CALLING SYNTAX:
#    $result = &YardLiveOverlay(\@TurnoutPos, $WebDataDir);
#
# ARGUMENTS:
#    $TurnoutPos        Pointer to turnout position data array.
#    $WebDataDir        Directory path for output file.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub YardLiveOverlay {
   my($TurnoutPos, $WebDataDir) = @_;
   my(@tData, @tParm, @tPos, @overlayFile, $posList, $cnt, $file);
   
   # The %sections hash holds the turnouts that must be taken into consideration
   # for each section.
   my(%sections) = ('S1' => ['T22','T23','T24','T25'],
                    'S2' => ['T12','T16','T18','T19','T23'],
                    'S3' => ['T15','T16','T17','T20','T21'],
                    'S4' => ['T08','T09','T13','T14','T26'],
                    'S5' => ['T10','T11','T14','T15','T17'],
                    'S6' => ['T11','T27']);
                    
   # The overlay hash holds the mapping between the section's turnout positions
   # and the corresponding overlay image file. The matching positions are specified
   # by the secondary hash index.
   my(%overlay) = (
      'S1' => {'T22c:T23o:T24c' => 'S1-T22cT23oT24c.png',
               'T22c:T23o:T24o:T25c' => 'S1-T22cT23oT24oT25c.png',
               'T22c:T23o:T24o:T25o' => 'S1-T22cT23oT24oT25o.png',
               'T22o:T24c' => 'S1-T22oT24c.png',
               'T22o:T24o:T25c' => 'S1-T22oT24oT25c.png',
               'T22o:T24o:T25o' => 'S1-T22oT24oT25o.png'},
      'S2' => {'T12c:T16c' => 'S2-T12cT16c.png',
               'T12c:T16o:T18c' => 'S2-T12cT16oT18c.png',
               'T12c:T16o:T18o:T19c' => 'S2-T12cT16oT18oT19c.png',
               'T12c:T16o:T18o:T19o:T23c' => 'S2-T12cT16oT18oT19oT23c.png',
               'T12o' => 'S2-T12o.png'},
      'S3' => {'T15c:T16c:T17c' => 'S3-T15cT16cT17c.png',
               'T17o:T20c' => 'S3-T17oT20c.png',
               'T17o:T20o:T21c' => 'S3-T17oT20oT21c.png',
               'T17o:T20o:T21o' => 'S3-T17oT20oT21o.png'},
      'S4' => {'T08c:T09o:T26c' => 'S4-T08cT09oT26c.png',
               'T08c:T09o:T26o' => 'S4-T08cT09oT26o.png',
               'T08c:T09c:T13c' => 'S4-T08cT09cT13c.png',
               'T08c:T09c:T13c:T14c' => 'S4-T08cT09cT13cT14c.png',
               'T08o' => 'S4-T08o.png'},
      'S5' => {'T10c:T11o:T14c' => 'S5-T10cT11oT14c.png',
               'T10c:T11o:T14o' => 'S5-T10cT11oT14o.png',
               'T10o:T15c:T17c' => 'S5-T10oT15cT17c.png',
               'T10o:T15c:T17o' => 'S5-T10oT15cT17o.png',
               'T10o:T15o' => 'S5-T10oT15o.png'},
      'S6' => {'T11c:T27c' => 'S6-T11cT27c.png',
               'T11c:T27o' => 'S6-T11cT27o.png',
               'T11o' => 'S6-T11o.png'});   

   foreach my $section (keys(%sections)) {
      @tPos = ();
      @overlayFile = (join('-', $section, 'NoTrack.png'));

      # Get the current positions of the section turnouts.
      foreach my $tNmbr (@{ $sections{$section} }) {
         @tData = grep /^$tNmbr=/, @$TurnoutPos;
         chomp($tData[0]);
         if ($tData[0] =~ m/^$tNmbr=(.+)/) {
            @tParm = split(':', $1);
            
            # Account for temperature adjusted pos value.
            if (@tParm[0] > ($tParm[2]-10) and @tParm[0] < ($tParm[2]+10)) {
               push (@tPos, "${tNmbr}o");
            }
            elsif (@tParm[0] > ($tParm[4]-10) and @tParm[0] < ($tParm[4]+10)) {
               push (@tPos, "${tNmbr}c");
            }
         }
      }
      $posList = join(',', @tPos);
      
      # Check the section's overlay hash for a match and update @overlayFile
      # value if found.   
      foreach my $indx (keys(%{$overlay{$section}})) {
         @tPos = split(':', $indx);
         $cnt = 0;
         foreach my $t (@tPos) {
            $cnt++ if ($posList =~ m/$t/);
         }
         if ($cnt == scalar @tPos) {
            @overlayFile = ($overlay{$section}{$indx});
            last;
         }      
      }

      # Store the overlay file name for Yard Live use.
      $file = join('', $WebDataDir, '/Yard-', $section, '-overlay.dat');
      &WriteFile($file, \@overlayFile, '');
   }

   return 0;
}

# =============================================================================
# FUNCTION:  TestSound
#
# DESCRIPTION:
#    This routine is used to select and audition the sound files in the sound 
#    file directory when the -p command line option is specified.
#
# CALLING SYNTAX:
#    $result = &TestSound($SoundDir);
#
# ARGUMENTS:
#    $SoundDir     Directory holding sound files.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::MainRun, $main::SoundPlayer, $main::AudioVolume
# =============================================================================
sub TestSound {
   my($SoundDir) = @_;
   my(@fileList, $cnt, $key, $resp, $volume);
   my(%select) = ('00' => 'Exit test.');

   &DisplayDebug(1, "TestSound entry ...   SoundDir: $SoundDir   " .
                    "SoundPlayer: $main::SoundPlayer");

   if (-d $SoundDir) {

      # Get wav file names, sort, and build user picklist. 
      @fileList = sort grep { -f } glob "$SoundDir/*.wav";
      $cnt = 1;
      foreach my $file (@fileList) {
         $key = $cnt++;
         $key = "0$key" if (length($key) == 1);
         $select{$key} = substr($file, rindex($file, "/")+1);
      }

      #Display list to user and get selection.
      while ($main::MainRun) {
         &DisplayMessage("TestSound, ------------------------------");
         &DisplayMessage("TestSound, Enter file number to audition.");
         &DisplayMessage("TestSound, Include ,xx to change volume"  );
         &DisplayMessage("TestSound, from default $main::AudioVolume%.");
         foreach my $key (sort keys(%select)) {
            &DisplayMessage("TestSound,    $key: $select{$key}");
         }
         &DisplayMessage("TestSound, ------------------------------");
         print "$$ TestSound, Enter selection: ";
         $resp = <>;
         chomp($resp);
         if ($resp =~ m/(\d+),(.+)/) {
            $resp = $1;
            $volume = $2;
         }
         else {
            $volume = '';
         }
         $resp = "0$resp" if (length($resp) == 1);
         return 0 if ($resp eq '00');
         if (exists $select{$resp}) {
            if ($volume ne '') {
               if ($volume > 0 and $volume <= 99) {
                  &PlaySound($select{$resp}, $volume);
               }
               else {
                  &DisplayError("TestSound, Invalid volume: $volume");
               }
            }
            else {
               &PlaySound($select{$resp});
               &DisplayMessage("TestSound, playing selection $resp ...");
            }
         }
         else {
            &DisplayError("TestSound, Entry '$resp' not found.");
         }
      }
   }
   else {
      &DisplayError("TestSound, Sound file directory not found: $SoundDir");
      return 1;
   }

   return 0;
}

# =============================================================================
# FUNCTION:  TestRelay
#
# DESCRIPTION:
#    This routine is called by the DnB_main code to test the power polarity 
#    relays when the -r command line option is specified. The specified relay,
#    or all if 0, is sequentially energized and de-energized at a five second 
#    on/off rate. This test runs until terminated by ctrl-c. 
#
# CALLING SYNTAX:
#    $result = &TestRelay($Relay, \%GpioData);
#
# ARGUMENTS:
#    $Relay         Relay number to test, 0 for all.
#    $GpioData      Pointer to %GpioData hash. (polarity relays) 
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::MainRun
# =============================================================================
sub TestRelay {
   my($Relay, $GpioData) = @_;
   my($check, $relayNum);
   my($value) = 1;

   &DisplayDebug(1, "TestRelay entry ...   Relay: $Relay");
   if ($Relay !~ m/^\d+$/ or $Relay < 0 or $Relay > 3) {
      &DisplayError("TestRelay, Invalid relay number specified: '$Relay'");
      return 1;
   } 

# Run test loop until terminated.
   while ($main::MainRun) {
      foreach my $gpio (sort keys(%$GpioData)) {
         if ($gpio =~ m/^GP.+?_PR(\d\d)/) {
            $relayNum = sprintf("%d", $1);
            if ($Relay == $relayNum or $Relay == 0) {            
               $$GpioData{$gpio}{'Obj'}->write($value);  # Set relay GPIO.
               $check = $$GpioData{$gpio}{'Obj'}->read;  # Readback and check.
               if ($check != $value) {
                  &DisplayError("TestRelay, Failed to set $gpio (" .
                                $$GpioData{$gpio}{'Desc'} . ") to $value");
               }
               else {
                  &DisplayMessage("TestRelay, $gpio (" . $$GpioData{$gpio}{'Desc'} .
                                  ") set to $value");
               }
               sleep 0.5;         # Delay
            }
         }
      }
      sleep 5;
      $value = (~$value) & 1;     # Compliment the working value.
   }
   return 0;
}

return 1;
