# ============================================================================
# FILE: DnB_Mainline.pm                                             9/28/2020
#
# SERVICES:  DnB TRACK PROCESSING FUNCTIONS
#
# DESCRIPTION:
#    This perl module provides mainline track processing related functions used 
#    by the DnB model railroad control program. 
#
# PERL VERSION: 5.24.1
#
# =============================================================================
use strict;
# -----------------------------------------------------------------------------
# Package Declaration
# -----------------------------------------------------------------------------
package DnB_Mainline;
require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
   ProcessHoldover
   ProcessMidway
   ProcessWye
   HoldoverTrack
   MidwayTrack
   WyeTrack
   CheckTurnout
);

use DnB_Message;
use DnB_Sensor;
use DnB_Turnout;

# =============================================================================
# FUNCTION:  ProcessHoldover
#
# DESCRIPTION:
#    This routine performs the operational functions related to the holdover
#    track section. Functions include turnout point positioning and setting 
#    of track power polarity.
#
#    Retriggerable timers in %TrackData are used for S1, S2, and S3 to ensure
#    that a route is set only once for as long as the train activates the 
#    sensor.
#
#    The S1, S2, and S3 sensors also retrigger the 'RouteTime' if a temporary 
#    holdover route has be set ('RouteLocked') via button input. When a route
#    has been set, no other ProcessHoldover functions are performed.  
#
# CALLING SYNTAX:
#    $result = &ProcessHoldover(\%TrackData, \%SensorBit, \%SensorState, 
#                               \%TurnoutData, \%GpioData);
#
# ARGUMENTS:
#    $TrackData          Pointer to %TrackData hash. 
#    $SensorBit          Pointer to %SensorBit hash.
#    $SensorState        Pointer to %SensorState hash. 
#    $TurnoutData        Pointer to %TurnoutData hash.
#    $GpioData           Pointer to %GpioData hash. (polarity relays) 
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ProcessHoldover {
   my($TrackData, $SensorBit, $SensorState, $TurnoutData, $GpioData) = @_;
   my($moveResult, $turnout, $position, $gpio, $value, $check);
   my(%bitPos) = ('B1' => '00', 'B2' => '01', 'B3' => '02', 'S1' => '16',
                  'S2' => '17', 'S3' => '18');
   my(%routes) = (
      'InB1'  => 'T01:Close,T02:Close,T03:Close,GPIO6_PR02:0',
      'InB2'  => 'T01:Open,T03:Close,T02:Close,GPIO5_PR01:0',
      'OutB1' => 'T03:Open,T01:Open,GPIO6_PR02:1',
      'OutB2' => 'T02:Open,T01:Close,GPIO5_PR01:1');

   my(@route) = ();
   my($cTime) = time;

   &DisplayDebug(2, "ProcessHoldover entry ...");

# --- RouteLocked related processing. -----------------------------------------
   if ($$TrackData{'01'}{'RouteLocked'} == 1) {
      if (&GetSensorBit($bitPos{'S1'}, $SensorBit, $SensorState) == 1 or
          &GetSensorBit($bitPos{'S2'}, $SensorBit, $SensorState) == 1 or
          &GetSensorBit($bitPos{'S3'}, $SensorBit, $SensorState) == 1) {
         $$TrackData{'01'}{'ManualRouteTime'} = time + 60;
      }
      return 0;
   }

# --- Processing for S1 sensor disable. ---------------------------------------
# S1 sensor input is ignored for an outbound train to prevent improper turnout
# positioning; 'Direction' is set to 'Out'. 'Direction' is set back to 'In' and
# outbound route flags are reset when track block B3 is no longer occupied. 
 
   if ($$TrackData{'01'}{'Direction'} eq 'Out' and
       $$TrackData{'01'}{'WaitB3Inact'} == 1) {
      if (&GetSensorBit($bitPos{'B3'}, $SensorBit, $SensorState) == 0) {
         &DisplayMessage("ProcessHoldover, block B3 is unoccupied.");
         $$TrackData{'01'}{'Direction'} = 'In';
         $$TrackData{'01'}{'WaitB3Inact'} = 0;
#         @route = split(",", $routes{'InB1'});  # Default turnout positions.
      }
   }

# --- Sensor S1 processing. ---------------------------------------------------
   if (&GetSensorBit($bitPos{'S1'}, $SensorBit, $SensorState) == 1) {
      if ($$TrackData{'01'}{'Direction'} eq 'Out' and
          $$TrackData{'01'}{'WaitB3Inact'} == 0) {
         &DisplayDebug(1, "ProcessHoldover, S1 is active.");
         $$TrackData{'01'}{'WaitB3Inact'} = 1;
         &DisplayMessage("ProcessHoldover, waiting for block B3 to be unoccupied.");
      }

      if ($$TrackData{'01'}{'Direction'} eq 'In') {     
         if ($$TrackData{'01'}{'Timeout'} < $cTime) {  # If route not already set.
            &DisplayDebug(1, "ProcessHoldover, S1 is active.");

            # Should never have an inbound state with S2 or S3 active. But if so,
            # sound train wreck.
            if (&GetSensorBit($bitPos{'S2'}, $SensorBit, $SensorState) == 1 or
                &GetSensorBit($bitPos{'S3'}, $SensorBit, $SensorState) == 1) {
               &DisplayMessage("ProcessHoldover, inbound and outbound train wreck!");
               &PlaySound("TrainWreck3.wav");
            }

            # Alternate holdover tracks if both are unoccupied. Otherwise, route
            # inbound train to an available track.
            elsif (&GetSensorBit($bitPos{'B1'}, $SensorBit, $SensorState) == 0 and
                   &GetSensorBit($bitPos{'B2'}, $SensorBit, $SensorState) == 0) {
               if ($$TrackData{'01'}{'Last'} eq 'B1') {
                  &DisplayMessage("ProcessHoldover, routing inbound train to B2.");
                  $$TrackData{'01'}{'Last'} = 'B2';
                  @route = split(",", $routes{'InB2'});
               }
               else {
                  &DisplayMessage("ProcessHoldover, routing inbound train to B1.");
                  $$TrackData{'01'}{'Last'} = 'B1';
                  @route = split(",", $routes{'InB1'});
               }
            }
            elsif (&GetSensorBit($bitPos{'B1'}, $SensorBit, $SensorState) == 0) {
               &DisplayMessage("ProcessHoldover, routing inbound train to B1.");
               @route = split(",", $routes{'InB1'});
            }
            elsif (&GetSensorBit($bitPos{'B2'}, $SensorBit, $SensorState) == 0) {
               &DisplayMessage("ProcessHoldover, routing inbound train to B2.");
               @route = split(",", $routes{'InB2'});
            }
            else {
               &DisplayMessage("ProcessHoldover, inbound sidings " .
                               "full train wreck!");
               &PlaySound("TrainWreck3.wav");
            }
         }
         $$TrackData{'01'}{'Timeout'} = $cTime + 10;  # Disable S1 processing.
      }
   }

# --- Sensor S2 processing. ---------------------------------------------------
#  Note: A retriggerable timer is used to prevent multiple turnout settings. It
#        is possible for this timer to expire for a slow or stopped train that 
#        leaves the sensor unblocked. No adverse affect, just some CPU cycles.
#        The timer is used instead of the 'Out' direction state so that a second
#        siding departure can occur while the previous train still occupies the
#        B3 block. 
 
   elsif (&GetSensorBit($bitPos{'S2'}, $SensorBit, $SensorState) == 1) {
      if ($$TrackData{'02'}{'Timeout'} < $cTime) {  # If route not already set.
         &DisplayDebug(1, "ProcessHoldover, S2 is active.");
         &DisplayMessage("ProcessHoldover, routing outbound B2 train to B3.");
         @route = split(",", $routes{'OutB2'});
         $$TrackData{'01'}{'Direction'} = 'Out';
      }
      $$TrackData{'02'}{'Timeout'} = $cTime + 3;    # Disable S2 processing.
   }

# --- Sensor S3 processing. ---------------------------------------------------
#  Above note for S2 applies here also.

   elsif (&GetSensorBit($bitPos{'S3'}, $SensorBit, $SensorState) == 1) {
      if ($$TrackData{'03'}{'Timeout'} < $cTime) {  # If route not already set.
         &DisplayDebug(1, "ProcessHoldover, S3 is active.");
         &DisplayMessage("ProcessHoldover, routing outbound B1 train to B3.");
         @route = split(",", $routes{'OutB1'});
         $$TrackData{'01'}{'Direction'} = 'Out';
      }
      $$TrackData{'03'}{'Timeout'} = $cTime + 3;    # Disable S3 processing.
   }

# --- Set turnouts and relays if @route is specified. --------------------------
   if ($#route >= 0) {
      foreach my $device (@route) {
         if ($device =~ m/^T(\d+):(.+)/) {
            $turnout = $1;
            $position = $2;
            $moveResult = &MoveTurnout($position, $turnout, $TurnoutData);
            if ($moveResult == 1) {
               &DisplayError("ProcessHoldover, Failed to set turnout " .
                             "$turnout to $position");
            }
            else {
               &DisplayMessage("ProcessHoldover, turnout $turnout " .
                               "set to $position.");
            }
         }
         elsif ($device =~ m/^(GPIO.+?):(\d)/) {
            $gpio = $1;
            $value = $2;
            $$GpioData{$gpio}{'Obj'}->write($value);  # Set power polarity relay.
            $check = $$GpioData{$gpio}{'Obj'}->read;  # Readback and check.
            if ($check != $value) {
               &DisplayError("ProcessHoldover, Failed to set power " .
                             "relay $gpio to $value");
            }
            else {
               &DisplayMessage("ProcessHoldover, relay $gpio " .
                               "set to $value.");
            }
         }
         else {
            &DisplayError("ProcessHoldover, Invalid S1 route entry: " .
                          "$device");
         }
      }
   }
   return 0;
}

