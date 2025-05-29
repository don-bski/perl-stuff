# ============================================================================
# FILE: DnB_Sensor.pm                                               9/20/2020
#
# SERVICES:  DnB SENSOR FUNCTIONS
#
# DESCRIPTION:
#    This perl module provides sensor related functions used by the DnB model 
#    railroad control program.
#
# PERL VERSION: 5.24.1
#
# =============================================================================
use strict;
# -----------------------------------------------------------------------------
# Package Declaration
# -----------------------------------------------------------------------------
package DnB_Sensor;
require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
   I2C_InitSensorDriver
   KeypadChildProcess
   ButtonChildProcess
   PositionChildProcess
   GetSensorBit
   ReadKeypad
   GetButton
   TestSensorBits
   TestSensorTones
   TestKeypad
);

use DnB_Message;
use Time::HiRes qw(gettimeofday sleep);

# =============================================================================
# FUNCTION:  I2C_InitSensorDriver
#
# DESCRIPTION:
#    This routine initializes the sensor I2C driver board on the DnB model 
#    railroad. It sets parameters that are common to all sensor ports. The 
#    I/O PI Plus board utilizes two MCP23017 chips. Each chip has two 8 bit
#    ports of configurable GPIO pins. Each chip is configured based on the
#    values in the %SensorChip hash.
#
#    Chip 3 is initialized for a 'Storm K Range' 4x4 keypad. MCP23017 GPIO
#    pins are direct connected as follows. Row (letter) GPIOs are set as
#    input + pullup. Columns set as outputs.
#
#    The %SensorChip{chip}{'Obj'} hash key is written with the driver object 
#    pointer for use in sensor data reading.
#
#       Keypad pin:      1 2 3 4 5 6 7 8
#       Keypad col/row:  A B 1 2 3 4 D C
#       GPIOA pin:       3 4 5 6 7 8 9 10
#       GPIOA bit:       0 1 2 3 4 5 6 7
#       GPIODIRA:        1 1 0 0 0 0 1 1     1 = Input, 0 = Output
#
# CALLING SYNTAX:
#    $result = &I2C_InitSensorDriver($ChipNmbr, \%MCP23017, \%SensorChip);
#
# ARGUMENTS:
#    $ChipNmbr             Chip number being initialized.
#    $MCP23017             Pointer to %MCP23017 internal register definitions
#    $SensorChip           Pointer to %SensorChip hash. 
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub I2C_InitSensorDriver {

   my($ChipNmbr, $MCP23017, $SensorChip) = @_;
   my($driver);
   my(@temp) = ();

   &DisplayDebug(2, "I2C_InitSensorDriver, ChipNmbr: $ChipNmbr   I2C_Address: " .
                    sprintf("0x%.2X",$$SensorChip{$ChipNmbr}{'Addr'}));

   $driver = RPi::I2C->new($$SensorChip{$ChipNmbr}{'Addr'});
   unless ($driver->check_device($$SensorChip{$ChipNmbr}{'Addr'})) {
      &DisplayError("I2C_InitSensorDriver, Failed to initialize I2C address: " . 
                    sprintf("0x%.2X",$$SensorChip{$ChipNmbr}{'Addr'}) .
                    " - $!");
      return 1;
   }
   $$SensorChip{$ChipNmbr}{'Obj'} = $driver;

   # Set MCP23017 BANK (bit7) = 0 (sets MCP23017 register addresses)
   $driver->write_byte(0x00, $$MCP23017{'IOCON'});

   # Set port direction bits.
   $driver->write_byte($$SensorChip{$ChipNmbr}{'DirA'}, $$MCP23017{'IODIRA'});
   $driver->write_byte($$SensorChip{$ChipNmbr}{'DirB'}, $$MCP23017{'IODIRB'}); 

   # Set port polarity bits.
   $driver->write_byte($$SensorChip{$ChipNmbr}{'PolA'}, $$MCP23017{'IOPOLA'});
   $driver->write_byte($$SensorChip{$ChipNmbr}{'PolB'}, $$MCP23017{'IOPOLB'});

   # Set port pullup enable bits.
   $driver->write_byte($$SensorChip{$ChipNmbr}{'PupA'}, $$MCP23017{'GPPUA'});
   $driver->write_byte($$SensorChip{$ChipNmbr}{'PupB'}, $$MCP23017{'GPPUB'});

   # Build temporary array for debug output.
   push(@temp, $driver->read_byte($$MCP23017{'IOCON'}));   # Get current IOCON.
   push(@temp, $driver->read_byte($$MCP23017{'IODIRA'}));  # Get current IODIRA.
   push(@temp, $driver->read_byte($$MCP23017{'IODIRB'}));  # Get current IODIRB.
   push(@temp, $driver->read_byte($$MCP23017{'IOPOLA'}));  # Get current IOPOLA.
   push(@temp, $driver->read_byte($$MCP23017{'IOPOLB'}));  # Get current IOPOLB.

   &DisplayDebug(2, "I2C_InitSensorDriver - Initialized IODIRA " .
                    "IODIRB IOPOLA IOPOLB IOCON: " . 
                    sprintf("0x%0.2X 0x%0.2X 0x%0.2X 0x%0.2X 0x%0.2X", @temp));

# Debug code.
#   while (1) {
#      $message = "I2C Address: " . sprintf("0x%.2X",$$SensorChip{$ChipNmbr}
#                                           {'Addr'});
#      $message = $message . "   GPIOB: " . sprintf("%0.8b", 
#                                       $driver->read_byte($$MCP23017{'GPIOB'}));
#      $message = $message . "   GPIOA: " . 
#                      sprintf("%0.8b", $driver->read_byte($$MCP23017{'GPIOA'}));
#      &DisplayMessage("I2C_InitSensorDriver - $message");
#      sleep 1;
#   }
#   exit(0);

   return 0;
}

