#!/usr/bin/perl
# ===================================================================================
# FILE: WledLibrarianDBI.pm                                                8-24-2025
#
# DESCRIPTION:
#   This perl module provides SQLite database interfacing functions for the WLED
#   librarian program.
#
#   Subroutines DisplayDebug and ColorMessage are defined here so they are available
#   to both WledLibrarianDIB and WledLibrarianLib. Organizationally, they belong in
#   WledLibrarianLib. But a circular reference will result if 'use WledLibrarianLib'
#   is added to this module.
#
# PERL VERSION:  5.28.1
#
# ===================================================================================
# -----------------------------------------------------------------------------
# Package Declaration
# -----------------------------------------------------------------------------
package WledLibrarianDBI;
require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
   DisplayDebug
   ColorMessage
   InitDB
   InsertDbData
   SelectDbArray
   DeleteDbData
   UpdateDbData
   DumpDbTable
);
   
# ------------------------------------------------------------------------------
# External module definitions.
use DBI  qw(:utils);
use Data::Dumper;
# $Data::Dumper::Sortkeys = 1;
# print Dumper $s_ref;

# =============================================================================
# FUNCTION:  DisplayDebug
#
# DESCRIPTION:
#    Displays a debug message to the user. The message is colored for easier
#    identification on the console.
#
# CALLING SYNTAX:
#    $result = &DisplayDebug($Message);
#
# ARGUMENTS:
#    $Message              Message to be output.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::cliOpts{d}
# =============================================================================
sub DisplayDebug {
   my($Message) = @_;
   
   &ColorMessage($Message, 'BRIGHT_CYAN', '') if (defined( $main::cliOpts{d} ));
   return 0;
}

# =============================================================================
# FUNCTION:  ColorMessage
#
# DESCRIPTION:
#    Displays a message to the user. If specified, an input parameter provides
#    coloring for the message text. Supported color constants are as follows.
#
#    black            red                green            yellow
#    blue             magenta            cyan             white
#    bright_black     bright_red         bright_green     bright_yellow
#    bright_blue      bright_magenta     bright_cyan      bright_white
#    gray             reset
#
#    gray = bright_black. reset return to screen colors.
#  
# CALLING SYNTAX:
#    $result = &ColorMessage($Message, $Color, $Nocr);
#
# ARGUMENTS:
#    $Message         Message to be output.
#    $Color           Optional color attributes to apply.
#    $Nocr            Suppress message newline if set. 
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::cliOpts{a}
# =============================================================================
sub ColorMessage {
   my($Message, $Color, $Nocr) = @_;
   my($cr) = "\n";
   
   # The color constants and their associated ANSI terminal sequence.
   my(%colConst) = (
      'black' => "\e[30m", 'red' => "\e[31m", 'green' => "\e[32m",
      'yellow' => "\e[33m", 'blue' => "\e[34m", 'magenta' => "\e[35m",
      'cyan' => "\e[36m", 'white' => "\e[37m", 'gray' => "\e[90m",
      'bright_black' => "\e[90m", 'bright_red' => "\e[91m", 
      'bright_green' => "\e[92m", 'bright_yellow' => "\e[93m",
      'bright_blue' => "\e[94m", 'bright_magenta' => "\e[95m",
      'bright_cyan' => "\e[96m", 'bright_white' => "\e[97m", 
      'reset' => "\e[0m");
   
   $cr = '' if ($Nocr ne '');
   
   # BRIGHT_RED is used throughout the program to indicate an error condition.
   # These messages are output to STDERR.
   my $fh = 'STDOUT';
   $fh = 'STDERR' if ($Color =~ m/BRIGHT_RED/i);

   if ($Color ne '' and not defined($main::cliOpts{a})) {
      print $fh $colConst{ lc($Color) }, $Message, $colConst{'reset'}, "$cr";
   }
   else {
      print $fh $Message, "$cr";
   }
   return 0;
}