# =============================================================================
# FUNCTION:  ProcessMidway
#
# DESCRIPTION:
#    This routine performs the operational functions related to the midway
#    track section. Functions include turnout point positioning. A turnout
#    is not processed if previously locked by user button input.
#
#    Retriggerable timers in %TrackData are used for S5 and S6 to ensure
#    that a route is set only once for as long as the train activates the 
#    sensor.
#
#    The respective turnout it set back to the Inactive position after its
#    timer expires. This action is inhibited by a manually set position. In 
#    this case, reposition will occur after a 2nd timeout cycle.
#
# CALLING SYNTAX:
#    $result = &ProcessMidway(\%TrackData, \%SensorBit, \%SensorState, 
#                             \%TurnoutData);
#
# ARGUMENTS:
#    $TrackData          Pointer to %TrackData hash. 
#    $SensorBit          Pointer to %SensorBit hash.
#    $SensorState        Pointer to %SensorState hash. 
#    $TurnoutData        Pointer to %TurnoutData hash. 
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ProcessMidway {
   my($TrackData, $SensorBit, $SensorState, $TurnoutData) = @_;
   my($moveResult);
   my(%bitPos) = ('S5' => '20', 'S6' => '21');
   my($cTime) = time;

   &DisplayDebug(2, "ProcessMidway entry ...");

# --- Sensor S5 processing. ---------------------------------------------------
   if ($$TrackData{'05'}{'Locked'} == 0) {
      if (&GetSensorBit($bitPos{'S5'}, $SensorBit, $SensorState) == 1) {
         &DisplayDebug(1, "ProcessMidway, S5 is active.");

         # Move turnout if no inprogress timeout. Otherwise, restart timeout.
         if ($$TurnoutData{'05'}{'Pos'} != 
             $$TurnoutData{'05'}{ $$TrackData{'05'}{'Active'} } and
             $$TrackData{'05'}{'Timeout'} < $cTime) {

            $moveResult = &MoveTurnout($$TrackData{'05'}{'Active'}, '05', 
                                       $TurnoutData);
            if ($moveResult == 1) {
               &DisplayError("ProcessMidway, Failed to set turnout " .
                             "05 to $$TrackData{'05'}{'Active'}.");
            }
            else {
               &DisplayMessage("ProcessMidway, turnout 05 set to " .
                               "active position $$TrackData{'05'}{'Active'}.");
            }
         }
         $$TrackData{'05'}{'Timeout'} = $cTime + 15;   # Retrigger timeout.
         $$TrackData{'05'}{'ManualSet'} = 0;
      }
      else {

         # Reset turnout if a timeout has completed and turnout is not in the 
         # Inactive position. Check for turnout Pid 0 prevents additional turnout 
         # setting during the move period. 
         if ($cTime >= $$TrackData{'05'}{'Timeout'} and 
             $$TrackData{'05'}{'ManualSet'} == 0 and
             $$TurnoutData{'05'}{'Pid'} == 0 and
             $$TurnoutData{'05'}{'Pos'} != 
             $$TurnoutData{'05'}{ $$TrackData{'05'}{'Inactive'} }) {
            $moveResult = &MoveTurnout($$TrackData{'05'}{'Inactive'}, '05', 
                                       $TurnoutData);
            if ($moveResult == 1) {
               &DisplayError("ProcessMidway, Failed to set turnout " .
                             "05 to $$TrackData{'05'}{'Inactive'}.");
            }
            else {
               &DisplayMessage("ProcessMidway, turnout 05 set to " .
                               "inactive position $$TrackData{'05'}{'Inactive'}.");
            }
         }
      }
   }

# --- Sensor S6 processing. ---------------------------------------------------
   if ($$TrackData{'06'}{'Locked'} == 0) {
      if (&GetSensorBit($bitPos{'S6'}, $SensorBit, $SensorState) == 1) {
         &DisplayDebug(1, "ProcessMidway, S6 is active.");

         # Move turnout if no inprogress timeout. Otherwise, restart timeout.
         if ($$TurnoutData{'06'}{'Pos'} != 
             $$TurnoutData{'06'}{ $$TrackData{'06'}{'Active'} } and
             $$TrackData{'06'}{'Timeout'} < $cTime) {

            $moveResult = &MoveTurnout($$TrackData{'06'}{'Active'}, '06', 
                                       $TurnoutData);
            if ($moveResult == 1) {
               &DisplayError("ProcessMidway, Failed to set turnout " .
                             "06 to $$TrackData{'06'}{'Active'}.");
            }
            else {
               &DisplayMessage("ProcessMidway, turnout 06 set to " .
                               "active position $$TrackData{'06'}{'Active'}.");
            }
         }
         $$TrackData{'06'}{'Timeout'} = $cTime + 15;   # Retrigger timeout.
         $$TrackData{'06'}{'ManualSet'} = 0;
      }
      else {

         # Reset turnout if a timeout has completed and turnout is not in the 
         # Inactive position. Check for turnout Pid 0 prevents additional turnout 
         # setting during the move period. 
         if ($cTime >= $$TrackData{'06'}{'Timeout'} and 
             $$TrackData{'06'}{'ManualSet'} == 0 and
             $$TurnoutData{'06'}{'Pid'} == 0 and
             $$TurnoutData{'06'}{'Pos'} != 
             $$TurnoutData{'06'}{ $$TrackData{'06'}{'Inactive'} }) {
            $moveResult = &MoveTurnout($$TrackData{'06'}{'Inactive'}, '06', 
                                       $TurnoutData);
            if ($moveResult == 1) {
               &DisplayError("ProcessMidway, Failed to set turnout " .
                             "06 to $$TrackData{'06'}{'Inactive'}.");
            }
            else {
               &DisplayMessage("ProcessMidway, turnout 06 set to " .
                               "inactive position $$TrackData{'06'}{'Inactive'}.");
            }
         }
      }
   }
   return 0;
}