# =============================================================================
# FUNCTION:  KeypadChildProcess
#
# DESCRIPTION:
#    This routine is launched as a child process during main program startup
#    and is used to return user input from the 'Storm K Range' 4x4 button 
#    keypad. This keypad is connected to a MCP23017 port as follows.
#
#       row/col   1   2   3   4
#                 |   |   |   |
#         A ------0---1---2---3--
#                 |   |   |   |
#         B ------4---5---6---7--
#                 |   |   |   |
#         C ------8---9---A---B--
#                 |   |   |   |
#         D ------C---D---E---F--
#                 |   |   |   |
#
#       Keypad pin:      1 2 3 4 5 6 7 8
#       Keypad col/row:  A B 1 2 3 4 D C
#       GPIOA pin:       3 4 5 6 7 8 9 10
#       GPIOA bit:       0 1 2 3 4 5 6 7
#       GPIODIRA:        1 1 0 0 0 0 1 1     1 = Input, 0 = Output
#  
#    A dedicated child process is used to improve the reliability of keypad 
#    entries. Forks::Super is used between the parent and child to read data 
#    from the child's STDERR filehandle. Do no other output to STDERR within 
#    this routine. DisplayMessage and DisplayDebug are permitted since they 
#    use STDOUT for messaging.
#
#    The %KeypadData hash provides keypad specific data and state information.
#    Data is accessed using a hash index specified in the $Keypad variable.
#
#    The %cols hash holds 4 values, each has one of the keypad column driver
#    bits low. These bits are configured as outputs by I2C_InitSensorDriver. 
#    The %col hash keys map to the %matrix hash primary keys.
#
#    The %matrix hash contains the resulting button value for each of the 16 
#    combinations of col/row. I2C_InitSensorDriver configures the input pins 
#    with pullup enabled which results in a value of 0xC3 when no button is 
#    pressed. The hash secondary key corresponds to 0xC3 with one of the input 
#    bits low. Input is ignored if multiple buttons are pressed. 
#
#    Note that the physical rotational orientation of the keypad, that is the
#    keys that are the top row, will necessitate changes to the %matrix hash
#    values. Current matrix values are for the orientation with the keypad
#    connector at the 6 o'clock position. 
#
# CALLING SYNTAX:
#    $KeypadChildPid = fork {os_priority => 4, sub => \&KeypadChildProcess,
#                            child_fh => "err socket", 
#                            args => [ $Keypad, \%KeypadData, \%MCP23017, 
#                                      \%SensorChip ] };
#
#    $read_key = Forks::Super::read_stderr($KeypadChildPid);
#
# ARGUMENTS:
#    $Keypad                KeypadData entry to use.
#    $KeypadData            Pointer to %KeypadData hash. 
#    $MCP23017              Pointer to MCP23017 internal register definitions
#    $SensorChip            Pointer to %SensorChip hash. 
#
# RETURNED VALUES:
#    0-F = Pressed button via read_stderr.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::ChildName
# =============================================================================
sub KeypadChildProcess {
   my($Keypad, $KeypadData, $MCP23017, $SensorChip) = @_;
   my($row, $button);
   my($chip) = $$KeypadData{$Keypad}{'Chip'};
   my(%cols) = (1 => 0xFB, 2 => 0xF7, 3 => 0xEF, 4 => 0xDF);
   my(%matrix) = (1 => { 0xC2 => '0', 0xC1 => '4', 0x43 => '8', 0x83 => 'C'},
                  2 => { 0xC2 => '1', 0xC1 => '5', 0x43 => '9', 0x83 => 'D'},
                  3 => { 0xC2 => '2', 0xC1 => '6', 0x43 => 'A', 0x83 => 'E'},
                  4 => { 0xC2 => '3', 0xC1 => '7', 0x43 => 'B', 0x83 => 'F'});

   $main::ChildName = 'KeypadChildProcess';
   &DisplayMessage("KeypadChildProcess started.");
   &DisplayDebug(2, "Keypad: $Keypad   chip: $chip");

   if ($$SensorChip{$chip}{'Obj'} == 0) {
      &DisplayMessage("*** error: KeypadChildProcess, No SensorChip object " .
                      "for chip $chip. Call I2C_InitSensorDriver routine first.");
      &DisplayMessage("KeypadChildProcess terminated.");
      sleep 2;
      exit(0);
   }

   while(1) {
      $button = -1;
      foreach my $col (1,2,3,4) {
         $$SensorChip{$chip}{'Obj'}->write_byte($cols{$col}, 
                                     $$MCP23017{ $$KeypadData{$Keypad}{'Col'} });
         sleep 0.02;        # Delay for button debounce.
         $row = $$SensorChip{$chip}{'Obj'}->read_byte($$MCP23017{ 
                                         $$KeypadData{$Keypad}{'Row'} }) & 0xC3;
         &DisplayDebug(3, "ReadKeypad, Keypad: $Keypad   col: " . 
                          sprintf("%0.8b", $cols{$col}) . "   row: " .
                          sprintf("%0.8b", $row));

         # Process if valid single button keypress. Ignore held down button.
         if ($row == 0xC2 or $row == 0xC1 or $row == 0x43 or $row == 0x83) {
            $button = $matrix{$col}{$row};          # Get keypress result value.
            if ($button != $$KeypadData{$Keypad}{'Last'}) {   
               $$KeypadData{$Keypad}{'Last'} = $button;
               print STDERR "$button";              # Send key press.
               &DisplayDebug(3, "ReadKeypad, button '$button' pressed.");
            }
            last;
         }
      }

      # Clear 'Last' if no button is pressed.
      if ($button == -1 and $$KeypadData{$Keypad}{'Last'} != -1) {
         $$KeypadData{$Keypad}{'Last'} = -1;
         sleep 0.02;        # Delay for button debounce.
      }
      sleep 0.1;            # Loop delay.
   }

   &DisplayMessage("KeypadChildProcess terminated.");
   sleep 2;
   exit(0);
}