# =============================================================================
# FUNCTION:  InitDB
#
# DESCRIPTION:
#    This routine creates the working database for the WLED librarian program.
#    It creates the database tables and columns. If the specified database 
#    already exists, the tables and columns are verified. Input argument $DbFile
#    specifies the database file name. The following tables are created/verified. 
#
#    Table: Presets  - Holds the JSON imported from WLED presets.json files.
#       Lid    - Unique record id used for SQL table joins.
#       Pid    - Isolated preset id from Pdata.
#       Pname  - Isolated preset name from Pdata.
#       Qll    - Isolated preset quick load label from Pdata.
#       Pdata  - Imported JSON data for this preset.
#       Type   - Preset type, 'preset' or 'playlist'.
#       Src    - File name source of this record.
#       Date   - Import date.
#
#    Table: Keywords  - User assigned text for record selection.
#       Kid    - Id used for SQL table joins. Same as associated Lid.
#       Tag    - List of user provided tag words.  e.g. new, test
#       Group  - List of user provided grouping words.  e.g. xmas, xmas2025
#
#    Table: Palettes - Holds the custom palettes used by the presets.
#       Palid  - Unique palette Id. Multiple palettes for preset possible. 
#       Plid   - Lid of preset using this palette.
#       Plnum  - Palette number; 0 through -9 (256-247).
#       Pldata - JSON data for this custom palette.
#
#    Table: Ledmaps - Holds the custom ledmaps used by the presets.
#       Mapid  - Unique ledmap Id. One ledmap per preset. 
#       Mlid   - Lid of preset using this ledmap.
#       Mnum  -  Ledmap number; 0 through 9 (ledmap0.json - ledmap9.json).
#       Mdata -  JSON data for this ledmap.
#
#    The following initialization logic is used by this routine.
#
#    $DbFile     $New    Result
#    -------    -----    --------
#    Exists      'new'   Database file is overwritten
#    Not exists  'new'   New empty database is created.
#    Exists      ''      Database consistency check is performed.
#    Not exists  ''      New empty database is created.
#
# CALLING SYNTAX:
#    $dbh = &InitDB($DbFile, $New);
#
# ARGUMENTS:
#    $DbFile         Database path/file name. No path = cwd.
#    $New            Force database creation flag.
#
# RETURNED VALUES:
#    $dbh = Success,  -1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub InitDB {
   my($DbFile, $New) = @_;
   my($dbh);
   
   # %schema defines each database table and its associated fields.
   my %schema = ('Presets' => 'Lid,Pid,Pname,Qll,Pdata,Type,Src,Date',
                 'Keywords' => 'Kid,Tag,Group', 
                 'Palettes' => 'Palid,Plid,Plnum,Pldata',
                 'Ledmaps' => 'Mapid,Mlid,Mnum,Mdata');
                 
   # %type defines each database field type and size.              
   my %type = ('Lid'=>'INTEGER PRIMARY KEY','Pid'=>'INTEGER','Pname'=>'VARCHAR(100)',
               'Qll'=>'VARCHAR(10)','Pdata'=>'VARCHAR(6000)','Type'=>'VARCHAR(20)',
               'Src'=>'VARCHAR(100)','Date'=>'DATE','Kid'=>'INTEGER',
               'Tag'=>'VARCHAR(2000)','Group'=>'VARCHAR(2000)',
               'Palid'=>'INTEGER PRIMARY KEY','Plid'=>'INTEGER','Plnum'=>'INTEGER',
               'Pldata'=>'VARCHAR(100)','Mapid'=>'INTEGER PRIMARY KEY',
               'Mlid'=>'INTEGER','Mnum'=>'INTEGER','Mdata'=>'VARCHAR(3000)');

   &DisplayDebug("InitDB: DbFile: '$DbFile'   '$New'");
   if ($DbFile eq '') {
      &ColorMessage("InitDB: no database file specified.", "BRIGHT_RED", '');
      return -1;
   }
   
   if ($New eq 'new' or not -e $DbFile) {   # Make a new database.
      unlink $DbFile if (-e $DbFile);       # Remove file if present.
      $dbh = DBI->connect("dbi:SQLite:dbname=$DbFile","","");
      if ($dbh) {
         &DisplayDebug("InitDB: DB created.");
         &DisplayDebug("InitDB: SQLite version: $DBD::SQLite::sqlite_version");
      }
      else {
         &ColorMessage("InitDB: DB create failed. $DBI::errstr", "BRIGHT_RED", '');
         return -1;
      }
      # Initialize the database tables.
      foreach my $table (keys(%schema)) {
         return -1 if (&MakeDbTable($table, \%schema, \%type) == -1);
      }
   }
   else {         # Connect and check existing database.
      $dbh = DBI->connect("dbi:SQLite:dbname=$DbFile","","");
      &DisplayDebug("InitDB: SQLite version: $DBD::SQLite::sqlite_version");
      
      # Check each database table.
      foreach $table (keys(%schema)) {
         &DisplayDebug("InitDB: Checking table $table for columns $schema{$table}");
         my $sth = $dbh->prepare(qq(select name from pragma_table_info('$table');));
         return -1 if (not defined($sth));
         my $rv = $sth->execute();
         if (not defined($rv)) {
            &ColorMessage("InitDB: execute failed. $DBI::errstr", "BRIGHT_RED", '');
            return -1;
         }
         if ($DBI::errstr eq '') {
            my @names = ();
            while (my @row = $sth->fetchrow_array) {
               push (@names, $row[0]);
            }
            my $cols = join(',', @names);
            if ($cols ne $schema{$table}) {
               if ($cols eq '') {
                  &ColorMessage("\nDatabase table ", "BRIGHT_YELLOW", 'nocr');
                  &ColorMessage("$table", "BRIGHT_WHITE", 'nocr');
                  &ColorMessage(" is missing. This is likely due to a new\n" .
                                "WledLibrarian feature. The current database presets may " .
                                "need to \n" .
                                "be re-import to utilize the new feature. See the release " .
                                "notes.", "BRIGHT_YELLOW", '');
                  &ColorMessage("Create a new $table table? [y|N] -> ", "BRIGHT_WHITE", 'nocr');
                  my $resp = <STDIN>;
                  chomp($resp);
                  return -1 unless ($resp =~ m/y/i);
                  return -1 if (&MakeDbTable($table, \%schema, \%type) == -1);
                  &ColorMessage("Table $table successfully created.", "CYAN", '');
               }
               else {
                  &ColorMessage("InitDB: $table table column error.", "BRIGHT_RED", '');
                  &ColorMessage("Expected: '$schema{$table}'   Actual: '$cols'",
                                "BRIGHT_RED", '');
                  return -1;
               }
            }
         }
         else {
            &ColorMessage("InitDB: $DBI::errstr", "BRIGHT_RED", '');
            return -1;
         }
      }
   }

   # ----------   
   # Private subroutine used to create the specified database table.
   sub MakeDbTable {
      my($Table, $Schema, $Type) = @_;
      
      my @cols = split(',', $$Schema{$Table});
      my $sql = "CREATE TABLE $Table (";
      foreach my $col (@cols) {
         if ($col =~ m/^Group$/i) {
            $sql = join(' ', $sql, "[$col]", "$$Type{$col},");
         }
         else {
            $sql = join(' ', $sql, $col, "$$Type{$col},");
         }
      }
      $sql =~ s/,$/\);/;
      &DisplayDebug("InitDB: sql: '$sql'");
      $rv = $dbh->do($sql);
      if ($rv) {
         &DisplayDebug("InitDB: $Table table created.");
      }
      else {
         &ColorMessage("InitDB: $Table table create failed. $DBI::errstr",
                       "BRIGHT_RED", '');
         return -1;
      }
   }
   # ----------   
   
   return $dbh;
}