# =============================================================================
# FUNCTION:  ProcessWye
#
# DESCRIPTION:
#    This routine performs the operational functions related to the wye track
#    section. Functions include turnout point positioning and setting of track 
#    power polarity.
#
# CALLING SYNTAX:
#    $result = &ProcessWye(\%TrackData, \%SensorBit, \%SensorState,
#                          \%TurnoutData, \%GpioData);
#
# ARGUMENTS:
#    $TrackData          Pointer to %TrackData hash. 
#    $SensorBit          Pointer to %SensorBit hash.
#    $SensorState        Pointer to %SensorState hash. 
#    $TurnoutData        Pointer to %TurnoutData hash. 
#    $GpioData           Pointer to %GpioData hash. (polarity relays) 
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ProcessWye {
   my($TrackData, $SensorBit, $SensorState, $TurnoutData, $GpioData) = @_;
   my($moveResult);
   my(%bitPos) = ('S7' => '22', 'S8' => '23', 'S9' => '24');
   my($cTime) = time;

   &DisplayDebug(2, "ProcessWye entry ...");

# --- Sensor S7 processing. ---------------------------------------------------
   if (&GetSensorBit($bitPos{'S7'}, $SensorBit, $SensorState) == 1) {
      if ($$TrackData{'07'}{'Timeout'} < $cTime) {
         &DisplayDebug(1, "ProcessWye, S7 is active.");

         # Set the polarity relay based on current T7 position.
         if ($$TurnoutData{'07'}{'Pos'} == $$TurnoutData{'07'}{'Close'}) {
            if ($$TrackData{'07'}{'Polarity'} != 0) {
               $$GpioData{GPIO13_PR03}{'Obj'}->write(0);  # Set relay control bit.
               if ($$GpioData{GPIO13_PR03}{'Obj'}->read != 0) {  # Readback check.
                  &DisplayError("ProcessWye S7, Failed to set power " .
                                "relay GPIO13_PR03 to 0");
               }
               else {
                  &DisplayMessage("ProcessWye S7, power relay " .
                                  "GPIO13_PR03 set to 0.");
               }
               $$TrackData{'07'}{'Polarity'} = 0;
            }
         }
         else {
            if ($$TrackData{'07'}{'Polarity'} != 1) {
               $$GpioData{GPIO13_PR03}{'Obj'}->write(1); # Set relay control bit.
               if ($$GpioData{GPIO13_PR03}{'Obj'}->read != 1) {  # Readback check.
                  &DisplayError("ProcessWye S7, Failed to set power " .
                                "relay GPIO13_PR03 to 1");
               }
               else {
                  &DisplayMessage("ProcessWye S7, power relay " .
                                  "GPIO13_PR03 set to 1.");
               }
               $$TrackData{'07'}{'Polarity'} = 1;
            }   
         }
      }
      $$TrackData{'07'}{'Timeout'} = $cTime + 2;
   }

# --- Sensor S8 processing. ---------------------------------------------------
   if (&GetSensorBit($bitPos{'S8'}, $SensorBit, $SensorState) == 1) {
      if ($$TrackData{'08'}{'Timeout'} < $cTime) {
         &DisplayDebug(1, "ProcessWye, S8 is active.");
         if ($$TurnoutData{'07'}{'Pos'} != $$TurnoutData{'07'}{'Close'}) {
            $moveResult = &MoveTurnout('Close', '07', $TurnoutData);
            if ($moveResult == 1) {
               &DisplayError("ProcessWye S8, Failed to set turnout 07 to Close.");
            }
            else {
               &DisplayMessage("ProcessWye S8, turnout 07 set to Close.");
            }
         }
         if ($$TrackData{'07'}{'Polarity'} != 0) {
            $$GpioData{GPIO13_PR03}{'Obj'}->write(0);  # Set relay control bit.
            if ($$GpioData{GPIO13_PR03}{'Obj'}->read != 0) {   # Readback check.
               &DisplayError("ProcessWye S8, Failed to set power " .
                             "relay GPIO13_PR03 to 0");
            }
            else {
               &DisplayMessage("ProcessWye S8, power relay " .
                               "GPIO13_PR03 set to 0.");
            }
            $$TrackData{'07'}{'Polarity'} = 0;
         }
      }
      $$TrackData{'08'}{'Timeout'} = $cTime + 2;
   }

# --- Sensor S9 processing. ---------------------------------------------------
   if (&GetSensorBit($bitPos{'S9'}, $SensorBit, $SensorState) == 1) {
      if ($$TrackData{'09'}{'Timeout'} < $cTime) {
         &DisplayDebug(1, "ProcessWye, S9 is active.");
         if ($$TurnoutData{'07'}{'Pos'} != $$TurnoutData{'07'}{'Open'}) {
            $moveResult = &MoveTurnout('Open', '07', $TurnoutData);
            if ($moveResult == 1) {
               &DisplayError("ProcessWye S9, Failed to set turnout " .
                             "07 to Open.");
            }
            else {
               &DisplayMessage("ProcessWye S9, turnout 07 set to Open.");
            }
         }
         if ($$TrackData{'07'}{'Polarity'} != 1) {
            $$GpioData{GPIO13_PR03}{'Obj'}->write(1);  # Set relay control bit.
            if ($$GpioData{GPIO13_PR03}{'Obj'}->read != 1) {   # Readback check.
               &DisplayError("ProcessWye S9, Failed to set power " .
                             "relay GPIO13_PR03 to 1");
            }
            else {
               &DisplayMessage("ProcessWye S9, power relay " .
                               "GPIO13_PR03 set to 1.");
            }
            $$TrackData{'07'}{'Polarity'} = 1;
         }
      }
      $$TrackData{'09'}{'Timeout'} = $cTime + 2;
   }
   return 0;
}