# =============================================================================
# FUNCTION:  ButtonChildProcess
#
# DESCRIPTION:
#    This routine is launched as a child process during main program startup
#    and is used to return user input from the 'Storm K Range' 1x4 button 
#    keypad. This keypad is connected to a MCP23017 port as follows.
#
#       button    D   C   B   A
#                 |   |   |   |
#       common  --o---o---o---o
#
#         ButtonPad 1:    c  D C B A     ButtonPad 2:     c  D C B A
#         Button pin:     1  2 3 4 5     Button pin:      1  2 3 4 5
#         GPIOA pin:      2  6 5 4 3     GPIOA pin:       2 10 9 8 7
#         GPIOA bit:         0 1 2 3     GPIOA bit:          4 5 6 7
#
#    A dedicated child process is used to improve the reliability of a double 
#    button press. Forks::Super is used between the parent and child to read 
#    data from the child's STDERR filehandle. Do no other output to STDERR 
#    within this routine. DisplayMessage and DisplayDebug are permitted since 
#    they use STDOUT for messaging.
#
#    Two button data messgaes are generated, single press (s<num>) and double 
#    press (d<num>). <num> is the button index in the %ButtonData hash. The 
#    parent must read the child's data at a rate greater than the expected 
#    user input rate.
# 
#    Multiple button press events may be present in a message, e.g. 's01d01'.
#    Check first for d01 input and discard the s01 input if present.
#
#    The %ButtonData{<num>}{'Obj'} references must be set prior to launching
#    this child process.
#
# CALLING SYNTAX:
#    $ButtonChildPid = fork {os_priority => 4, sub => \&ButtonChildProcess,
#                            child_fh => "err socket", 
#                            args => [ \%ButtonData, \%MCP23017, \%SensorChip ] };
#
#    $read_button = Forks::Super::read_stderr($ButtonChildPid);
#
# ARGUMENTS:
#    $ButtonData            Pointer to %ButtonData hash.
#    $MCP23017              Pointer to MCP23017 internal register definitions
#    $SensorChip            Pointer to %SensorChip hash. 
#
# RETURNED VALUES:
#    s<num> - Button <num> has been single pressed. 
#    d<num> - Button <num> has been double pressed. 
#
# ACCESSED GLOBAL VARIABLES:
#    $main::ChildName
# =============================================================================
sub ButtonChildProcess {
   my($ButtonData, $MCP23017, $SensorChip) = @_;
   my($port, $mask, $chip, $check);

   $main::ChildName = 'ButtonChildProcess';
   &DisplayMessage("ButtonChildProcess started.");

   while(1) {
      foreach my $button (sort keys %$ButtonData) {
         next if ($button == 0xFF);             # Ignore shutdown button entry
         $chip = $$ButtonData{$button}{'Chip'};
         if ($$ButtonData{$button}{'Bit'} =~ m/^(GPIO.)(\d)/) {
            $port = $1;
            $mask = 1 << $2;

            # Read the port and isolate the bit value.  
            $check = $$SensorChip{$chip}{'Obj'}->read_byte($$MCP23017{$port});
            $check = $check & $mask;
            # 'Last' is used to handle a held down button. Only use the
            # transition from 0 to 1 as a button press.
            if ($check != 0) {
               if ($$ButtonData{$button}{'Last'} == 1) {
                  $$ButtonData{$button}{'PressTime'} = gettimeofday;
                  next;
               }
               if ((gettimeofday - $$ButtonData{$button}{'PressTime'}) < 1) {
                  print STDERR "d${button}";               # Send double press.
                  $$ButtonData{$button}{'PressTime'} = 0;  # New press cycle.
                  &DisplayDebug(1, "ButtonChildProcess, button: d${button}");
               }
               else {
                  print STDERR "s${button}";               # Send single press
                  $$ButtonData{$button}{'PressTime'} = gettimeofday;
                  &DisplayDebug(1, "ButtonChildProcess, button: s${button}");
               }
               $$ButtonData{$button}{'Last'} = 1;
            }
            else {
               $$ButtonData{$button}{'Last'} = 0;          # Button released.
            }
         }
      }
      sleep 0.05;             # Loop delay.
   }

   &DisplayMessage("ButtonChildProcess terminated.");
   sleep 2;
   exit(0);
}

