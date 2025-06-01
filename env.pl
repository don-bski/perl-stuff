#!/usr/bin/perl

print "OS: $^O \n";

foreach $key (sort keys(%ENV)) {
   print "'$key' : '$ENV{$key}'\n";
}
exit(0);
   