# =============================================================================
# FUNCTION:  HoldoverTrack
#
# DESCRIPTION:
#    This routine processes the user buttons associated with turnouts T01, T02,
#    and T03 in the Holdover track section. Four buttons are provided for user
#    input of a desired route. In response, this routine sets the turnouts as
#    needed. The turnouts will be 'locked' in the requested route and a LED
#    indicator on the keypad will be illuminated. This route will be persisted
#    until one of the following conditions occur.
#
#    1. Any button on the holdover route keypad is pressed.
#    2. No S1, S2, or S3 sensor activity for 60 seconds.
#
# CALLING SYNTAX:
#    $result = &HoldoverTrack($ButtonInput, \%TurnoutData, \%TrackData, 
#                             \%GpioData);
#
# ARGUMENTS:
#    $ButtonInput        User entered button input, if any.
#    $TurnoutData        Pointer to %TurnoutData hash.
#    $TrackData          Pointer to %TrackData hash.
#    $GpioData           Pointer to %GpioData hash. (polarity relays) 
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub HoldoverTrack {
   my($ButtonInput, $TurnoutData, $TrackData, $GpioData) = @_;
   my($result, $button, $route, $gpio, $value, $turnout, $position, $check);
   my($moveResult);
   my(%routes) = (
      '04' => 'T01:Close,T02:Close,GPIO6_PR02:0',
      '05' => 'T01:Close,T02:Open,GPIO5_PR01:1',
      '06' => 'T01:Open,T03:Close,GPIO5_PR01:0',
      '07' => 'T01:Open,T03:Open,GPIO6_PR02:1');
   my(@route) = ();
   &DisplayDebug(2, "HoldoverTrack entry ...  ButtonInput: '$ButtonInput'");

   # Process new button press.
   if ($ButtonInput =~ m/s(04)/ or $ButtonInput =~ m/s(05)/ or
       $ButtonInput =~ m/s(06)/ or $ButtonInput =~ m/s(07)/) {
      $button = $1;
      $route = join('', 'R', ($button - 3));
      &DisplayMessage("HoldoverTrack, route $route requested.");

      # ----------------------------------
      # If a route is currently active, reset and done.
      if ($$TrackData{'01'}{'RouteLocked'} == 1) {
         &PlaySound("Unlock.wav");
         $$TrackData{'01'}{'RouteTime'} = time - 1;     # Reset route timeout
         $$GpioData{'GPIO26_HLCK'}{'Obj'}->write(0);    # Button LED off
         $$TrackData{'01'}{'RouteLocked'} = 0;
         &DisplayMessage("HoldoverTrack, route unlocked by button.");
         return 0;
      }
      @route = split(",", $routes{$button});

      # ----------------------------------
      # Set turnouts.
      if ($#route >= 0) { 
         foreach my $device (@route) {
            if ($device =~ m/^T(\d+):(.+)/) {
               $turnout = $1;
               $position = $2;
               $moveResult = &MoveTurnout($position, $turnout, $TurnoutData);
               if ($moveResult == 1) {
                  &DisplayError("ProcessHoldover, Failed to set " .
                                "turnout $turnout to $position");
               }
               else {
                  &DisplayMessage("ProcessHoldover, turnout " .
                                  "$turnout set to $position.");
               }
            }
            elsif ($device =~ m/^(GPIO.+?):(\d)/) {
               $gpio = $1;
               $value = $2;
               $$GpioData{$gpio}{'Obj'}->write($value);  # Set polarity relay.
               $check = $$GpioData{$gpio}{'Obj'}->read;  # Readback and check.
               if ($check != $value) {
                  &DisplayError("HoldoverTrack, Failed to set " .
                                "power relay $gpio to $value");
               }
               else {
                  &DisplayMessage("ProcessHoldover, relay $gpio " .
                                  "set to $value.");
               }
            }
         }

         $$GpioData{'GPIO26_HLCK'}{'Obj'}->write(1);   # Button LED on
         $$TrackData{'01'}{'RouteLocked'} = 1;
         $$TrackData{'01'}{'RouteTime'} = time + 60;   # Set route timeout
         &DisplayMessage("HoldoverTrack, route $route is locked.");
         &PlaySound("Lock.wav");
      }
      else {
         &DisplayMessage("HoldoverTrack, $route is invalid for " .
                         "train movement direction.");
         &PlaySound("GE.wav");
      }
   }

   # If a route is set, and has timed out, reset the lock.
   else {
      if ($$TrackData{'01'}{'RouteLocked'} == 1 and
          $$TrackData{'01'}{'RouteTime'} < time) {
         &PlaySound("Unlock.wav");
         $$TrackData{'01'}{'RouteLocked'} = 0;
         $$GpioData{'GPIO26_HLCK'}{'Obj'}->write(0);        # Button LED off
         &DisplayMessage("HoldoverTrack, route unlocked by timeout.");
      }
   }
   return 0;
}