# =============================================================================
# FUNCTION:  PositionChildProcess
#
# DESCRIPTION:
#    This routine is launched as a child process during main program startup.
#    It periodically reads the train hold position sensors associated with the
#    holdover tracks and sets the appropriate panel LEDs to provide a visual
#    indication of train position in these hidden tracks. Warning point (yellow)
#    and stop point (red) LEDs are used.
#
# CALLING SYNTAX:
#    $result = &PositionChildProcess(\%SensorBit, \%PositionLed, \%SensorChip,
#                                    \%MCP23017);
#
# ARGUMENTS:
#    $SensorBit          Pointer to %SensorBit hash.
#    $PositionLed        Pointer to %PositionLed hash.
#    $SensorChip         Pointer to %SensorChip hash. 
#    $MCP23017           Pointer to MCP23017 internal register definitions.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::ChildName
# =============================================================================
sub PositionChildProcess {
   my($SensorBit, $PositionLed, $SensorChip, $MCP23017) = @_;
   my($chip, $port, $pos, $senBit, $ledBits);

   $main::ChildName = 'PositionChildProcess';
   &DisplayMessage("PositionChildProcess started.");

   while(1) {
      foreach my $led (sort keys(%$PositionLed)) {
         $chip = $$SensorBit{$led}{'Chip'};
         if ($$SensorBit{$led}{'Bit'} =~ m/^(GPIO.)(\d)/) {
            $port = $1;
            $pos = $2;

            # Read sensor port and isolate the bit value.  
            $senBit = $$SensorChip{$chip}{'Obj'}->read_byte($$MCP23017{$port});
            $senBit = ($senBit >> $pos) & 1;   # Position and isolate.

            $chip = $$PositionLed{$led}{'Chip'};
            if ($$PositionLed{$led}{'Bit'} =~ m/^(GPIO.)(\d)/) {
               $port = $1;
               $pos = $2;

               # Update associated LED bit value.
               $ledBits = $$SensorChip{$chip}{'Obj'}->read_byte(
                          $$MCP23017{$port});
               $ledBits = $ledBits & (~(1 << $pos));     # Clear bit position.
               $ledBits = $ledBits | ($senBit << $pos);  # Set bit position.
               $$SensorChip{$chip}{'Obj'}->write_byte($ledBits, 
                                  $$MCP23017{ $$PositionLed{$led}{'Olat'} });
            }
         }
      }
      sleep 0.5;             # Loop delay.      
   }

   &DisplayMessage("PositionChildProcess terminated.");
   sleep 1;
   exit(0);
}