# =============================================================================
# FUNCTION:  InsertDbData
#
# DESCRIPTION:
#    This routine is called to insert data into the database. 
#
# CALLING SYNTAX:
#    $status = &InsertDbData($Dbh, $Table, \%Data, \@Field);
#
# ARGUMENTS:
#    $Dbh              Database handle.
#    $Table 		     Table to load.                     
#    $Data             Pointer to hash of data records.
#    $Field            Pointer to field list.
#
# RETURNED VALUES:
#    <rowid> = Success,  -1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub InsertDbData {
   my($Dbh, $Table, $Data, $Field) = @_;
   my(@values) = ();

   &DisplayDebug("InsertDbData - Table: '$Table'   Field: '@$Field'");
   if ($Table ne '' and $#$Fields >= 0) {
      foreach my $key (@$Field) {
         if ($$Data{$key} =~ m/^NULL$/i) {
            push (@values, $$Data{$key});
         } 
         else {
            push (@values, "'$$Data{$key}'");
         }
      }
      my $query = join("", "INSERT INTO ", $Table, " (", join(",", @$Field),
                       ") VALUES (", join(",", @values), ")");
      # Escape SQLite reserved word 'group'.
      $query =~ s/group/\[group\]/ig unless ($query =~ m/\[group\]/);
      &DisplayDebug("InsertDbData - prepare query: $query");
      my $sth = $Dbh->prepare($query);
      if ($sth->err) {
         &ColorMessage("InsertDbData - prepare: $sth->err", "BRIGHT_RED", '');
         return 1;
      }
      # Perform the query.
      $sth->execute();
      if ($sth->err) {
         &ColorMessage("InsertDbData - execute: $sth->err", "BRIGHT_RED", '');
         return 1;
      }
      # Always return the last_insert_id. It is used in ImportPresets to link
      # Keywords, Palettes, and Ledmaps to the preset entry.
      return $sth->last_insert_id();
   }
   else {
      &ColorMessage("   InsertDbData table or fieldlist unspecified.", "BRIGHT_RED", '');
      return 1;
   }
}