# =============================================================================
# FUNCTION:  MidwayTrack
#
# DESCRIPTION:
#    This routine processes the user buttons associated with turnouts T05 and
#    T06. These buttons, 00 and 01, are used to manually position the turnout 
#    or lock it in its current position.
#
# CALLING SYNTAX:
#    $result = &MidwayTrack($ButtonInput, \%ButtonData, \%TurnoutData, 
#                           \%TrackData, \%SensorBit, \%SensorState);
#
# ARGUMENTS:
#    $ButtonInput        User entered button input, if any.
#    $ButtonData         Pointer to %ButtonData hash.
#    $TurnoutData        Pointer to %TurnoutData hash.
#    $TrackData          Pointer to %TrackData hash.
#    $SensorBit          Pointer to %SensorBit hash.
#    $SensorState        Pointer to %SensorState hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub MidwayTrack {
   my($ButtonInput, $ButtonData, $TurnoutData, $TrackData, $SensorBit,
      $SensorState) = @_;
   my($pressType, $moveResult, $turnout1, $turnout2, $position);

   &DisplayDebug(2, "MidwayTrack entry ...  ButtonInput: " .
                              "'$ButtonInput'");

   # Parse and process the button input.
   if ($ButtonInput =~ m/(d)(00)/ or $ButtonInput =~ m/(d)(01)/ or
       $ButtonInput =~ m/(s)(00)/ or $ButtonInput =~ m/(s)(01)/) {
      $pressType = $1;
      $turnout1 = $$ButtonData{$2}{'Turnout1'};
      $turnout2 = $$ButtonData{$2}{'Turnout2'};
      &DisplayDebug(1, "MidwayTrack, pressType: $pressType   " .
                       "turnout1: $turnout1   turnout2: $turnout2");

      # A single button press unlocks the turnout. ProcessMidway code
      # will reposition the turnout to its inactive position.
      if ($pressType eq 's' and $$TrackData{$turnout1}{'Locked'} == 1) {
         $$TrackData{$turnout1}{'Locked'} = 0;
         $$TrackData{$turnout1}{'ManualSet'} = 0;
         &DisplayMessage("MidwayTrack, turnout $turnout1 is unlocked.");
         &PlaySound("Unlock.wav");
         return 0;
      }

      # Ignore the button if $turnout1 or $turnout2 has a timeout or 
      # inprogress movement.
      return 0 if (&CheckTurnout($turnout1, 'MidwayTrack', $TurnoutData, 
                   $TrackData, $SensorBit, $SensorState) or &CheckTurnout(
                   $turnout2, 'MidwayTrack', $TurnoutData, $TrackData, 
                   $SensorBit, $SensorState));

      # Reposition $turnout2 if in a blocking position.
      if ($$TurnoutData{$turnout2}{'Pos'} ne 
          $$TurnoutData{$turnout2}{ $$TrackData{$turnout2}{'Inactive'} }) {
         $moveResult = &MoveTurnout($$TrackData{$turnout2}{'Inactive'}, 
                                    $turnout2, $TurnoutData);
         if ($moveResult == 1) {
            &DisplayError("MidwayTrack, Failed to set turnout $turnout2 to " .
                          "$$TrackData{$turnout2}{'Inactive'}.");
            &PlaySound("GE.wav");
            return 0;
         }
         if ($$TrackData{$turnout2}{'Locked'} == 1) {
            $$TrackData{$turnout2}{'Locked'} = 0;
            &DisplayMessage("MidwayTrack, turnout $turnout2 is unlocked.");
         }
         $$TrackData{$turnout2}{'ManualSet'} = 0;
      }

      # If double button press, move $turnout1 to active position and
      # then lock it.
      if ($pressType eq 'd') {
         if ($$TurnoutData{$turnout1}{'Pos'} ne 
             $$TurnoutData{$turnout1}{ $$TrackData{$turnout1}{'Active'} }) {
            $moveResult = &MoveTurnout($$TrackData{$turnout1}{'Active'}, 
                                       $turnout1, $TurnoutData);
            if ($moveResult == 1) {
               &DisplayError("MidwayTrack, Failed to set " .
                             "turnout $turnout1 to " .
                             "$$TrackData{$turnout1}{'Active'}.");
               &PlaySound("GE.wav");
               return 0;
            }
         }
         $$TrackData{$turnout1}{'Locked'} = 1;
         &DisplayMessage("MidwayTrack, turnout $turnout1 is locked.");
         &PlaySound("Lock.wav");
         return 0;
      }
      
      # Toggle $turnout1 position for single button press.
      $$TrackData{$turnout1}{'ManualSet'} = 1;
      if ($$TurnoutData{$turnout1}{'Pos'} == $$TurnoutData{$turnout1}{'Open'}) {
         $position = 'Close';
      }
      else {
         $position = 'Open';
      }
      $moveResult = &MoveTurnout($position, $turnout1, $TurnoutData);      
      if ($moveResult == 1) {
         &DisplayError("MidwayTrack, Failed to set turnout $turnout1 to " .
                       "$position");
         &PlaySound("GE.wav");
      }
      else {
         &DisplayMessage("MidwayTrack, turnout $turnout1 set to $position.");
         &PlaySound("A_.wav");
      }
   }
   return 0;
}