# =============================================================================
# FUNCTION:  GetSensorBit
#
# DESCRIPTION:
#    This routine returns the current value of the specified sensor bit. The
#    proper SensorState hash index is determined based on the requested bit
#    number. The bit number must include leading zero (0) if less that 10 for
#    proper index key in %SensorBit hash.
#
# CALLING SYNTAX:
#    $result = &GetSensorBit($BitNumber, \%SensorBit, \%SensorState);
#
# ARGUMENTS:
#    $BitNumber             Bit position to check (index in %SensorBit)
#    $SensorBit             Pointer to %SensorBit hash.
#    $SensorState           Pointer to %SensorState hash. 
#
# RETURNED VALUES:
#    Bit value: 0 or 1
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub GetSensorBit {
   my($BitNumber, $SensorBit, $SensorState) = @_;
   my($bitMask) = 1 << ($BitNumber % 16);

   return 1 if ($$SensorState{ $$SensorBit{$BitNumber}{'Chip'} } & $bitMask);

   return 0;
}

# =============================================================================
# FUNCTION:  TestSensorBits
#
# DESCRIPTION:
#    This routine displays the sensor state bits on the console. The user can
#    manually activate each sensor and observe the expected result. This test
#    loops indefinitely until the user enters ctrl+c.
#
# CALLING SYNTAX:
#    $result = &TestSensorBits($Range, \%MCP23017, \%SensorChip, \%SensorState);
#
# ARGUMENTS:
#    $Range                    Chip number or range to use.
#    $MCP23017                 Pointer to MCP23017 internal register definitions
#    $SensorChip               Pointer to %SensorChip hash. 
#    $SensorState              Pointer to %SensorState hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::MainRun
# =============================================================================
sub TestSensorBits {
   my($Range, $MCP23017, $SensorChip, $SensorState) = @_;
   my($chip, $start, $end, $msg, @chipList);
   my($cntr) = 0;

   &DisplayDebug(2, "TestSensorBits, Entry ... Range: '$Range'");

   if ($Range =~ m/(\d+):(\d+)/) {   # Range specified.
      $start = $1;
      $end = $2;
      if ($start > $end or $start < 1 or $start > 4 or $end < 1 or $end > 4) {
         &DisplayError("TestSensorBits, invalid sensor chip range: '$Range'");
         return 1;
      }
      for ($chip = $start; $chip <= $end; $chip++) {
         push (@chipList, $chip);
      }
   }
   else {
      @chipList = split(",", $Range);
   }
   &DisplayDebug(1, "TestSensorBits, chipList: '@chipList'");

   &DisplayMessage("TestSensorBits - enter ctrl+c to exit.\n");
   &DisplayMessage("TestSensorBits -----                           " .
                   "bit 76543210      bit 76543210");
   while($main::MainRun) {
      foreach my $chip (@chipList) {
         $msg = sprintf("%0.6d", $cntr);     # Show program activity on console.
         if (exists($$SensorChip{$chip})) {
            $$SensorState{$chip} = 
               ($$SensorChip{$chip}{'Obj'}->read_byte($$MCP23017{'GPIOB'}) << 8) |
                $$SensorChip{$chip}{'Obj'}->read_byte($$MCP23017{'GPIOA'});

            $msg = $msg . " I2C Address: " . 
                          sprintf("0x%.2X", $$SensorChip{$chip}{'Addr'});
            $msg = $msg . "   GPIOB: " . 
                          sprintf("%0.8b", ($$SensorState{$chip} >> 8));
            $msg = $msg . "   GPIOA: " . 
                          sprintf("%0.8b", ($$SensorState{$chip} & 0xFF));
            &DisplayMessage("TestSensorBits - $msg");
         }
         else {
            &DisplayError("TestSensorBits, invalid sensor range: '$Range'");
            return 1;
         }
      }
      $cntr++;
      sleep 1;
   }
   return 0;
}

