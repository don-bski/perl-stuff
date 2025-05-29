#!/usr/bin/perl
# ==============================================================================
# FILE: recursiveCopy.pl                                              1-12-2019
#
# SERVICES: Recursive name sorted file copyer 
#
# DESCRIPTION:
#   This program is used to recursively copy files from the -s specified source
#   folder to the -d specified destination folder. The copy operation orders the
#   files and folders alphabetically prior to copy. The -p option, when specified,
#   creates m3u playlist files in each folder for files with a .mp3 extention.
#
#   Note: The specified destination folder, e.g. E:/Music, and its contents, is
#   deleted if present prior to the copy operation.
#
# PERL VERSION:  5.6.1
#
# ==============================================================================
BEGIN {
   use Cwd;
   ($ExecutableName) = ($0 =~ /([^\/\\]*)$/);
   if (length($ExecutableName) == length($0)) {
      $WorkingDir = cwd();
   }
   else {
      $WorkingDir = substr($0, 0, rindex($0, "/"));
   }
   unshift (@INC, $WorkingDir);
   $libDir = join("/../", $WorkingDir, "lib");
   unshift (@INC, $libDir) if (-e $libDir);
}

# ------------------------------------------------------------------------------
# External module definitions.
use Getopt::Std;
use File::Path qw(make_path remove_tree);
use File::Copy;
use File::Find;
use File::Glob ':bsd_glob';   # Needed for Windows paths containing spaces.

# =============================================================================
# FUNCTION:  WriteFile
#
# DESCRIPTION:
#    This routine writes the specified array to the specified file. If the file
#    already exists, it is deleted.
#
# CALLING SYNTAX:
#    WriteFile($OutputFile, \@Array, "Trim");
#
# ARGUMENTS:
#    $OutputFile     File to write.
#    \@Array         Pointer to array for output records.
#    $Trim           Optional. Trims records before writing to file
#
# RETURNED VALUES:
#    0 = Success,  exit code on Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub WriteFile {
   my($OutputFile, $OutputArrayPointer, $Trim) = @_;
   my($rec);
   
   unlink ($OutputFile) if ($OutputFile);
   unless (open(OUTPUT, ">".$OutputFile)) {
      print "Error opening file for write: $OutputFile - $!";
      return 1;
   }
   foreach $rec (@$OutputArrayPointer) {
      $rec = Trim($rec) if ($Trim);
      unless (print OUTPUT $rec."\r\n") {
         print "Error writing file: $OutputFile - $!";
         close(OUTPUT);
         return 1;
      }
   }
   close(OUTPUT);
   return 0;
}

# ==============================================================================
# FUNCTION:  ProcessDir
#
# DESCRIPTION:
# Copies the folders and files in the specified source folder to the specified 
# destination folder. A recursive call is made for each sub-folder found. The
# playList array is loaded for each folder; relative path to each mp3 file. The 
# corresponding m3u file is created only if the -p option was specified.
#
# CALLING SYNTAX:
#    $result = &ProcessDir($SrcDir, $DstDir, $PlayDir, $Indent);
#
# ARGUMENTS:
#    $SrcDir         Source directory.
#    $DstDir         Destination directory.
#    $PlayDir        Playlist directory.
#    $Indent         Spaces for console output indent
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# ==============================================================================
sub ProcessDir {
   my($SrcDir, $DstDir, $PlayDir, $Indent) = @_;
   my(@dirlist, $srcdir, $dstdir, @filelist, $srcfile, $dstfile, $dstname, $dstplaypath, $playfile);
   my(@playlist) = ("#EXTM3U");

   # print "ProcessDir - SrcDir: $SrcDir   DstDir: $DstDir   PlayDir: $PlayDir   Indent: '$Indent'\n";
#
# Process file entries.
#
   @filelist = sort grep { -f } bsd_glob "$SrcDir/*";         # Get file entries.
   # print "filelist: @filelist \n";
   foreach $srcfile (@filelist) {
      $dstname = substr($srcfile, rindex($srcfile, "/")+1);
      $dstfile = join("/", $DstDir, $dstname);
      if ($dstname =~ m/\.mp3$/) {                            # Add entry to @playlist
         push (@playlist, "#EXTINF:0,$dstname");
         $dstplaypath = substr($dstfile, index($dstfile, "/"));
         $dstplaypath =~ s#/#\\#g;
         push (@playlist, "..$dstplaypath");
#         push (@playlist, "");
      }    
      unless (-e $dstfile) {
         copy($srcfile, $dstfile);
         if (-e $dstfile) {
            print "${Indent}$dstfile \n";
         }
         else {
            print "*** Failed to copy: $dstfile  $!\n";
            return 1;
         }
      }
   }
   
#
# Create playlist file if requested (-p) and playlist array contains mp3 entries.
#
   if ($PlayDir ne "" and $#playlist > 0) {
      $playfile = join("/", $PlayDir, join(".", substr($DstDir, rindex($DstDir, "/")+1), "m3u"));
      return 1 if (&WriteFile($playfile, \@playlist, ""));
      print "${Indent}Playlist created: $playfile\n";
   }  

#
# Process directory entries.
#
   @dirlist = sort grep { -d } bsd_glob "$SrcDir/*";          # Get directory entries.
   foreach $srcdir (@dirlist) {
      $srcdir =~ s#/$##;
      $dstdir = substr($srcdir, rindex($srcdir, "/")+1);
      $dstdir = join("/", $DstDir, $dstdir);
      # print "srcdir: $srcdir   dstdir: $dstdir\n";
      unless (-d $dstdir) {
         make_path($dstdir);
         if (-d $dstdir) {
            print "${Indent}$dstdir \n";
            return 1 if (&ProcessDir("$srcdir", "$dstdir", $PlayDir, "$Indent   "));
         }
         else {
            print "*** Failed to create: $dstdir  $!\n";
            return 1;
         }
      }
   }

   return 0;
}