# =============================================================================
# FUNCTION:  WyeTrack
#
# DESCRIPTION:
#    This routine processes the user buttons associated with the T07 turnout.
#    These buttons, 02 and 03, are used to manually set the turnout position 
#    which selects the yard approach track to be used.
#
# CALLING SYNTAX:
#    $result = &WyeTrack($ButtonInput, \%ButtonData, \%TurnoutData, 
#                        \%TrackData, \%SensorBit, \%SensorState,
#                        \%GpioData);
#
# ARGUMENTS:
#    $ButtonInput        User entered button input, if any.
#    $ButtonData         Pointer to %ButtonData hash.
#    $TurnoutData        Pointer to %TurnoutData hash.
#    $TrackData          Pointer to %TrackData hash.
#    $SensorBit          Pointer to %SensorBit hash.
#    $SensorState        Pointer to %SensorState hash.
#    $GpioData           Pointer to %GpioData hash. (polarity relays) 
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub WyeTrack {
   my($ButtonInput, $ButtonData, $TurnoutData, $TrackData, $SensorBit,
      $SensorState, $GpioData) = @_;
   my($moveResult, $button, $turnout, $position, $polarity);

   &DisplayDebug(2, "WyeTrack entry ...   ButtonInput: '$ButtonInput'");

   # ----------------------------------
   # Process single press button input.
   if ($ButtonInput =~ m/s(02)/ or $ButtonInput =~ m/s(03)/) {
      $button = $1;
      $turnout = $$ButtonData{$button}{'Turnout'};
      &DisplayDebug(0, "WyeTrack, button: $button   turnout: $turnout");

      # Ignore the button if turnout move or train transit is inprogress.
      return 0 if (&CheckTurnout($turnout, 'WyeTrack', $TurnoutData, $TrackData,
                   $SensorBit, $SensorState));

      if ($button eq '02') {
         $position = 'Open';
         $polarity = 1;
      }
      else {
         $position = 'Close';
         $polarity = 0;
      }
            
      # Move turnout if necessary.
      if ($$TurnoutData{$turnout}{'Pos'} ne $$TurnoutData{$turnout}{$position}) {
         $moveResult = &MoveTurnout($position, $turnout, $TurnoutData);
         if ($moveResult == 1) {
            &DisplayError("WyeTrack, Failed to set turnout $turnout to $position");
            &PlaySound("GE.wav");
         }
         else {
            &DisplayMessage("WyeTrack, turnout $turnout set to $position.");
            &PlaySound("A_.wav");
         }
      }
      else {
         &DisplayMessage("WyeTrack, turnout $turnout already at $position.");
         &PlaySound("A_.wav");
      }

      # Change power polarity relay if necessary.
      if ($$TrackData{'07'}{'Polarity'} != $polarity) {
         $$GpioData{GPIO13_PR03}{'Obj'}->write($polarity);  # Set relay control bit.
         if ($$GpioData{GPIO13_PR03}{'Obj'}->read != $polarity) {  # Readback check.
            &DisplayError("ProcessWye S7, Failed to set power " .
                          "relay GPIO13_PR03 to $polarity");
         }
         else {
            &DisplayMessage("ProcessWye S7, power relay " .
                            "GPIO13_PR03 set to $polarity.");
         }
         $$TrackData{'07'}{'Polarity'} = $polarity;
      }
   }
   return 0;
}