# =============================================================================
# FUNCTION:  TestSensorTones
#
# DESCRIPTION:
#    This routine tests all sensors. A sensor ID number of tones are sounded 
#    when a sensor becomes active and a double tone is sounded when a sensor 
#    becomes inactive. This facilitates operability testing of the layout 
#    remote sensors; e.g. by manually blocking the IR light path. This test 
#    loops indefinitely until the user enters ctrl+c.
#
# CALLING SYNTAX:
#    $result = &TestSensorTones(\%MCP23017, \%SensorChip, \%SensorState,
#                               \%SensorBit);
#
# ARGUMENTS:
#    $MCP23017              Pointer to MCP23017 internal register definitions
#    $SensorChip            Pointer to %SensorChip hash. 
#    $SensorState           Pointer to %SensorState hash.
#    $SensorBit             Pointer to %SensorBit hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::MainRun
# =============================================================================
sub TestSensorTones {
   my($MCP23017, $SensorChip, $SensorState, $SensorBit) = @_;
   my($bitNmbr, $cur, $prev, $x, $y);
   my(%localSensorState) = ('1' => 0, '2' => 0);

   &DisplayDebug(2, "TestSensorTones, Entry ...");

   &DisplayMessage("TestSensorTones, ==============================");
   &DisplayMessage("TestSensorTones, Waiting for change in sensor " .
                   "bits 0-31 ...");
   while($main::MainRun) {

      # Get all sensor states.
      $localSensorState{'1'} = 
      ($$SensorChip{'1'}{'Obj'}->read_byte($$MCP23017{'GPIOB'}) << 8) |
       $$SensorChip{'1'}{'Obj'}->read_byte($$MCP23017{'GPIOA'});
      $localSensorState{'2'} = 
      ($$SensorChip{'2'}{'Obj'}->read_byte($$MCP23017{'GPIOB'}) << 8) |
       $$SensorChip{'2'}{'Obj'}->read_byte($$MCP23017{'GPIOA'});

      # If a bit has changed, report change.
      for ($x = 0; $x < 32; $x++) {
         $bitNmbr = sprintf("%0.2d",$x);
         next if ($$SensorBit{$bitNmbr}{'Desc'} =~ m/spare/ or
                  $$SensorBit{$bitNmbr}{'Desc'} =~ m/Unused/ );
         $cur  = &GetSensorBit($bitNmbr, $SensorBit, \%localSensorState);
         $prev = &GetSensorBit($bitNmbr, $SensorBit, $SensorState);

         if (($cur - $prev) == 1) {      # Bit now set.
            &DisplayMessage("TestSensorTones, Sensor bit $bitNmbr" .
                            " has set   (1). [" .
                            $$SensorBit{$bitNmbr}{'Desc'} . "]");
            for ($y = 0; $y < $x; $y++) {
               &PlaySound("Lock.wav");
               sleep 0.5;
            }
            last;                        # Skip remaining bits
         }
         elsif (($prev - $cur) == 1) {   # Bit now reset.
            &DisplayMessage("TestSensorTones, Sensor bit $bitNmbr" .
                            " has reset (0). [" .
                            $$SensorBit{$bitNmbr}{'Desc'} . "]");
            &PlaySound("Unlock.wav");
            last;                        # Skip remaining bits
         }
      }

      # Update %SensorState hash with just read sensor states.
      $$SensorState{'1'} = $localSensorState{'1'};
      $$SensorState{'2'} = $localSensorState{'2'};
      sleep 0.5;
   }
   return 0;
}