# =============================================================================
# FUNCTION:  SelectDbArray
#
# DESCRIPTION:
#    This routine is called to get and return data from the database in the
#    specified array. Column ordering is as specified in the SELET clause.
#    Rows are ordered as specified by the ORDER BY clause, if any.
#
#    Results are returned in the specified array as an array of arrays. Primary
#    array value is the row number. Secondary array in each row are the column
#    values ordered as specified in the query. These columns are comma separated
#    if multiple columns were specified in the query.
#
#    row [0, cols [0, 1, 2, ...] ]
#        [1, cols [0, 1, 2, ...] ]
#        [2, cols [0, 1, 2, ...] ]
#
#    Example dereference code. @cols is a list of column names from query.
#       foreach my $rec (@array) {
#          my @data = split(',', $rec);
#          my $line = '';
#          for (my $x = 0; $x <= $#cols; $x++) {
#             $line = join(',', $line, "$cols[$x]:$data[$x]");
#          }
#          $line =~ s/^,//;
#          print "$line\n";
#       }
#
# CALLING SYNTAX:
#    $result = &SelectDbArray($Dbh, $Query, \@Array);
#
# ARGUMENTS:
#    $Dbh              Database handle.
#    $Query 		     Select query to perform. 
#    $Array            Pointer to results array.                    
#
# RETURNED VALUES:
#    0 = Success,   1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub SelectDbArray {
   my($Dbh, $Query, $Array) = @_;

   if ($Query ne '') {
      # Escape SQLite reserved word 'group' Don't change if GROUP_CONCAT. 
      unless ($Query =~ m/\[group\]/ or $Query =~ m/GROUP_CONCAT/) {
         $Query =~ s/group/\[group\]/ig;
      }
      &DisplayDebug("SelectDbArray - Query: $Query");
      @$Array = ();
   
      my $sth = $Dbh->prepare($Query);
      if ($sth->err) {
         &ColorMessage("SelectDbArray - $sth->err", "BRIGHT_RED", '');
         return 1;
      }
      # Perform the query.
      $sth->execute();
      if ($sth->err) {
         &ColorMessage("SelectDbArray - $sth->err", "BRIGHT_RED", '');
         return 1;
      } 
      my @row;
      while (@row = $sth->fetchrow_array) {
         push (@$Array, join('|', @row));
      }
      &DisplayDebug("SelectDbArray - " . scalar @$Array . " records selected.");
   }
   else {
      &ColorMessage("   SelectDbArray no query specified.", "BRIGHT_RED", '');
      return 1;
   }
   return 0;
}