# =============================================================================
# FUNCTION:  CheckTurnout
#
# DESCRIPTION:
#    This routine is shared code used by MidwayTrack and WyeTrack to check for 
#    an inprogress turnout operation. This check is performed as part of button 
#    input processing. Warning tone and console message is output if necessary.
#
# CALLING SYNTAX:
#    $result = &CheckTurnout($Turnout, $Caller, \%TurnoutData, \%TrackData,
#                            \%SensorBit, \%SensorState);
#
# ARGUMENTS:
#    $Turnout            Turnout number.
#    $Caller             Name of calling routine.
#    $TurnoutData        Pointer to %TurnoutData hash.
#    $TrackData          Pointer to %TrackData hash.
#    $SensorBit          Pointer to %SensorBit hash.
#    $SensorState        Pointer to %SensorState hash.
#
# RETURNED VALUES:
#    0 = no inprogress operation,  1 = inprogress operation.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub CheckTurnout {
   my($Turnout, $Caller, $TurnoutData, $TrackData, $SensorBit, $SensorState) = @_;

   if ($$TurnoutData{$Turnout}{'Pid'} != 0) {
      &DisplayMessage("$Caller, turnout $Turnout position change is inprogress.");
      &PlaySound("GE.wav");
      return 1; 
   }
   if ($$TrackData{$Turnout}{'Timeout'} > time) {
      &DisplayMessage("$Caller, train transit of turnout $Turnout is inprogress.");
      &PlaySound("GE.wav");
      return 1; 
   }
   if (&GetSensorBit($$TurnoutData{$Turnout}{'Sensor'}, $SensorBit, 
                     $SensorState) == 1) {
      &DisplayMessage("$Caller, $Turnout sensor " .
                      $$TurnoutData{$Turnout}{'Sensor'} . " is active.");
      &PlaySound("GE.wav");
      return 1; 
   }
   return 0;
}

return 1;