# =============================================================================
# FUNCTION:  TestKeypad
#
# DESCRIPTION:
#    This routine displays the pressed button on the keypad. It also sets and 
#    resets the 1st entry LED with each key press. The individual turnout 
#    buttons will also be displayed when pressed. This test loops until the 
#    user enters ctrl+c.
#
# CALLING SYNTAX:
#    $result = &TestKeypad($Keypad, \%KeypadData, \%ButtonData, \%GpioData, 
#                          \%MCP23017, \%SensorChip, \$KeypadChildPid,
#                          \$ButtonChildPid);
#
# ARGUMENTS:
#    $KeypadId              KeypadData entry to test.
#    $KeypadData            Pointer to %KeypadData hash.
#    $ButtonData            Pointer to %ButtonData hash.
#    $GpioData              Pointer to %GpioData hash.
#    $MCP23017              Pointer to MCP23017 internal register definitions
#    $SensorChip            Pointer to %SensorChip hash. 
#    $KeypadChildPid        Pointer to KeypadChild pid value.
#    $ButtonChildPid        Pointer to ButtonChild pid value. 
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::MainRun
# =============================================================================
sub TestKeypad {
   my($KeypadId, $KeypadData, $ButtonData, $GpioData, $MCP23017, $SensorChip,
      $KeypadChildPid, $ButtonChildPid) = @_;
   my($button, $value, $lockLed, $key, @input);

   &DisplayDebug(2, "TestKeypad, Entry ... KeypadId: $KeypadId   KeypadChildPid: " .
                 "$$KeypadChildPid   ButtonChildPid: $$ButtonChildPid");

   $KeypadId = sprintf("%0.2d",$KeypadId);   # Add leading 0 for proper key.
   if (exists $$KeypadData{$KeypadId}) {
      while($main::MainRun) {

         # Keypad buttons.
         $button = Forks::Super::read_stderr($$KeypadChildPid);
         if ($button eq '') {
            &DisplayMessage("TestKeypad, KeypadId: $KeypadId - No " .
                            "button pressed.");
         }
         else {
            $button = substr($button, 0, 1);  # 1st character only if multiple.
            &DisplayMessage("TestKeypad, KeypadId: $KeypadId - " .
                            "keypad button pressed: '$button'");

            # Read keypad 1st entry LED.
            $value = $$GpioData{ $$KeypadData{$KeypadId}{'Gpio'} }{'Obj'}->read;

            # Compliment the value.
            $value = (~$value) & 1;

            # Write keypad 1st entry LED.
            $$GpioData{ $$KeypadData{$KeypadId}{'Gpio'} }{'Obj'}->write($value);
            &DisplayMessage("TestKeypad, KeypadId: $KeypadId - 1st " .
                            "entry LED set to $value");
         }

         # Single buttons.
         $button = Forks::Super::read_stderr($$ButtonChildPid);
         if ($button ne '') {
            if ($button =~ m/d(\d+)/) {
               $value = $1;
               &DisplayMessage("TestKeypad, button double press: " .
                               "$$ButtonData{$1}{'Desc'}");
            }
            elsif ($button =~ m/s(\d+)/) {
               $value = $1;
               &DisplayMessage("TestKeypad, button single press: " .
                               "$$ButtonData{$1}{'Desc'}");
            }
            else {
               &DisplayMessage("TestKeypad, invalid button response: " .
                               "'$button'");
            }
            if ($value ge '04' and $value le '07') {

               # Read Holdover route lock LED.
               $lockLed = $$GpioData{'GPIO26_HLCK'}{'Obj'}->read;

               # Compliment the value.
               $lockLed = (~$lockLed) & 1;

               # Write keypad 1st entry LED.
               $$GpioData{'GPIO26_HLCK'}{'Obj'}->write($lockLed);
               &DisplayMessage("TestKeypad, Lock led set to $lockLed");
            }
         }
         else {
            &DisplayMessage("TestKeypad, No single button input.");
         }

         # Read and display shutdown button state.
         $button = $$GpioData{'GPIO21_SHDN'}{'Obj'}->read;
         &DisplayMessage("TestKeypad, Shutdown button: $button");
         sleep 2;
      }
   }
   else {
      &DisplayError("TestKeypad, Keypad $KeypadId is not supported.");
      return 1;
   }
   return 0;
}

return 1;