# =============================================================================
# FUNCTION:  SelectDbHash
#
# DESCRIPTION:
#    This routine is called to get and return data from the database. Results
#    are returned in the specified hash. Each hash entry corresponds to a
#    query returned row. The data are %% separated if multiple columns are
#    specified in the query.
#
# CALLING SYNTAX:
#    $result = &SelectDbHash($Dbh, $Query, \%Hash);
#
# ARGUMENTS:
#    $Dbh              Database handle.
#    $Query 		     Select query to perform. 
#    $Hash             Pointer to results hash.                    
#
# RETURNED VALUES:
#    0 = Success,   1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub SelectDbHash {
   my($Dbh, $Query, $Hash) = @_;

   # Escape SQLite reserved word 'group' Don't change if GROUP_CONCAT. 
   unless ($Query =~ m/\[group\]/ or $Query =~ m/GROUP_CONCAT/) {
      $Query =~ s/group/\[group\]/ig;
   }
   &DisplayDebug("SelectDbHash - Query: $Query");
   %$Hash = ();

   my $sth = $Dbh->prepare($Query);
   if ($sth->err) {
      &ColorMessage("SelectDbHash - $sth->err", "BRIGHT_RED", '');
	   return 1;
   }
   # Perform the query.
   $sth->execute();
   if ($sth->err) {
      &ColorMessage("SelectDbHash - $sth->err", "BRIGHT_RED", '');
	   return 1;
   }
   my @row;
   while (@row = $sth->fetchrow_hash) {
#      push (@$Array, join('%%', @row;
   }
   return 0;
}

# =============================================================================
# FUNCTION:  DeleteDbData
#
# DESCRIPTION:
#    This routine deletes the specified database record.
#
# CALLING SYNTAX:
#    $status = &DeleteDbData($Dbh, $Table, $Id);
#
# ARGUMENTS:
#    $Dbh            Database handle.
#    $Table 		   Table to process. 
#    $Id             Primary Id to delete.                    
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub DeleteDbData {
   my($Dbh, $Table, $Id) = @_;
   my %priKey = ('Presets' => 'Lid', 'Keywords' => 'Kid', 'Palettes' => 'Plid',
                 'Ledmaps' => 'Mlid');

   if (exists($priKey{$Table})) {
      # Build the query.
      my $query = "DELETE FROM $Table WHERE $Table.$priKey{$Table} = $Id;";   
      &DisplayDebug("DeleteDbData - query: '$query'");
      
      $sth = $Dbh->prepare($query);
      if ($sth->err) {
         &ColorMessage("DeleteDbData - $sth->err", "BRIGHT_RED", '');
         return 1;
      }
      # Perform the query.
      $sth->execute();
      if ($sth->err) {
         &ColorMessage("DeleteDbData - $sth->err", "BRIGHT_RED", '');
         return 1;
      }
   }
   else {
      &ColorMessage("   DeleteDbData '$Table' not in database.", "BRIGHT_RED", '');
      return 1;
   }
   return 0;  
}