# =============================================================================
# MAIN PROGRAM
# =============================================================================
# Process user specified CLI options.
getopts("hps:d:");

if (defined($opt_h)) {
   print "\nThis program is used to recursively copy files from the -s specified source\n";
   print "folder to the -d specified destination folder. The copy operation orders the\n";
   print "files and folders alphabetically prior to copy. The -p option, when specified,\n";
   print "creates m3u playlist files in each folder for files with a .mp3 extention.\n\n";
   print "Note: The specified destination folder, e.g. E:/Music, and its contents, is\n";
   print "deleted if present prior to the copy operation.\n\n";
   print "-> perl recursiveCopy.pl -s I:/Music -d E:/Music -p\n\n";   
   exit(1);
}

# Check for required input.
if (defined($opt_s)) {
   unless (-d $opt_s) {
      print "\n*** Source folder not found: $opt_s\n";
      exit(1);
   }   
}
else {
   print "\n*** No source folder specified.\n";
   exit(1);
}
unless (defined($opt_d)) {
   print "\n*** No destination folder specified.\n";
   exit(1);
}

# Get size to be copied.
$totalSize = 0;
find(sub { $totalSize += -s if -f }, $opt_s);
$totalSize =~ s/(\d)(?=(\d{3})+(\D|$))/$1\,/g;

# Verify operation with user.
ASK:           
print "\nRecursively copy files from '$opt_s' to '$opt_d'\n";
print "--> $totalSize bytes will be copied.\n";
print "--> M3U playlist files will be created.\n" if (defined($opt_p));
print "--> $opt_d folder will be deleted!  Proceed? [y/n]: ";
$resp = <STDIN>;
if ($resp =~ m/^y/i or $resp =~ m/^n/i) {
   if ($resp =~ m/^y/i) {
   
      # Delete existing destination folder.   
      if (-d $opt_d) {
         print "Deleting folder $opt_d ...\n";
         remove_tree($opt_d);
         rmdir $opt_d;          # Remove_tree leaves parent directory
         if (-d $opt_d) {
            print "\n*** Failed to delete folder: $opt_d\n";
            exit(1);
         }
      }
      $playListsDir = "";
      
      # will cause the MP3 player to re-index contents.
      if (defined($opt_p)) {
         $rootDir = substr($opt_d, 0, rindex($opt_d, "/"));
         $playListsDir = join("/", $rootDir, "Playlists");
         remove_tree($playListsDir);
         rmdir $playListsDir;       # Remove_tree leaves parent directory
         if (-d $playListsDir) {
            print "\n*** Failed to delete folder: $playListsDir\n";
            exit(1);
         }
         foreach $file ("m3u.lib", "music.lib") {
            $delFile = join("/", $rootDir, $file);
            unlink $delFile;
            if (-e $delFile) {
               print "\n*** Failed to delete file: $delFile\n";
               exit(1);
            }
         }
         
         # Make new Playlists folder.
         make_path($playListsDir);
         if (-d $playListsDir) {
            print "New destination folder successfully created.\n";
         }
         else {
            print "\n*** Failed to create folder: $playListsDir\n";
            exit(1);
         }
      } 

      # Make new destination folder.
      make_path($opt_d);
      if (-d $opt_d) {
         print "New playlists folder successfully created.\n";
      }
      else {
         print "\n*** Failed to create folder: $opt_d\n";
         exit(1);
      }
      
      # Begin copy operation.
      print "Copying files ...\n";     
      exit(1) if (&ProcessDir("$opt_s", "$opt_d", "$playListsDir", "   "));      
   }
   else {
      print "*** Copy aborted by the user.\n\n";
      exit(1);
   }
}   
else {
   print "*** Please respond 'y' or 'n' \n";
   goto ASK;
}

exit(0);
