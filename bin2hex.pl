#!/usr/bin/perl
# ===================================================================================
# FILE: bin2hex.pl                                                         7-19-2007
#
# DESCRIPTION:
#   This script dumps the specified file contents to the screen. Hex and its ASCII
#   equivalent characters are displayed.
#
# ===================================================================================
use strict;
# use warnings;

my($file, $decaddr, $addr) = ('', '', 0);

if ($ARGV[0] eq "") {
   goto Help;
}   
elsif ($ARGV[0] =~ m/^-d/) {                             # Parse CLI
   $decaddr = $ARGV[0];
   $file = $ARGV[1];
}   
else {
   $file = $ARGV[0];
   $decaddr = $ARGV[1];
}   

if ($file) {                                             # Must have file to dump
   if (-e $file) {                                       # File must exist
      if (-r $file) {                                    # File must be readable
         if (open(INPUT, "<".$file)) {
            my($length, $data) = ReadBin(\*INPUT, 16, ""); # Read from file
            my $line = FormatData($data);
            print STDOUT "\nHex dump of file: $file\n";
            HeaderLine($decaddr);
            print STDOUT "000000  $line\n";
            while ($length != -1) {
               ($length, $data) = ReadBin(\*INPUT, 16, ""); # Read from file
               last if ($length == -1);              
               $line = FormatData($data);
               $addr = $addr + 16;
               HeaderLine($decaddr) if (($addr % 256) == 0);
               if ($decaddr =~ m/^-d/i) {
                  printf STDOUT "%6.6d  %s\n", $addr, $line;
               }
               else {
                  printf STDOUT "%6.6x  %s\n", $addr, $line;
               }
            }
            close(INPUT);
         }
         else {
            print STDERR "*** Error opening $ARGV[0] $!\n";
            exit(1);
         }   
      }
      else {
         print STDERR "   *** No read permission for $ARGV[0]\n";
         exit(1);
      }
   }
   else {
      print STDERR "*** File not found: $ARGV[0]\n";
      exit(1);
   }
}
else {
Help:
   print STDERR "*** No file specified.\n\n";
   print STDERR "bin2hex.pl - File dump utility.\n\n";
   print STDERR "Usage:\n";
   print STDERR "  bin2hex.pl [-d] <file> - Dump the contents of <file> to the screen.\n";
   print STDERR "     The -d option causes the address column to be output in decimal.\n\n";
   exit(1);
}
print STDOUT "\n";
exit(0);

# ===========================================================================
# FUNCTION:  HeaderLine
#
# DESCRIPTION:
#    This routine prints the header line output.
#
# CALLING SYNTAX:
#    HeaderLine($decaddr);
#
# ARGUMENTS:
#    $decaddr            Decimal option 
#
# RETURNED VALUES:
#    None
#
# ACCESSED GLOBAL VARIABLES:
#    None
# ===========================================================================
sub HeaderLine {

   my($decaddr) = @_;

   if ($decaddr =~ m/^-d/i) {
      print STDOUT "\nOffset   0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15  Ascii\n";
   }
   else {
      print STDOUT "\nOffset   0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F  Ascii\n";
   }   
   print STDOUT "-" x 6 . "  " . "-" x 47 . "  " . "-" x 16 . "\n";
   return;
}

# ===========================================================================
# FUNCTION:  ReadBin
#
# DESCRIPTION:
#    This routine is used to perform sysread's of the specified number of
#    bytes from the specified file handle. The data is unpacked into a 
#    character string; two characters per byte in hexidecimal format. The
#    returned length will always be the requested size times 2 plus the
#    length of the input $data contents. Any input $data from a previous
#    ReadBin call is prepended to the current data read.
#
# CALLING SYNTAX:
#    ($length, $data) = &ReadBin($FileHandle, $size, $data);
#
# ARGUMENTS:
#    $FileHandle     Filehandle of input data.
#    $size           Number of bytes to read from FileHandle
#    $data           Input $data contents, if any.
#
# RETURNED VALUES:
#    -1 = EOF,  length of data.
#    unpacked bytes read.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# ===========================================================================
sub ReadBin {
 
   my($FileHandle, $size, $data) = @_;

   my($sizeread, $newdata);

   if ($size > 0) {
      undef $/;
      
      $sizeread = sysread($FileHandle, $newdata, $size);
      
#      print "sizeread: $sizeread\n";
      
      $/ = "\n";

      if ($sizeread > 0) {
         $newdata = unpack("H*", $newdata);
         $newdata = join("", $data, $newdata);
         return (length($newdata), $newdata);
      }
      else {
         return (-1, $data);
      }
   }
   return (length($data), $data);
}

# ===========================================================================
# FUNCTION:  FormatData
#
# DESCRIPTION:
#    This routine is used to format the specified hex data string for output.
#    Input with less than 16 byte
#    positions are padded with spaces to line up the ASCII translation.
#
# CALLING SYNTAX:
#    $line = &FormatData($HexData);
#
# ARGUMENTS:
#    $HexData            Input hex data to format.
#
# RETURNED VALUES:
#    ASCII character string
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# ===========================================================================
sub FormatData {
   my($HexData) = @_;
   
   my($Ascii);
   
   $Ascii = HexToAscii($HexData);     
   $HexData =~ s/(.{2})/$1 /g;
   $HexData = substr($HexData."   " x 16, 0, 48);
   return "$HexData $Ascii";
}

# ===========================================================================
# FUNCTION:  HexToAscii
#
# DESCRIPTION:
#    This routine is used to translate a hex data string to its equivalent
#    ASCII characters. Two characters from the input data stream are used
#    for each output character. The period character is used to substitute
#    for non-printable characters. 
#
# CALLING SYNTAX:
#    $AsciiStr = &HexToAscii($HexData);
#
# ARGUMENTS:
#    $HexData            Input hex data to convert.
#
# RETURNED VALUES:
#    ASCII character string
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# ===========================================================================
sub HexToAscii {

   my($HexData) = @_;
   
   my($x, $chr);  my($AsciiStr) = "";
   
   for ($x = 0; $x < length($HexData); $x += 2) {
      $chr = chr(hex(substr($HexData, $x, 2)));
      $chr =~ s/[\x00-\x1F]|[\x80-\xFF]/\./;  # Translate non-printable characters
      $AsciiStr = join("", $AsciiStr, $chr);
   }
   return substr($AsciiStr." " x 16, 0, 16);
}