# =============================================================================
# FUNCTION:  UpdateDbData
#
# DESCRIPTION:
#    This routine is called to update the specified database table. @Fields
#    holds the field names to be updated. These names must have corresponding
#    key entries in the %Data hash where the values are stored.  
#
# CALLING SYNTAX:
#    $result = &UpdateDbData($Dbh, $Table, \%Data, \@Field);
#
# ARGUMENTS:
#    $Dbh              Database handle.
#    $Table 		     Table to update; Presets, Keywords, or Segments.
#    $Data             Pointer to hash of data records.
#    $Field            Pointer to field list.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub UpdateDbData {
   my($Dbh, $Table, $Data, $Field) = @_;
   my %priKey = ('Presets' => 'Lid', 'Keywords' => 'Kid', 'Segments' => 'Sid');

   &DisplayDebug("UpdateDbData - Table: $Table   Field: '@$Field'");

   if ($Table ne '' and $#$Field >= 0 and exists($priKey{$Table})) {
      my $id = $priKey{$Table};
      
      # Build query string.
      my $setStr = 'SET';
      foreach my $fld (@$Field) {
         $setStr = join(' ', $setStr, $fld, '=', "'$$Data{$fld}',"); 
      }
      $setStr =~ s/,$//;
      $setStr =~ s/group/\[group\]/ig unless ($setStr =~ m/\[group\]/);
      my $query = "UPDATE $Table $setStr WHERE $id = $$Data{$id}";
      &DisplayDebug("UpdateDbData - prepare query: $query");

      # Prepare update.      
      my $sth = $Dbh->prepare($query);
      if ($sth->err) {
         &ColorMessage("UpdateDbData - prepare: $sth->err", "BRIGHT_RED", '');
	      return 1;
      }
      
      # Perform the query.
      $sth->execute();
      if ($sth->err) {
         &ColorMessage("UpdateDbData - execute: $sth->err", "BRIGHT_RED", '');
	      return 1;
      }
   }
   else {
      &ColorMessage("UpdateDbData - missing parameter", "BRIGHT_RED", '');
      return 1;
   }
   return 0;
}

# =============================================================================
# FUNCTION:  DumpDbTable
#
# DESCRIPTION:
#    This routine is called to print to console all records for the specified
#    database table. This is primarily a debugging aide. Called by the DUMP
#    command.
#
# CALLING SYNTAX:
#    $result = &DumpDbTable($Dbh, $Table);
#
# ARGUMENTS:
#    $Dbh              Database handle.
#    $Table 		     Table to dump.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub DumpDbTable {
   my($Dbh, $Table) = @_;

   if ($Table ne '') {
      &ColorMessage("\n=== $Table record dump ===", "WHITE", '');
      # Get table names.
      my $sth = $Dbh->prepare(qq(select name from pragma_table_info('$Table');));
      if ($sth->err) {
         &ColorMessage("DumpDbTable - $sth->err", "BRIGHT_RED", '');
         return 1;
      }
      # Perform the query.
      $sth->execute();
      if ($sth->err) {
         &ColorMessage("DumpDbTable - $sth->err", "BRIGHT_RED", '');
         return 1;
      }
      my @names = ();
      while (my @row = $sth->fetchrow_array) {
         push (@names, $row[0]);
      }
      &ColorMessage('' . join(' | ', @names), "WHITE", '');

      # Dump table records.
      my $sth = $Dbh->prepare("SELECT * FROM $Table;");
      if ($sth->err) {
         &ColorMessage("DumpDbTable - $sth->err", "BRIGHT_RED", '');
         return 1;
      }
      # Perform the query.
      $sth->execute();
      if ($sth->err) {
         &ColorMessage("DumpDbTable - $sth->err", "BRIGHT_RED", '');
         return 1;
      }
      my @rows;
      while (@rows = $sth->fetchrow_array) {
         &ColorMessage('' . join(' | ', @rows), "CYAN", '');
      }
      &ColorMessage('', "WHITE", '');
      &DisplayDebug("DumpDbTable - " . scalar @$Array . " records dumped.");
   }   
   return 0;
}

1;
