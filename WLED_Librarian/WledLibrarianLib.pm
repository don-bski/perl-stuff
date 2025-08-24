# ==============================================================================
# FILE: WledLibrarianLib.pm                                           8-24-2025
#
# SERVICES: Wled Librarian support code
#
# DESCRIPTION:
#   This program provides support code for the Wled Librarian program. Wled
#   librarian is a WLED tool for storing presets as individual entities in a
#   database. The presets can be selected/grouped in an ad-hoc manner for use
#   with WLED. 
#
# PERL VERSION:  5.28.1
#
# ==============================================================================
# -----------------------------------------------------------------------------
# Package Declaration
# -----------------------------------------------------------------------------
package WledLibrarianLib;
require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
   ReadFile
   WriteFile
   DateTime
   ValidateJson
   FormatPreset
   GetTmpDir
   PostJson
   PostUrl
   GetUrl
   WledReset
   ShowCmdHelp
   DisplayHeadline
   ProcessKeypadInput
   GetKeyboardInput
   ParseInput
   LoadPalettes
   LoadLedmaps
   ImportPresets
   ExportPresets
   AddTagGroup
   RemoveTagGroup
   GetLidList
   DisplayPresets
   ShowPresets
   DeletePresets
   DuplPresets
);

use WledLibrarianDBI;
use LWP::UserAgent;
use Term::ReadKey;
use DBI  qw(:utils);
use JSON;
# use Data::Dumper;
# use warnings;

# =============================================================================
# FUNCTION:  ReadFile
#
# DESCRIPTION:
#    This routine reads the specified file into the specified array.
#
# CALLING SYNTAX:
#    $result = &ReadFile($InputFile, \@Array, $Option);
#
# ARGUMENTS:
#    $InputFile      File to read.
#    \@Array         Pointer to array for the read records.
#    $Option         'trim' input records.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub ReadFile {
   my($InputFile, $ArrayPointer, $Option) = @_;
   my($FileHandle);

   unless (-e $InputFile) {
      &ColorMessage("Error: File not found: $InputFile", "BRIGHT_RED", '');
      return 1;
   }
   unless (open($FileHandle, '<', $InputFile)) {
      &ColorMessage("Error: opening file for read: $InputFile - $!",
                    "BRIGHT_RED", '');
      return 1;
   }
   @$ArrayPointer = <$FileHandle>;
   close($FileHandle);
   if ($Option =~ m/trim/i) {
      foreach my $line (@$ArrayPointer) {
         chomp($line);
         $line =~ s/^\s+|\s+$//g;
      }   
   }
   return 0;
}

# =============================================================================
# FUNCTION:  WriteFile
#
# DESCRIPTION:
#    This routine writes the specified array to the specified file. If the file
#    already exists, it is deleted.
#
# CALLING SYNTAX:
#    $result = &WriteFile($OutputFile, \@Array, $Option);
#
# ARGUMENTS:
#    $OutputFile     File to write.
#    $Array          Pointer to array of records to write.
#    $Option         'trim' records before writing to file.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub WriteFile {
   my($OutputFile, $OutputArrayPointer, $Option) = @_;
   my($FileHandle);
   
   unlink ($OutputFile) if (-e $OutputFile);

   unless (open($FileHandle, '>', $OutputFile)) {
      &ColorMessage("Error: opening file for write: $OutputFile - $!",
                    "BRIGHT_RED", '');
      return 1;
   }
   foreach my $line (@$OutputArrayPointer) {
      if ($Option =~ m/trim/i) {
         chomp($line);
         $line =~ s/^\s+|\s+$//g;
      }
      unless (print $FileHandle $line, "\n") {
         &ColorMessage("Error: writing file: $OutputFile - $!", "BRIGHT_RED", '');
         close($FileHandle);
         return 1;
      }
   }
   close($FileHandle);
   return 0;
}

# =============================================================================
# FUNCTION: DateTime
#
# DESCRIPTION:
#    This function, when called, returns a date/time string. The current server
#    time when called is used. The arguments may be used to effect how the date
#    and time components are joined into the result string. For example, if
#    $DateJoin = "-", $TimeJoin = ":", and $DatetimeJoin = "_", the returned
#    string would be formatted as follows.
#
#    2007-06-13_08:15:41
#
# CALLING SYNTAX:
#    $datetime = DateTime($DateJoin, $TimeJoin, $DatetimeJoin);
#
# ARGUMENTS:
#    $DateJoin         Character string to join date components 
#    $TimeJoin		   Character string to join time components
#    $DatetimeJoin	   Character string to join date and time components
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub DateTime {
   my($DateJoin, $TimeJoin, $DatetimeJoin) = @_;
   my($sec, $min, $hour, $day, $month, $year) = localtime;
   my($date, $time);

   $month = $month+1;
   $month = "0".$month if (length($month) == 1);
   $day = "0".$day if (length($day) == 1);
   $year = $year + 1900;
   $hour = "0".$hour if (length($hour) == 1);
   $min = "0".$min if (length($min) == 1);
   $sec = "0".$sec if (length($sec) == 1);

   $date = join($DateJoin, $year, $month, $day);
   $time = join($TimeJoin, $hour, $min, $sec); 
   return join($DatetimeJoin, $date, $time);
}

# =============================================================================
# FUNCTION:  ValidateJson
#
# DESCRIPTION:
#    This routine optionally removes multiple spaces from the specified array
#    or string. Only one of Array or String should be specified. The resulting
#    data is validated using decode_json. The cleaned array or string replaces
#    the input if clean is specified.
#
# CALLING SYNTAX:
#    $result = &ValidateJson(\@Array, \$String, $Clean, $Quiet);
#
# ARGUMENTS:
#    $Array          Pointer to array of json records.
#    $String         Pointer to string of json data.
#    $Clean          Milti-space removal if set.
#    $Quiet          No error message. Just return error.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub ValidateJson {
   my($ArrayPointer, $StringPointer, $Clean, $Quiet) = @_;
   my (@array, $check);

   if ($ArrayPointer ne '') {
      @array = @$ArrayPointer;                         # Local working copy
      if ($Clean ne '') {
         s/\x20{2,}//g foreach @array;              # Remove multiple spaces  
      } 
      $check = join('', @array);
      return 1 if (&chkJson(\$check));
      @$ArrayPointer = @array if ($Clean ne '');    # Replace with cleaned data.
   }
   elsif ($StringPointer ne '') {
      $check = $$StringPointer;
      $check =~ s/\x20{2,}//g if ($Clean ne '');       # Remove multiple spaces
      return 1 if (&chkJson(\$check));
      $StringPointer = $check if ($Clean ne '');    # Replace with cleaned data.
   }
   else {
      &ColorMessage("ValidateJson - No json specified.", "BRIGHT_RED", '');
      return 1;
   }
   return 0;

   # ----------
   # This private sub performs the json validation.   
   sub chkJson {
      my($Pntr) = @_;
      eval { JSON->new->decode($$Pntr) };      # Validate json data formatting.
      if ($@) {
         unless ($Quiet) {
            &ColorMessage("ValidateJson - Invalid json.", "BRIGHT_RED", '');
            &ColorMessage("ValidateJson - $@", "CYAN", '');
         }
         return 1;
      }
      return 0;
   }
}
# =============================================================================
# FUNCTION:  FormatPreset
#
# DESCRIPTION:
#    This routine reformats the specified WLED JSON preset data for readability
#    and use in a text editor. The serialized output is returned to the caller. 
#
#    The keys for each level of the preset data structure are read and stored
#    in a working hash. As the individual keys are processed, using the ordering
#    arrays, the key in the working hash is marked 'done'. Once the processing
#    of known keys is complete for the level, any not 'done' working hash keys
#    are processed. This helps to minimize future code changes when new preset 
#    keys are added.
#
#    A small private subroutine at the end of this subroutine handles boolean
#    and string key:value pairs. Boolean key values are set to 'true'/'false'
#    and strings are enclosed in double quotes.
#
# CALLING SYNTAX:
#    $result = &FormatPreset(\%Preset, $Pid);
#
# ARGUMENTS:
#    $Preset        Pointer to decoded_json data hash.
#    $Pid           Pid being processed.
#
# RETURNED VALUES:
#    <str> = Serialized data string,  '' = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub FormatPreset {
   my($JsonRef, $Pid) = @_;
   my($tab) = ' ' x 3;
   my(@order);
   my($segCount) = 32;                  # Segment down counter.
   my($spData) = '"' . $Pid . '":{';    # Start serealized preset data.

   &DisplayDebug("FormatPreset ... Pid: $Pid");
   # $Data::Dumper::Sortkeys = 1;       
   # print Dumper $JsonRef;
   
   # -------------------------------------------------
   if (exists($$JsonRef{'playlist'})) {
      # Get all of the playlist level 1 keys that are present in the input hash.
      # Used this to process unknown key:value pairs (not in @order). Also used
      # to indicate we've processed the key:value pair; set to 'done'. 
      my(%done1) = ();
      $done1{$_} = '' foreach (keys( %{$JsonRef} ));  # Initialize working hash.
      @order = ('on','n','ql','playlist');            # Key process order.
      
      # Process playlist data level 1. Last key checked must be 'playlist'. Then
      # add any unknown keys at this level.
      foreach my $key (@order) {   
         if (exists($$JsonRef{$key})) {
            if ($key eq 'playlist') {
               $done1{$key} = 'done';
               foreach my $udn (keys(%done1)) {          # Check/process undone keys.
                  next if ($done1{$udn} ne '');
                  my $value = &chkType($udn, $$JsonRef{$udn});
                  $spData .= join('', '"', $udn, '":', $value, ',');
                  $done1{$udn} = 'done';
               }
               $spData .= join('', '"', $key, '":{');
               last;
            }
            else {
               my $value = &chkType($key, $$JsonRef{$key});
               $spData .= join('', '"', $key, '":', $value, ',');
               $done1{$key} = 'done';
            }
         }
         else {
            $done1{$key} = 'ignore';
         }
      }
      # Process playlist data level 2.
      $playref = $$JsonRef{'playlist'};                    # playlist array reference
      %done2 = ();
      $done2{$_} = '' foreach (keys( %{$playref} ));       # Initialize working hash.
      @order = ('ps','dur','transition','r','repeat','end'); 
      foreach my $key (@order) {
         if (exists($playref->{$key})) {
            if (($key eq 'transition' or $key eq 'dur' or $key eq 'ps') and 
                ref($playref->{$key}) eq 'ARRAY') {
               $spData .= join('', "\n$tab", '"', $key, '":[');
               $spData .= join(',', @{$playref->{$key}});
               $spData .= '],';
               $done2{$key} = 'done';
            }
            else {
               my $value = &chkType($key, $playref->{$key});
               if ($key eq 'r') {
                  $spData .= join('', "\n$tab", '"', $key, '":', $value, ',');
               } 
               else {
                  $spData .= join('', '"', $key, '":', $value, ',');
               }
               $done2{$key} = 'done';
            }
         }
         else {
            $done2{$key} = 'ignore';
         }
      }
      foreach my $key (keys(%done2)) {             # Check/process undone keys.
         next if ($done2{$key} ne '');
         my $value = &chkType($key, $playref->{$key});
         $spData .= join('', '"', $key, '":', $value, ',');
         $done2{$key} = 'done';
      }
      $spData =~ s/,$//;
      # Playlist complete!
      $spData .= "}" if (exists($$JsonRef{'playlist'}));  # close playlist
      $spData .= "}";                                     # close json
   }
   else {
      # -------------------------------------------------
      # Get all of the preset level 1 keys that are present in the input hash.
      # Used to process unknown key:value pairs (not in @order1). Also used
      # to indicate we've processed the key:value pair; set to 'done'. 
      my(%done1) = ();
      $done1{$_} = '' foreach (keys( %{$JsonRef} ));  # Initialize working hash.
      @order = ('on','n','ql','bri','transition','mainseg','ledmap','seg');   
      
      # Process preset data level 1. Last key checked must be 'seg'. Then add
      # any unknown keys at this level.
      foreach my $key (@order) {                      # 1st line keys
         if (exists($$JsonRef{$key})) {
            if ($key eq 'seg') {
               $done1{$key} = 'done';
               foreach my $udn (keys(%done1)) {       # Check/process undone keys.
                  next if ($done1{$udn} ne '');
                  my $value = &chkType($udn, $$JsonRef{$udn});
                  $spData .= join('', '"', $udn, '":', $value, ',');
                  $done1{$udn} = 'done';
               }
               $spData .= join('', '"', $key, '":[', "\n");
               last;
            }
            else {
               if (exists($$JsonRef{$key})) {
                  my $value = &chkType($key, $$JsonRef{$key});
                  $spData .= join('', '"', $key, '":', $value, ',');
               }
               $done1{$key} = 'done';
            }
         }
         else {
            $done1{$key} = 'ignore';
         }
      }
      
      # Process preset data level 2 if input has 'seg'.
      if (exists($$JsonRef{'seg'})) {
         foreach my $segref (@{ $$JsonRef{'seg'} }) {     # Process each segment.
            %done2 = ();
            $done2{$_} = '' foreach (keys(%{$segref}));   # Initialize working hash.
            # Ignore segments with 'stop' and no 'id'. We'll add them later.  
            next if (exists($done2{'stop'}) and not exists($done2{'id'}));
            
            $spData .= "$tab\{";
            @order = ('id','start','stop','grp','spc','of','on','bri','frz');
            foreach my $key (@order) {                    # 2nd line keys
               if (exists($segref->{$key})) {
                  my $value = &chkType($key, $segref->{$key});
                  $spData .= join('', '"', $key, '":', $value, ',');
                  $done2{$key} = 'done';
               }
               else {
                  $done2{$key} = 'ignore';
               }
            }
            $spData .= "\n$tab";
            @order = ('col','fx','sx','ix','pal','rev','c1','c2','c3','sel');
            foreach my $key (@order) {                     # 3rd line keys
               if (exists($segref->{$key})) {
                  if ($key eq 'col') {                     # col is array of arrays
                     $spData .= join('', '"', $key, '":[');
                     foreach my $colref (@{ $segref->{'col'} }) { # Each color group.
                        $spData .= join('', "[", join(',', @{$colref}), "],");
                     }
                     $spData =~ s/,\n*\s*$//;
                     $spData .= '],';
                     $done2{$key} = 'done';
                  }
                  else {
                     my $value = &chkType($key, $segref->{$key});
                     $spData .= join('', '"', $key, '":', $value, ',');
                     $done2{$key} = 'done';
                  }
               }
               else {
                  $done2{$key} = 'ignore';
               }
            }
            $spData .= "\n$tab";
            @order = ('set','n','o1','o2','o3','si','m12','mi','cct'); 
            foreach my $key (@order) {                         # 4th line keys
               if (exists($segref->{$key})) {
                  my $value = &chkType($key, $segref->{$key});
                  $spData .= join('', '"', $key, '":', $value, ',');
                  $done2{$key} = 'done';
               }
               else {
                  $done2{$key} = 'ignore';
               }               
            }
               
            foreach my $key (keys(%done2)) {      # Check/process undone keys.
               next if ($done2{$key} ne '');
               my $value = &chkType($key, $segref->{$key});
               $spData .= join('', '"', $key, '":', $value, ',');
               # Don't mark these done so next segment gets them added too.
            }
            $spData =~ s/,\n*\s*$//;   # This segment is done!
            $spData .= "},\n";
            $segCount--;             # Decrement the segment down counter.
         }
         
         # Add {"stop":0} for all remaining unused segments. Unsure why this
         # is needed by WLED. Skip this step if no segments.
         if (exists($$JsonRef{'seg'})) {
            my $stopCnt = 10;        # Number of stops per line.
            $spData .= $tab;         # Indent 1st line.
            while ($segCount > 0) {
               if ($stopCnt == 0) {
                  $stopCnt = 9;
                  $spData .= "\n$tab" . '{"stop":0},';
               }
               else {
                  $spData .= '{"stop":0},';
                  $stopCnt--;
               }
               $segCount--;
            }
         }
         # All segments are done!
         $spData =~ s/,\n*\s*$//;
         $spData .= ']';      # close the segments array.
      }
      $spData =~ s/,\n*\s*$//;
      $spData .= '}';         # close the preset definition.
   }
   # Make sure the formatted JSON is valid. We need to wrap the string with {}
   # for the validity check.
   &DisplayDebug("FormatPreset: spData: $spData");
   my $check = join('', '{' ,$spData, '}');
   return '' if (&ValidateJson('', \$check, '', ''));
   return $spData;
   
   # ----------
   # This private sub sets boolean values to true/false and encloses strings
   # in double quotes. Any undefined key is returned as string.  
   sub chkType {
      my($Key, $Value) = @_;
      my(%bool) = ('on'=>1,'rev'=>1,'frz'=>1,'r'=>1,'sel'=>1,'mi'=>1,'nl.on'=>1,
         'rY'=>1,'mY'=>1,'tp'=>1,'send'=>1,'sgrp'=>1,'rgrp'=>1,'nn'=>1,'live'=>1);
      my(%nmbr) = ('id'=>1,'start'=>1,'stop'=>1,'grp'=>1,'spc'=>1,'of'=>1,'bri'=>1,
         'col'=>1,'fx'=>1,'sx'=>1,'ix'=>1,'pal'=>1,'c1'=>1,'c2'=>1,'c3'=>1,'set'=>1,
         'o1'=>1,'o2'=>1,'o3'=>1,'si'=>1,'m12'=>1,'cct'=>1,'transition'=>1,'tt'=>1,
         'tb'=>1,'ps'=>1,'psave'=>1,'pl'=>1,'pdel'=>1,'nl.dur'=>1,'nl.mode'=>1,
         'nl.tbri'=>1,'lor'=>1,'rnd'=>1,'rpt'=>1,'mainseg'=>1,'startY'=>1,'stopY'=>1,
         'rem'=>1,'recv'=>1,'w'=>1,'h'=>1,'lc'=>1,'rgbw'=>1,'wv'=>1, 'ledmap'=>1);
      my(%str) = ('n'=>1,'ql'=>1,'ver'=>1,'vid'=>1,'cn'=>1,'release'=>1);
      if (exists($bool{$Key})) {
         return 'true' if ($Value > 0);
         return 'false';
      }
      elsif (exists($nmbr{$Key})) {
         return $Value;
      }
      else {
         return join('', '"', $Value, '"');
      }
   }
}

# =============================================================================
# FUNCTION:  GetTmpDir
#
# DESCRIPTION:
#    This routine returns a path to the temporary directory on Linux and 
#    Windows by examining environment variables. If not resolved, an OS 
#    specific default is returned.
#
# CALLING SYNTAX:
#    $path = &GetTmpDir();
#
# ARGUMENTS:
#    None.
#
# RETURNED VALUES:
#    <path> = Success,  '' = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub GetTmpDir {
   my($path, $os) = ('','');

   # Check for an environment varible specified tempdir.
   foreach my $dir ('TMP','TEMP','TMPDIR','TEMPDIR') {
      if (exists($ENV{$dir})) {
         $path = $ENV{$dir};
         last;
      }
   }

   # Use a default if tempdir not specified.
   if ($^O =~ m/Win/i) {
      $os = 'win';
      $path = cwd() if ($path eq '');
   }
   else {
      $os = 'linux';
      $path = '/tmp' if ($path eq '');
   }
   chomp($path);
   $path =~ s/^\s+|\s+$//g;
   &DisplayDebug("GetTmpDir: os: $os   path: '$path'");
   unless (-d $path) {
      &ColorMessage("   Can't get temp directory: $path", "BRIGHT_RED", '');
      return '';
   }
   return $path;
} 

# =============================================================================
# FUNCTION:  PostJson
#
# DESCRIPTION:
#    This routine is used to POST the JSON formatted data specified by $Json
#    to the specified URL; typically http://<wled-ip>/json/state. 
#
#    my($agent) defines the POST user agent string. decode_json is used to 
#    validate the json payload. The POST is retried up to 3 times before 
#    returning error.
#
# CALLING SYNTAX:
#    $result = &PostJson($Url, $Json);
#
# ARGUMENTS:
#    $Url            Endpoint URL.
#    $Json           Json formatted data to POST
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub PostJson {
   my($Url, $Json) = @_;
   my($response, @data);
   my($agent) = "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, " .
                "like Gecko) Chrome/89.0.4389.114 Safari/537.36";
   my($retry) = 3;
   &DisplayDebug("PostJson: $Url   Json: '$Json'");

   my $userAgent = LWP::UserAgent->new(
      timeout => 5, agent => $agent, protocols_allowed => ['http',]);
   if ($Json ne '') {
      while ($retry > 0) {
         $response = $userAgent->post($Url,
            Content_Type => 'application/json',
            Content => "$Json"
         );
         last if ($response->is_success);
         $retry--;
         if ($retry == 0) {
            &ColorMessage("HTTP POST $Url", "BRIGHT_RED", '');
            &ColorMessage("HTTP POST error: " . $response->code, "BRIGHT_RED", '');
            &ColorMessage("HTTP POST error: " . $response->message .
                          "\n","BRIGHT_RED", '');
            return 1;
         }
         else {
            &ColorMessage("PostJson - POST retry ...", "CYAN", '');
            sleep 1;       # Wait a bit for network stabilization.
         }
      }
   }
   else {
      &ColorMessage("PostJson - No JSON data specified.", "BRIGHT_RED", '');
      return 1;
   }
   undef($userAgent);
   return 0;
}

# =============================================================================
# FUNCTION:  PostUrl
#
# DESCRIPTION:
#    This routine is used to POST the JSON formatted data specified by $File 
#    to the specified URL; typically http://<wled-ip>/upload.
#
#    Note that WLED parses the file name in the POST header to know how to 
#    handle the incoming data. The caller must ensure the specified file is 
#    correctly named; presets.json.
#
#    my($agent) defines the POST user agent string. The POST is retried up to
#    3 times before returning error.
#
# CALLING SYNTAX:
#    $result = &PostUrl($Url, $File);
#
# ARGUMENTS:
#    $Url            Endpoint URL.
#    $File           File to POST
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub PostUrl {
   my($Url, $File) = @_;
   my($request, $response, @data);
   my($agent) = "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, " .
                "like Gecko) Chrome/89.0.4389.114 Safari/537.36";
   my($retry) = 3;
   &DisplayDebug("PostUrl: $Url   File: '$File'");

   my $userAgent = LWP::UserAgent->new(
      timeout => 10, agent => $agent, protocols_allowed => ['http',]);
   if (-e $File) {
      # Send the data to WLED.
      while ($retry > 0) {
         $response = $userAgent->post($Url,
            Content_Type => 'form-data',
            Content => [ data => [ $File ],],
         );
         last if ($response->is_success);
         $retry--;
         print "\n" if ($retry == 2);
         if ($retry == 0) {
            &ColorMessage("PostUrl - Can't connect to WLED $Url", "BRIGHT_RED", '');
#            &ColorMessage("HTTP POST error: " . $response->code, "BRIGHT_RED", '');
#            &ColorMessage("HTTP POST error: " . $response->message .
#                          "\n","BRIGHT_RED", '');
            return 1;
         }
         else {
            &ColorMessage("PostUrl - POST retry ...", "CYAN", '');
            sleep 1;       # Wait a bit for network stabilization.
         }
      }
   }
   else {
      &ColorMessage("PostUrl - File not found: $File", "BRIGHT_RED", '');
      return 1;
   }
   undef($userAgent);
   return 0;
}

# =============================================================================
# FUNCTION:  GetUrl
#
# DESCRIPTION:
#    This routine performs a GET using the specified URL and returns the 
#    response data in the specified array.
# 
#    my($agent) defines the GET user agent string. The received json payload
#    is validated. The GET is retried up to 3 times before returning error.
#
# CALLING SYNTAX:
#    $result = &GetUrl($Url, $Resp);
#
# ARGUMENTS:
#    $Url            Endpoint URL.
#    $Resp           Pointer to response array.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error, 2 =  Palette not found
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub GetUrl {
   my($Url, $Resp) = @_;
   my($request, $response, @data);
   my($agent) = "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, " .
                "like Gecko) Chrome/89.0.4389.114 Safari/537.36";
   my($retry) = 3;
   &DisplayDebug("GetUrl URL: $Url");
   
   my $userAgent = LWP::UserAgent->new(
      timeout => 10, agent => $agent, protocols_allowed => ['http',]);
   while ($retry > 0) {
      $response = $userAgent->get($Url,
         Content_Type => 'application/json'
      );
      
      # Process response.
      @$Resp = ();                         # Clear previous response.
      if ($response->is_success) {
         @data = $response->decoded_content;
         s/[^\x00-\x7f]/\./g foreach (@data);  # Replace 'wide' chars with .
         if (&ValidateJson(\@data, '', '', 'quiet')) {
            &ColorMessage("GetUrl - Invalid json data. Retry Get ...", "CYAN", '');
            $retry--;
            if ($retry == 0) { 
               &ColorMessage("GetUrl - $@", "WHITE", '');
#               &ColorMessage("GetUrl - '$check'", "WHITE", '');
               last;
            }
            else {
               sleep 1;       # Wait a bit for network stabilization.
            }
         }
         else {
            push (@$Resp, @data);
            last;
         }
      }
      else {
         # Request for a palette.json beyond the last available will return 404 
         # status. In this case, suppress error report and return 2.
         my $statLine = $response->status_line;
         &DisplayDebug("GetUrl resp: $statLine");
         if ($Url =~ m/palette\d\.json$/ and $statLine =~ m/404/) {
            return 2;
         }
         else {  
            $retry--;
            print "\n" if ($retry == 2);
            if ($retry == 0) { 
               &ColorMessage("GetUrl - Can't connect to WLED $Url", "BRIGHT_RED", '');
               # &ColorMessage("HTTP GET error code: " . $response->code, "BRIGHT_RED", '');
               # &ColorMessage("HTTP GET error message: " . $response->message .
               #              "\n","BRIGHT_RED", '');
               return 1;
            }
            else {
               &ColorMessage("GetUrl - GET retry ...", "CYAN", '');
               sleep 1;       # Wait a bit for network stabilization.
            }
         }
      }
   }
   undef($userAgent);
   return 0;
}

# =============================================================================
# FUNCTION:  WledReset
#
# DESCRIPTION:
#    This routine initiates a reset to the specified WLED instance. This action
#    causes WLED to read its currently configured presets.
#
# CALLING SYNTAX:
#    $result = &WledReset($Ip);
#
# ARGUMENTS:
#    $Ip            WLED IP to reset.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub WledReset {
   my($Ip) = @_;
   my($agent) = "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, " .
                "like Gecko) Chrome/89.0.4389.114 Safari/537.36";
                
   my($wledUrl) = "http://$Ip/win&RB";
   &DisplayDebug("WledReset URL: $wledUrl");
   
   my $userAgent = LWP::UserAgent->new(
      timeout => 10, agent => $agent, protocols_allowed => ['http',]);
      
   $response = $userAgent->get($wledUrl,
      Content_Type => 'application/json'
   );
   
   undef($userAgent);
   return 0;
}

# =============================================================================
# FUNCTION:  ShowCmdHelp
#
# DESCRIPTION:
#    This routine displays the program command help. The user entered command
#    is parsed for any other command(s). This will limit the help output to
#    just those specified.
#
# CALLING SYNTAX:
#    $result = &ShowCmdHelp($Parsed);
#
# ARGUMENTS:
#    $Parsed     Pointer to parsed command line.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub ShowCmdHelp {
   my($Parsed) = @_;
   my(@cmds) = ();
   
   if ($$Parsed{'args0'} eq '') {
      @cmds = ('g','sh','so','i','a','r','de','du','ed','ex','q');
   }
   else {
      @cmds = split(' ', $$Parsed{'args0'});
   }
   
   foreach my $cmd (@cmds) {
      &ColorMessage("\n--------------------", "WHITE", ''); 
      if ($cmd =~ m/^g[eneral]*/) {
         &ColorMessage("Wled librarian is a simple tool that is used for the storage of WLED presets as", "WHITE", ''); 
         &ColorMessage("individual entities in a database. These preset data are tagged and grouped by the", "WHITE", '');
         &ColorMessage("user as needed. Presets can then be selected ad-hoc or by tag/group for export to a", "WHITE", '');
         &ColorMessage("WLED presets file or directly to WLED over WIFI.\n", "WHITE", '');
         &ColorMessage("The database is contained in a single file (default: wled_librarian.dbs) that is", "WHITE", '');
         &ColorMessage("located in the librarian startup directory or optionally specified on the program", "WHITE", '');
         &ColorMessage("start CLI (-f <file>). For database safeguard, periodically copy the file to a", "WHITE", '');
         &ColorMessage("safe external location using an appropriate operating system command. To restore,", "WHITE", ''); 
         &ColorMessage("copy the backup file to the working database file name.\n", "WHITE", '');
         &ColorMessage("Some operations involve the SHOW command and second command on the same user input", "WHITE", '');
         &ColorMessage("line. SHOW and its filter options select the presets that will be affected by the", "WHITE", '');
         &ColorMessage("second command. Use the SHOW command alone until the desired records are displayed.", "WHITE", '');
         &ColorMessage("Then, recall the SHOW command and add the second command to the end of the line.\n", "WHITE", '');
         &ColorMessage("Note: ", "BRIGHT_WHITE", 'nocr');
         &ColorMessage("The program has minimal operational guardrails. If told to delete a preset,", "WHITE", '');
         &ColorMessage("beyond a simple warning, it will do so. Use with care.\n", "WHITE", '');
         &ColorMessage("The following options can be specified on the program start CLI:\n", "WHITE", '');
         &ColorMessage("   -h            Displays the program CLI help.", "WHITE", '');
         &ColorMessage("   -a            Monochrome output. No ANSI color.", "WHITE", '');
         &ColorMessage("   -d            Run the program in debug mode.", "WHITE", '');
         &ColorMessage("   -p            Disable import preset ID checks.", "WHITE", '');
         &ColorMessage("   -r            Disable import preset data reformat.", "WHITE", '');
         &ColorMessage("   -f <file>     Use the specified database file.", "WHITE", '');
         &ColorMessage("   -c '<cmd>'    Process <cmds> non-interactive.\n", "WHITE", '');
         &ColorMessage("The -p option disables preset ID duplication checks during import. Preset data are", "WHITE", ''); 
         &ColorMessage("import with existing ID values. Also during import, the preset data is reformatted", "WHITE", ''); 
         &ColorMessage("for user readability (SHOW pdata). The -r option disables this processing which may", "WHITE", ''); 
         &ColorMessage("result in inconsistent key:value pair location within the pdata.\n", "WHITE", '');
         &ColorMessage("The -c option performs the specified command directly; no interactive prompt. Piped", "WHITE", '');
         &ColorMessage("STDIN input is also supported. Program results are sent to STDOUT and STDERR. Used to", "WHITE", '');
         &ColorMessage("integrate with an external program. <cmd> and piped input must comply with interactive", "WHITE", '');
         &ColorMessage("input usage rules.\n", "WHITE", ''); 
         &ColorMessage("Available program CLI keys:\n", "WHITE", ''); 
         &ColorMessage("   UpArrow  DnArrow     Recall previously used command.", "WHITE", '');
         &ColorMessage("   LftArrow  RgtArrow   Move curcor position in current CLI.", "WHITE", '');
         &ColorMessage("   Del  Backspace       Remove character in current CLI.", "WHITE", '');
         &ColorMessage("   Tab                  file: name search/entry, similar to OS. No ~ support.", "WHITE", '');
         &ColorMessage("   Home                 Display program headline command summary.\n", "WHITE", '');
         &ColorMessage("All librarian commands and options are case insensitive. Options and their value(s)", "WHITE", '');
         &ColorMessage("must be colon joined. Commands are capitalized in this help text for clairity.", "WHITE", '');
      }
      elsif ($cmd =~ m/^a[dd]*/) {
         &ColorMessage("ADD tag:<w>[:<w>] group:<w>[:<w>]", "BRIGHT_WHITE", '');
         &ColorMessage("Used to add one or more tag and/or group words <w> to the selected presets. Use the", "WHITE", '');
         &ColorMessage("SHOW command to filter for the desired preset(s). Then, recall the SHOW command and", "WHITE", '');
         &ColorMessage("add this command to the end. e.g. ", "WHITE", 'nocr');
         &ColorMessage("SHOW tag:new ADD tag:xmas,4th", "BRIGHT_WHITE", '');
      }
      elsif ($cmd =~ m/^rem[ove]*/) {
         &ColorMessage("REMOVE tag:<w> group:<w>", "BRIGHT_WHITE", '');
         &ColorMessage("Used to remove tag and/or group word(s) <w> from the selected presets. Use the SHOW", "WHITE", '');
         &ColorMessage("command to filter for the desired preset(s). Then, recall the SHOW command and add", "WHITE", '');
         &ColorMessage("this command to the end. e.g. ", "WHITE", 'nocr');
         &ColorMessage("SHOW group:test REMOVE group:test,xmas", "BRIGHT_WHITE", '');
      }
      elsif ($cmd =~ m/^de[lete]*/) {
         &ColorMessage("DELETE [lid:<i>] [pid:<i>] [tag:<w>] [group:<w>] [pal:<i>]", "BRIGHT_WHITE", '');
         &ColorMessage("Used to delete preset data record(s). Specify one or more record selection filters.", "WHITE", '');
         &ColorMessage("Respond to the confirmation prompt to proceed with the operation. Use caution. There", "WHITE", '');
         &ColorMessage("is no un-delete function. e.g. ", "WHITE", 'nocr');
         &ColorMessage("DELETE lid:10,13", "BRIGHT_WHITE", '');
      }
      elsif ($cmd =~ m/^du[pl]*/) {
         &ColorMessage("DUPL lid:<i> [pid:<i>] [pname:<n>] [qll:<w>] [tag:<w>] [group:<w>]", "BRIGHT_WHITE", '');
         &ColorMessage("Used to duplicate a preset data record. The lid specified source record is replicated", "WHITE", '');
         &ColorMessage("to the next available lid. Tag/group words associated with the source record are not", "WHITE", '');
         &ColorMessage("replicated. Optional parameters, if specified, are applied to the new preset record.", "WHITE", '');
         &ColorMessage("e.g. ", "WHITE", 'nocr');
         &ColorMessage("DUPL lid:17 pid:67 pname:TwinkleRedGrn tag:xmas", "BRIGHT_WHITE", '');
      }
      elsif ($cmd =~ m/^i[mport]*/) {
         &ColorMessage("IMPORT file:<file> wled[:<ip>] tag:<w>[,<w>] group:<w>[,<w>]", "BRIGHT_WHITE", '');
         &ColorMessage("Used to load JSON formatted WLED preset data into the database. The WLED presets", "WHITE", '');
         &ColorMessage("backup function in the WLED configuration menu can be used to create a file. Tag", "WHITE", '');
         &ColorMessage("and/or group words <w> can be applied to all presets during import. tag:new is", "WHITE", '');
         &ColorMessage("applied if neither is specified. e.g. ", "WHITE", 'nocr');
         &ColorMessage("IMPORT file:presets.json group:xmas\n", "BRIGHT_WHITE", '');
         &ColorMessage("The presets on an active WLED instance can be directly imported over WIFI. The", "WHITE", '');
         &ColorMessage("above tag/group word rules apply. Specify the IP address if WLED is not using", "WHITE", '');
         &ColorMessage("the 4.3.2.1 default. e.g. ", "WHITE", 'nocr');
         &ColorMessage("IMPORT wled:192.168.1.12 tag:test,xmas\n", "BRIGHT_WHITE", '');
         &ColorMessage("Presets, palettes, and ledmaps are user created in the WLED UI. Each consists of", "WHITE", '');
         &ColorMessage("JSON formatted field:value pairs. The palette and ledmap entities are associated", "WHITE", '');
         &ColorMessage("with a preset and saved in the WLED UI by the user. Field:value pairs within the", "WHITE", '');
         &ColorMessage("preset JSON link the palette and ledmap. This association is used to store the", "WHITE", '');
         &ColorMessage("preset, palette, and ledmap JSON data in the WledLibrarian's database.\n", "WHITE", '');
         &ColorMessage("During import, the preset JSON is checked for a custom palette linkage; pal:256", "WHITE", '');
         &ColorMessage("through pal:247 which corresponds to palette0.json through palette9.json files.", "WHITE", '');
         &ColorMessage("These files must be present along with the preset.json when an IMPORT file: is ", "WHITE", '');
         &ColorMessage("performed. IMPORT wled: will automatically transfer the associated palette data", "WHITE", '');
         &ColorMessage("from the WLED instance.\n", "WHITE", '');
         &ColorMessage("Import of ledmap data functions in a similar manner. The importing preset is", "WHITE", '');
         &ColorMessage("checked for ledmap:0 through ledmap:9 which corresponds to ledmap0.json through", "WHITE", '');
         &ColorMessage("ledmap9.json files. During subsequent preset EXPORT, the palette and ledmap JSON", "WHITE", '');
         &ColorMessage("entities are recreated; files or direct-to-WLED data transfers.\n", "WHITE", '');
         &ColorMessage("Checks are performed on each incoming preset to help mitigate duplications. If the", "WHITE", '');
         &ColorMessage("preset is already in the database, the user is prompted for an action; Skip, Replace", "WHITE", '');
         &ColorMessage("New, Keep, or #. # is a numeric value in the range 0-250. The importing preset ID is", "WHITE", ''); 
         &ColorMessage("changed to the entered value. Enter 0 to abort the import. For choice 'New', the", "WHITE", '');
         &ColorMessage("importing preset ID is changed to the lowest unused ID value. Choice 'Keep' imports", "WHITE", '');
         &ColorMessage("the preset with its existing pid.\n", "WHITE", '');
         &ColorMessage("Additional processing occurs for choice 'New' or a user entered ID value. During", "WHITE", '');
         &ColorMessage("the import operation, any importing playlists that use the old ID value will be", "WHITE", '');
         &ColorMessage("changed to use the new ID value.\n", "WHITE",'');
         &ColorMessage("Duplicate preset ID's or preset data will not affect the librarian database. All", "WHITE", '');
         &ColorMessage("presets are assigned a unique library ID (lid). The preset ID (pid), like tag or", "WHITE", '');
         &ColorMessage("group, is mainly used for SHOW command selection purposes. Import pid checks can", "WHITE", '');
         &ColorMessage("be disabled by adding the -p option to the program start CLI.", "WHITE", '');
      }
      elsif ($cmd =~ m/^sh[ow]*/) {
         &ColorMessage("SHOW tag:<w> group:<w> pid:<i> date:<d> lid:<i> pname:<w> type:<w> pdata pal", "BRIGHT_WHITE", '');
         &ColorMessage("     map src wled", "BRIGHT_WHITE", '');
         &ColorMessage("Used to display database records matching the specified criteria. For multiple", "WHITE", '');
         &ColorMessage("options, they are logically joined by AND in the database query. e.g. tag:new", "WHITE", '');
         &ColorMessage("(and) date:2025-06-13. For options that support multiple value input, the items", "WHITE", '');
         &ColorMessage("are logically OR-ed. e.g. pid:5,9 (5 or 9 or both).\n", "WHITE", ''); 
         &ColorMessage("Text based option input <w> is used in a 'contains' manner. e.g. pname:blu shows", "WHITE", '');
         &ColorMessage("all presets with 'blu' in the preset name. Numeric option input <i> is matched", "WHITE", '');
         &ColorMessage("exactly. The type option selects presets or playlists. e.g. type:pl. pdata shows", "WHITE", '');
         &ColorMessage("the preset's JSON in the output. src shows the preset's input source.\n", "WHITE", '');
         &ColorMessage("The pdata (preset data), pal (custom palette), map (ledmap), and src (source)", "WHITE", '');
         &ColorMessage("options display the specified data for each record output.\n", "WHITE", '');
         &ColorMessage("Option wled[:<ip>] will send the preset data to the specified WIFI connected WLED", "WHITE", '');
         &ColorMessage("instance. Unlike export, this action does not affect existing presets stored on the", "WHITE", '');
         &ColorMessage("WLED instance. If a playlist is sent, the presets it uses need to be present. If", "WHITE", '');
         &ColorMessage("multiple records are selected, only the first record is displayed.  e.g.", "WHITE", '');
         &ColorMessage("SHOW lid:2,4,7 pdata  ", "BRIGHT_WHITE", 'nocr');
         &ColorMessage("or  ", "WHITE", 'nocr');
         &ColorMessage("SHOW lid:3 wled ", "BRIGHT_WHITE", '');
      }
      elsif ($cmd =~ m/^ex[port]*/) {
         &ColorMessage("EXPORT file:<file> or wled[:<ip>]", "BRIGHT_WHITE", '');
         &ColorMessage("Used to send the SHOW selected preset pdata to a file or a WLED instance. The file", "WHITE", '');
         &ColorMessage("is WLED compatible for subsequent upload into WLED using its Config 'Restore presets'", "WHITE", '');
         &ColorMessage("function. Custom palette files, e.g. palette0.json, are also created if needed by one", "WHITE", '');
         &ColorMessage("or more of the presets.  ", "WHITE", 'nocr');
         &ColorMessage("SHOW group:4th EXPORT file:presets.json\n", "BRIGHT_WHITE", '');
         &ColorMessage("When 'wled' is specified, the preset data is sent to an active WLED over its WIFI", "WHITE", '');
         &ColorMessage("connection and replaces the current presets data. Preset used custom palettes are", "WHITE", '');
         &ColorMessage("also sent. The default WLED WIFI address is 4.3.2.1 if not specified. \ne.g. ", "WHITE", 'nocr');
         &ColorMessage("SHOW tag:xmas EXPORT wled:192.168.1.20\n", "BRIGHT_WHITE", '');
         &ColorMessage("Following WIFI transfer, the active WLED is reset to activate the presets.", "WHITE", '');
      }
      elsif ($cmd =~ m/^ed[it]*/) {
         &ColorMessage("EDIT lid:<i> [pid:<i>] [pname:<n>] [qll:<w>] [src:<w>]", "BRIGHT_WHITE", '');
         &ColorMessage("Used to change the preset ID (Pid), preset name (Pname) quick load label (Qll) or", "WHITE", ''); 
         &ColorMessage("import source (src) value. Lid: specifies the database record to change. Pid:, pname:", "WHITE", '');
         &ColorMessage("qll: and src: specify the replacement value. If the new preset name includes a space,", "WHITE", '');
         &ColorMessage("enclose the new value in single quotes. e.g. ", "WHITE", 'nocr');
         &ColorMessage("EDIT lid:2 pid:42 pname:'The Answer'", "BRIGHT_WHITE", '');
      }
      elsif ($cmd =~ m/^so[rt]*/) {
         &ColorMessage("SORT lid | pid | date | pname | tag | group:a|d", "BRIGHT_WHITE", '');
         &ColorMessage("Specifies the column and direction to order the SHOW command output. Ascending (low to", "WHITE", ''); 
         &ColorMessage("high), Descending (high to low). The setting remains in effect until changed. Default", "WHITE", ''); 
         &ColorMessage("column is Lid:a. e.g. ", "WHITE", 'nocr');
         &ColorMessage("SORT date:d.", "BRIGHT_WHITE", '');
      }
      elsif ($cmd =~ m/^q[uit]*/) {
         &ColorMessage("QUIT", "BRIGHT_WHITE", '');
         &ColorMessage("The quit command terminates the WLED ligrarian program. The current state of the", "WHITE", '');
         &ColorMessage("database is preserved.", "WHITE", ''); 
      }
      else {
         &ColorMessage("Help: Unknown command '$cmd'.", "WHITE", '');
      }
   }
   &ColorMessage('', "WHITE", '');
   return 0;
}

# =============================================================================
# FUNCTION:  DisplayHeadline
#
# DESCRIPTION:
#    This routine displays the program startup headline. It contains operational
#    information in an abreviated format. It is also output in response to the 
#    F1 key.
#
# CALLING SYNTAX:
#    $result = &DisplayHeadline();
#
# ARGUMENTS:
#    None
#
# RETURNED VALUES:
#    None
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub DisplayHeadline {
   
   my $line = '=' x 85;
   &ColorMessage("\n$line", "WHITE", '');
   &ColorMessage("WLED Preset Librarian\n", "BRIGHT_WHITE", '');
   &ColorMessage("Enter command and arguments. The show command allows a second command which operates", "WHITE", '');
   &ColorMessage("on the show selected presets. Use arrow keys for command recall. Default tag:new is", "WHITE", '');
   &ColorMessage("set for imported presets when no tag or group is specified. lid, pid, tag, and group", "WHITE", '');
   &ColorMessage("support multiple comma separated values. e.g. tag:<w>,<w>. Home key shows this header.", "WHITE", '');
   &ColorMessage("\nCommands:", "WHITE", ''); 
   &ColorMessage("   show [tag:<w>] [group:<w>] [pid:<i>] [date:<d>] [lid:<i>] [pname:<n>] [qll:<w>]", "WHITE", '');
   &ColorMessage("          [type:<w>] [pdata] [src] [pal] [map] [wled[:<ip>]]", "WHITE", '');
   &ColorMessage("      + [add [tag:<w>] [group:<w>]]", "WHITE", '');
   &ColorMessage("      + [remove [tag:<w>] [group:<w>]]", "WHITE", '');
   &ColorMessage("      + [export [file:<file>] [wled[:<ip>]]]", "WHITE", '');
   &ColorMessage("   delete [lid:<i>] [pid:<i>] [tag:<w>] [group:<w>]", "WHITE", '');
   &ColorMessage("   dupl lid:<i> [pid:<i>] [pname:<n>] [qll:<w>] [tag:<w>] [group:<w>]]", "WHITE", '');
   &ColorMessage("   edit lid:<i> [pid:<i>] [pname:<n>] [qll:<w>] [src:<w>]", "WHITE", '');
   &ColorMessage("   import [file:<file>] [wled:[<ip>]] [tag:<w>] [group:<w>]", "WHITE", '');
   &ColorMessage("   sort [lid|pid|date|pname|tag|group]:[a|d]", "WHITE", '');
   &ColorMessage("   help [add|change|delete|edit|export|general|import|quit|remove|show]", "WHITE", '');
   &ColorMessage("   quit", "WHITE", '');
   &ColorMessage("$line", "WHITE", '');
   return 0;
}

# =============================================================================
# FUNCTION:  PromptUser
#
# DESCRIPTION:
#    This routine is used to prompt the user for input and return the response
#    to the caller. Using a separate InWork hash each time, this input is not
#    recorded in the main input command history buffer. 
#
# CALLING SYNTAX:
#    $response = &PromptUser($Prompt, $Color);
#
# ARGUMENTS:
#    $Prompt         Use prompt string.
#    $Color          Prompt string color
#
# RETURNED VALUES:
#    User response string.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub PromptUser {
   my($Prompt, $Color) = @_;

   $Color = 'WHITE' if ($Color eq ''); 
     
   # Get user input.
   my %inWork = ('inbuf' => '', 'iptr' => 0, 'pcol' => $Color, 'noCmdcr' => 1,
                 'prompt' => $Prompt);
   while (&GetKeyboardInput(\%inWork) == 0) {  # Wait for user input.
      sleep .2;
   }
   return $inWork{'inbuf'};
}

# =============================================================================
# FUNCTION:  ProcessKeypadInput
#
# DESCRIPTION:
#    This routine is used to process user keyboard input. Keys with no action
#    defined are ignored. The following table shows the expected byte sequence
#    for the keypad keys. 'iptr' is the current input buffer position.
#
#       Key              Action                      Bytes
#       ---------        ---------------             --------  
#       up arrow         previous history entry      27 91 65
#       down arrow       next history entry          27 91 66
#       left arrow       previous input character    27 91 68
#       right arrow      next input character        27 91 67
#       end                                          27 91 70
#       home             Show program header         27 91 72
#       home             Win32::Console              27 91 49 126
#       page up                                      27 91 53 126
#       page down                                    27 91 54 126
#       keypad 5                                     27 91 69
#       keypad 0 (ins)                               27 91 50 126
#       keypad . (del)   Delete character            27 91 51 126
#       enter                                        10
#       /                                            47
#       +                                            43
#       -                                            45
#       backspace        Delete prev character       127
#       backspace        Win32::Console              8
#
# CALLING SYNTAX:
#    $result = &ProcessKeypadInput(\%InWork);
#
# ARGUMENTS:
#    $InWork           Pointer to input working hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub ProcessKeypadInput {
   my($InWork) = @_;

   # This hash is a dispatch table that defines the supported keypad byte 
   # sequences and the subroutine used to perform the actions.
   my(%keySub) = ('279151126' => \&delete, '127' => \&backSpace, '279165' => \&upArrow,
      '279166' => \&downArrow, '279168' => \&leftArrow, '279167' => \&rightArrow,
      '279172' => \&homeKey, '9' => \&tabKey,
      # These definitions are needed for the windows environment.
      '8' => \&backSpace, '279149126' => \&homeKey);
                  
   # This hash defines cursor move and edit ANSI sequences. Not all are used
   # For details, see https://en.wikipedia.org/wiki/ANSI_escape_code             
   my(%cursor) = ('left' => "\e[D", 'right' => "\e[C", 'up' => "\e[A", 
                  'down' => "\e[B", 'clrLeft' => "\e[1K", 'clrRight' => "\e[0K",
                  'clrLine' => "\e[2K", 'delLine' => "\e[2K\r", 'insLine' => "\e[L",
                  'insChar' => "\e[\@", 'delChar' => "\e[P", 'col1' => "\e[1G");               

   # &DisplayDebug("ProcessKeypadInput: inseq: '$$InWork{'inseq'}'  ". 
   #               "iptr: $$InWork{'iptr'}   inbuf: '$$InWork{'inbuf'}'  ".
   #               "hptr: $$InWork{'hptr'}   history: @{ $$InWork{'history'} }");
   if (exists($keySub{ $$InWork{'inseq'} })) {
      return $keySub{ $$InWork{'inseq'} }->($InWork,\%cursor);  
   }
   # &ColorMessage("ProcessKeypadInput: No handler for $$InWork{'inseq'}",
   #              'BRIGHT_RED', '');
   return 1;
   
   # ----------
   # Delete key handler. Remove character after 'iptr'. Characters 'iptr'+1
   # to end shift left. 
   sub delete {
      my($InWork, $Cursor) = @_;
      my $pre = substr($$InWork{'inbuf'}, 0, $$InWork{'iptr'});
      my $post = substr($$InWork{'inbuf'}, $$InWork{'iptr'} +1);
      return 0 if ($$InWork{'inbuf'} eq '' and $post eq '');  # Nothing to delete.
      $$InWork{'inbuf'} = join('', $pre, $post);
      my $len = length($post);
      $post = join('', $$Cursor{'clrRight'}, $post);
      $post = join('', $post, "\e[", $len, "D") if ($len > 0);
      print $post;
      return 0;
   }

   # ----------
   # Backspace key handler. Remove the character left of 'iptr'. Characters
   # 'iptr' to end shift left. 
   sub backSpace {
      my($InWork, $Cursor) = @_; 
      my $pre = substr($$InWork{'inbuf'}, 0, $$InWork{'iptr'} -1);
      return 0 if ($$InWork{'inbuf'} eq '' and $pre eq '');  # Nothing to delete.
      my $post = substr($$InWork{'inbuf'}, $$InWork{'iptr'});
      $$InWork{'inbuf'} = join('', $pre, $post);
      $$InWork{'iptr'}--;
      my $len = length($post);
      $post = join('', $$Cursor{'left'}, $$Cursor{'clrRight'}, $post);
      $post = join('', $post, "\e[", $len, "D") if ($len > 0);
      print $post;
      return 0;
   }
   
   # ----------
   # Up arrow key handler. Populate 'inbuf' with previous @'history' entry.
   sub upArrow {
      my($InWork, $Cursor) = @_;
      if ($#{ $$InWork{'history'} } >= 0) {     # Ignore key if no history.
         return 0 if ($$InWork{'hptr'} == 0);   # Ignore key if at min. 
         $$InWork{'inbuf'} = ${ $$InWork{'history'} }[ --$$InWork{'hptr'} ];
         $$InWork{'iptr'} = length($$InWork{'inbuf'});  # iptr to end-of-line  
         print $$Cursor{'delLine'};
         &ColorMessage($$InWork{'prompt'}, $$InWork{'pcol'}, 'nocr');         
         print $$InWork{'inbuf'};
      }
      return 0;
   }
   
   # ----------
   # Down arrow key handler. Populate 'inbuf' with next @'history' entry. 
   sub downArrow {
      my($InWork, $Cursor) = @_;
      if ($#{ $$InWork{'history'} } >= 0) {  # Ignore key if no history.
         return 0 if ($$InWork{'hptr'} > $#{ $$InWork{'history'} }); # Ignore if > max.
         if ($$InWork{'hptr'} >= $#{ $$InWork{'history'} }) {  # At max
            $$InWork{'inbuf'} = '';  # clear input.
            $$InWork{'hptr'} = $#{ $$InWork{'history'} } +1;  # point one beyond.
         }
         else {
            $$InWork{'inbuf'} = ${ $$InWork{'history'} }[ ++$$InWork{'hptr'} ];
         }
         $$InWork{'iptr'} = length($$InWork{'inbuf'});  # iptr to end-of-line
         print $$Cursor{'delLine'};
         &ColorMessage($$InWork{'prompt'}, $$InWork{'pcol'}, 'nocr');         
         print $$InWork{'inbuf'};
      }
      return 0;
   }
   
   # ----------
   # Left arrow key handler. Move cursor left unless already at start.
   sub leftArrow {
      my($InWork, $Cursor) = @_;
      if ($$InWork{'iptr'} > 0) {
         $$InWork{'iptr'}--;
         print $$Cursor{'left'};       # Move cursor left
      }
      return 0;
   }
   
   # ----------
   # Right arrow key handler. Move cursor right unless already at end.
   sub rightArrow {
      my($InWork, $Cursor) = @_;
      if ($$InWork{'iptr'} < length($$InWork{'inbuf'})) {
         $$InWork{'iptr'}++;
         print $$Cursor{'right'};      # Move cursor right
      }
      return 0;
   }
   # ----------
   # Home key handler. Display program headline.
   sub homeKey {
      my($InWork, $Cursor) = @_;
      DisplayHeadline();
      &ColorMessage($$InWork{'prompt'}, $$InWork{'pcol'}, 'nocr');         
      return 0;
   }

   # ----------
   # Tab key handler. Extends file: based on current user partial entry. 
   sub tabKey {
      my($InWork, $Cursor) = @_;
      my(@temp);
      
      if ($$InWork{'inbuf'} =~ m/file:([a-zA-Z0-9_\.\-\/]*)(\s*.*)$/) {
         my $spec = $1;
         my $opts = $2;
         my $newSpec;
         if ($spec eq '') {                       # Show all files.
            @temp = grep {(-f and -T) or -d} glob "*";   # Get file entries.
            return 0 if ($#temp < 0);             # Nothing to do.
            &lstFiles(\@temp, $InWork, $opts);    # Show user the file names.
         }
         else {                                   # Process partial filespec.
            # glob function needs trailing / for directories
            if (-d $spec and not $spec =~ m#/$#) {
               $$InWork{'inbuf'} =~ s#file:$spec#file:$spec/#;
               $$InWork{'iptr'}++;
               $spec = join('', $spec, '/');
               print '/';
            }
            @temp = grep {(-f and -T) or -d} glob "${spec}*";  # Get file entries.
            return 0 if ($#temp < 0);             # Nothing to do.
            if ($#temp == 0) {
               $newSpec = $temp[0];               # Single matching spec.
            }
            else { 
               # Expand the file spec. If full match we're done.                 
               $newSpec = &maxSpec($spec, \@temp, 0);  # Get max spec.
               my @check = grep /^$newSpec$/, @temp;
               if ($#check < 0) {
                  &lstFiles(\@temp, $InWork, $opts);   # Show the file names.
                  return 0;
               }
            }
            $$InWork{'inbuf'} =~ s/file:$spec/file:$newSpec/;
            $$InWork{'iptr'} = $$InWork{'iptr'} - length($spec) + length($newSpec);
            print join('', "\e[", length($spec), "D"), $$Cursor{'clrRight'}, $newSpec;
            if ($opts ne '') {
               print $opts, join('', "\e[", length($opts), "D");
               $$InWork{'iptr'} -= length($opts);
            }
         }
         return 0;
      }
   }

   # ----------   
   # Recursive code finds and returns a filespec based on input. Multiple
   # possible specs are in $Array. Make spec one character longer and check
   # again until only one. Used by tabKey.
   sub maxSpec {
      my($Spec, $Array, $Depth) = @_;
      return 'recursion error: $Depth' if ($Depth > 10);
      return substr($Spec, 0, length($Spec)-1) if ($#$Array <= 0);
      my $chkSpec = quotemeta(substr($$Array[0], 0, length($Spec)+1));
      my @temp = grep /^$chkSpec/, @$Array; 
      return $Spec if ($#temp <= 0);
      return &maxSpec($chkSpec, \@temp, $Depth +1);
   }

   # ----------   
   # Show the $Fnames pointer specified file names to the user. Follow it with
   # a new user prompt containings the current inbuf contents. Used by tabKey.
   sub lstFiles {
      my ($Fnames, $InWork, $Opts) = @_;
      
      my $max = 0;
      foreach my $name (@$Fnames) {  # Find longest file name.
         $max = length($name) if (length($name) > $max);
      }
      $max += 2;
      my $cols = int(72/$max);
      $cols = 1 if ($cols < 1);
      my $width = int(72/$cols);
      my $pad = ' ' x $width;
      my $cnt = 0;
      &ColorMessage('', "WHITE", '');
      foreach my $name (@$Fnames) {  # Show file names.
         &ColorMessage('  ', "WHITE", '') if ($cnt == 0);
         $name = join('', $name, '/') if (-d $name);
         print substr(join('', $name, $pad), 0, $width);
         $cnt++;
         if ($cnt >= $cols) {
            &ColorMessage('', "WHITE", '');
            $cnt = 0;
         }
      }
      &ColorMessage('', "WHITE", '') if ($cnt > 0);
      &ColorMessage($$InWork{'prompt'}, $$InWork{'pcol'}, 'nocr');
      print $$InWork{'inbuf'};
      $$InWork{'iptr'} = length($$InWork{'inbuf'});
      if ($Opts ne '') {
         print join('', "\e[", length($Opts), "D");
         $$InWork{'iptr'} -= length($Opts);
      }
      return 0;
   }
}   

# =============================================================================
# FUNCTION:  GetKeyboardInput
#
# DESCRIPTION:
#    This routine is used to check/get user keyboard input. This allows for
#    processing of keypad and arrow key input. This is used to impliment
#    basic input line editing and history/recall. These functions are not 
#    available with perl's $response = <STDIN> form of input. The down side
#    is this routine needs to be called periodically to check for user input.
#
#    Keypad and arrow key input is any key that returns a byte sequence that 
#    starts with the value 27. When detected, the bytes associated with it are
#    read and processed by &ProcessKeypadInput. The keypad sequence is passed
#    as a text string using the perl ord function to make it easier visualize.
#    Refer to &ProcessKeypadInput for a description of the sequences and the
#    actions performed.
#
#    The following shows the required working data %InWork and their required
#    initial start content. 
#
#    %InWork (
#       'inbuf'  => '',    Buffer used to accumulate keyboard input.
#       'iptr' => 0,       inbuf position. Used with console display.
#       'prompt' => '',    Optional: User input prompt string.
#       'pcol' => '',      Optional: Color for prompt string. 
#       ------             These keys are created at runtime.
#       'pflag' => 0,      Prompt string output when set.
#       'inseq' => '',     Holder for keypad escape sequence. 
#       'history' => [],   History array. Used with up/down arrow keys.
#       'hptr' => 0        History position. Used with up/down arrow keys.
#    );
#
#    Keyboard input is accumulated in $InWork{'inbuf'} until the enter key
#    is detected. The enter key is not added to inbuf or displayed console.
#    The inbuf data is returned to the caller. Following consumption, the 
#    caller must reset 'inbuf' and 'iptr' ('', 0) before the next input request. 
#
#    This subroutine uses the Term::ReadKey module to read keyboard input. Use
#    ReadMode('cbreak') in the main code to enable processing. This setting is
#    applied to the terminal session that was used to launched this program. 
#    Use ReadMode('normal') to restore default settings at program exit or
#    abnormal termination.
#
# CALLING SYNTAX:
#    $result = &GetKeyboardInput(\%InWork);
#
# ARGUMENTS:
#    $InWork      Pointer to input working hash.
#
# RETURNED VALUES:
#    0 = Input inprogress,  1 = Input available.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub GetKeyboardInput {
   my($InWork) = @_;
   
   my (%keyMap) = ('back' => 127, 'tab' => 9, 'enter' => 10);
   %keyMap = ('back' => 8, 'tab' => 9, 'enter' => 13) if ($^O =~ m/Win/i);

   # Output user prompt if necessary.
   if (exists($$InWork{'prompt'})) {
      $$InWork{'pflag'} = 0 unless (exists($$InWork{'pflag'}));
      unless ($$InWork{'pflag'} == 1) {
         &ColorMessage($$InWork{'prompt'}, $$InWork{'pcol'}, 'nocr');
         $$InWork{'pflag'} = 1;
      }
   }
   
   while (defined($char = ReadKey(-1))) {     # Get user input.
      # &DisplayDebug("ProcessKeyboardInput: char: '" . ord($char) . "'");
      
      if (ord($char) == 27) {                       # Escape sequence.
         $$InWork{'inseq'} = ord($char);
         # To properly handle auto-repeat input, take only the number of bytes
         # needed from ReadKey. See escape sequences in &ProcessKeypadInput 
         # description. 3rd byte in range 65-72 indicates a 3 byte keypad 
         # sequence. Otherwise, get 1 more byte (126).
         while (defined($char = ReadKey(-1))) {     # Get remaining bytes.
            $$InWork{'inseq'} = join('', $$InWork{'inseq'}, ord($char));
            last if (ord($char) =~ m/^(65|66|67|68|69|70|72)/);
            last if (ord($char) =~ m/^126/);
         }
         &DisplayDebug("ProcessKeyboardInput inseq: " . $$InWork{'inseq'});
         &ProcessKeypadInput($InWork);
      }
      elsif (ord($char) == $keyMap{'back'}) {         # Backspace key.
         $$InWork{'inseq'} = ord($char);
         &ProcessKeypadInput($InWork);
      }
      elsif (ord($char) == $keyMap{'tab'}) {          # Tab key.
         $$InWork{'inseq'} = ord($char);
         &ProcessKeypadInput($InWork)
      }
      elsif (ord($char) == $keyMap{'enter'}) {        # Enter key.
         if ($$InWork{'inbuf'} ne '') {
            # Create history array if not present.
            unless (defined( $$InWork{'history'} )) {
               push (@{ $$InWork{'history'} }, $$InWork{'inbuf'});
            }
            else {
               # Don't save to history if same command.
               if ($$InWork{'inbuf'} ne ${ $$InWork{'history'} }[-1]) {
                  push (@{ $$InWork{'history'} }, $$InWork{'inbuf'});
               }
            }
            # Point 1 beyond the new last history entry for upArrow.
            $$InWork{'hptr'} = scalar @{ $$InWork{'history'} };
            # Point to end of inbuf in case tabKey was used. Also cursor.
            $$InWork{'iptr'} = length($$InWork{'inbuf'});
            my $move = $$InWork{'iptr'} + length($$InWork{'prompt'});
            print "\e[1G", join('', "\e[", $move, "C");
            # Add \n to inbuf and print on console unless 'noCmdcr'.
            unless (defined($$InWork{'noCmdcr'})) {
               $$InWork{'inbuf'} = join('', $$InWork{'inbuf'}, $char);
               $$InWork{'iptr'}++;
               print $char;
            }
            $$InWork{'pflag'} = 0;   # Enable prompt output next call.
            return 1;        # Return input available to caller.
         }
         else {
            if ($$InWork{'prompt'} =~ m#y/n#i) {
               $$InWork{'pflag'} = 0;   # Enable prompt output next call.
               return 1;        # Return input available to caller.
            }
            &ColorMessage("\n$$InWork{'prompt'}", $$InWork{'pcol'}, 'nocr');
         }
      }
      else {   # Insert character at iptr.
         my $pre = substr($$InWork{'inbuf'}, 0, $$InWork{'iptr'});
         my $post = substr($$InWork{'inbuf'}, $$InWork{'iptr'});
         $$InWork{'inbuf'} = join('', $pre, $char, $post);
         $$InWork{'iptr'}++;
         # Display new character and reposition cursor to insert point.
         print $char, $post, "\b" x length($post);
      }
   }
   return 0;
}

# =============================================================================
# FUNCTION:  ParseInput
#
# DESCRIPTION:
#    This routine parses the specified input for supported entries and sets
#    any found in the specified hash. The fields to be parsed must be space 
#    separated. Multiple words separated by colon are preserved. For commands
#    that support a second command, e.g. SHOW, the commands are parsed left
#    to right. The first command and its options are set with keys ending in
#    0. Second command keys end in 1. For example: (caps not required, only 
#    for illustration)
#
#    SHOW TAG:new GROUP:xmas TYPE:preset CHANGE TAG:xmas2025
#
#    %Parsed = (
#       'cmd0' => 'show',
#       'tag0' => 'new',
#       'group0' => 'xmas',
#       'type0' => 'preset',
#       'cmd1' => 'change',
#       'tag1' => 'xmas2025'
#    )
#
# CALLING SYNTAX:
#    $result = &ParseInput($Dbh, $Cmd, \%Parsed);
#
# ARGUMENTS:
#    $Dbh           Pointer to database object.
#    $Cmd           Command to be parsed.
#    $Parsed        Pointer to hash for parsed output.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error
#
# ACCESSED GLOBAL VARIABLES:
#    $main::WledIp
# =============================================================================
sub ParseInput {
   my($Dbh, $Cmd, $Parsed) = @_;

   # These hashes define the supported commands and the options that may be used.
   # First command position and second.
   my(%validCmd1) = ('import' => 'file,wled,tag,group', 'help' => '', 'quit' => '',
      'show' => 'tag,group,date,pid,pname,type,lid,pdata,qll,src,pal,map,,wled', 
      'delete' => 'lid,pid,tag,group', 'dupl' => 'lid,pid,pname,qll,tag,group',
      'edit' => 'lid,pid,pname,qll,src', 'sort' => 'tag,group,date,pid,pname,lid',
      'dump' => 'tbl');
   my(%validCmd2) = ('add' => 'tag,group', 'remove' => 'tag,group', 
                     'export' => 'file,wled');
   
   # Initial clean up of the input string.
   my $cmdLine = $Cmd;
   chomp($cmdLine);               # Remove \n if any.
   $cmdLine =~ s/^\s+|\s+$//g;    # Remove leading and trailing \s if any.
   $cmdLine =~ s/\s{2,}/ /g;      # Multiple spaces to single.
   &DisplayDebug("ParseInput - cmdLine: '$cmdLine'");
   
   # Check for two commands and isolate if found.
   my @commands = ();
   foreach my $key (sort keys(%validCmd2)) {
      my $pos = index($cmdLine, $key);
      if ($pos > 0) {   # 2nd command?
         push (@commands, substr($cmdLine, 0, $pos));
         push (@commands, substr($cmdLine, $pos));
         last;
      }
   }
   push (@commands, $cmdLine) if ($#commands < 0);
   
   # Validate each command and its associated arguments. Each valid command
   # and argument is added to $Parsed; 1st command <arg>0, 2nd command <arg>1.
   my @vCmds;   my @opts;
   for (my $x = 0; $x <= $#commands; $x++) {
      if ($x == 0) {
         @vCmds = sort keys(%validCmd1);
      }
      else {
         @vCmds = sort keys(%validCmd2);
      }
      foreach my $key (@vCmds) {
         if ($commands[$x] =~ m/^$key(.*)$/i) {
            $$Parsed{"cmd$x"} = $key;
            $$Parsed{"args$x"} = $1;
            # Get options that are valid for this command.
            if ($x == 0) {
               @opts = split(',', $validCmd1{$key});
            }
            else {
               @opts = split(',', $validCmd2{$key});
            }
            last;
         }
      }
      $$Parsed{"args$x"} =~ s/^\s+//;
      $$Parsed{"args$x"} =~ s/:\s+/:/g;   
      &DisplayDebug("ParseInput - cmd${x}: " . $$Parsed{"cmd${x}"} .
                    "  args${x}: " . $$Parsed{"args${x}"});
      # Parse the argument string and set valid options. Some commands don't
      # have options so this loop won't run.
      foreach my $opt (@opts) {
         if ($$Parsed{"cmd${x}"} eq 'sort') {
            if ($$Parsed{"args${x}"}  =~ m/($opt)(.*)/i) {
               $$Parsed{'sortmp'} = "$1$2";
               last;
            }
            elsif ($$Parsed{"args${x}"}  =~ m/($opt)(.*)/i) {
               $$Parsed{'sortmp'} = "$1$2";
               last;
            }
         }
         else {
            if ($opt eq 'file') {
               if ($$Parsed{"args${x}"} =~ m#$opt:(.+)#i) {
                  my $file = $1;
                  if ($file =~ m/(["|'].+?["|'])/) {  # "' enclosed "'
                     $$Parsed{"${opt}${x}"} = $1;
                  }
                  elsif ($file =~ m/\s/) {
                     $$Parsed{"${opt}${x}"} = substr($file, 0, index($file,' ')); 
                  }
                  else {
                     $$Parsed{"${opt}${x}"} = $file;
                  }
               }
            }
            elsif ($opt eq 'lid' or $opt eq 'pid') {
               # Only digits and comma for lid/pid/
               if ($$Parsed{"args${x}"}  =~ m/$opt:([0-9,]+)/i) {
                  $$Parsed{"${opt}${x}"} = $1;
                  $$Parsed{"${opt}${x}"} =~ s/,,/,/g;
               }
            }
            elsif ($opt eq 'wled') {
               if ($$Parsed{"args${x}"}  =~ m/($opt:)([0-9\.]*)/i) {
                  $$Parsed{"${opt}${x}"} = "${1}${2}";
               } 
               elsif ($$Parsed{"args${x}"}  =~ m/($opt)/) {
                  $$Parsed{"${opt}${x}"} = join(':', $1, $main::WledIp);
               } 
            }
            elsif ($opt eq 'pname') {
               if ($$Parsed{"args${x}"} =~ m/$opt:(.+)/) {
                  my $pname = $1;
                  if ($pname =~ m/^["|'](.+?)["|']/) {
                     $$Parsed{"${opt}${x}"} = $1; 
                  }   
                  else {
                     $$Parsed{"${opt}${x}"} = substr($pname, 0, index($pname,' ')); 
                  }
               }
            }
            elsif ($opt eq 'pdata') {
               # pdata is a flag. No associated value.
               $$Parsed{"${opt}${x}"} = 1 if ($$Parsed{"args${x}"} =~ m/pdata/i);
            }
            elsif ($opt eq 'pal') {
               # pal is a flag. No associated value.
               $$Parsed{"${opt}${x}"} = 1 if ($$Parsed{"args${x}"} =~ m/pal/i);
            }
            elsif ($opt eq 'map') {
               # map is a flag. No associated value.
               $$Parsed{"${opt}${x}"} = 1 if ($$Parsed{"args${x}"} =~ m/map/i);
            }
            elsif ($opt eq 'src') {
               if ($$Parsed{"args${x}"}  =~ m/$opt:([a-zA-Z0-9_,\-]+)/i) {
                  $$Parsed{"${opt}${x}"} = $1;
               } 
               elsif ($$Parsed{"args${x}"}  =~ m/$opt/) {
                  $$Parsed{"${opt}${x}"} = 1;
               } 
            }
            elsif ($$Parsed{"args${x}"} =~ m/$opt:([a-zA-Z0-9_,\-]+)/i) {
               $$Parsed{"${opt}${x}"} = $1;
               $$Parsed{"${opt}${x}"} =~ s/,,/,/g;
            }
         }
      } 
   }

   # At this point, the useable input data has been stored in $Parsed. Call
   # the primary command handler. Handler calls 2nd command handler if needed.
   foreach my $key (sort keys(%$Parsed)) {
      &DisplayDebug("ParseInput done: $key -> $$Parsed{$key}");
   }      
   if ($$Parsed{'cmd0'} eq 'help') {
      return &ShowCmdHelp($Parsed);  
   }
   elsif ($$Parsed{'cmd0'} eq 'import') {  
      return &ImportPresets($Dbh, $Parsed);  
   }
   elsif ($$Parsed{'cmd0'} eq 'delete') {
      return &DeletePresets($Dbh, $Parsed);  
   }
   elsif ($$Parsed{'cmd0'} eq 'dupl') {
      return &DuplPreset($Dbh, $Parsed);  
   }
   elsif ($$Parsed{'cmd0'} eq 'show') {
      return &ShowPresets($Dbh, $Parsed);
   } 
   elsif ($$Parsed{'cmd0'} eq 'edit') {
      return &EditPresets($Dbh, $Parsed);
   } 
   elsif ($$Parsed{'cmd0'} eq 'sort') {
      if (exists($$Parsed{'sortmp'})) {
         $$Parsed{'sortmp'} .= ':a' unless ($$Parsed{'sortmp'} =~ m/:/);  
         my ($col,$dir) = split(':', $$Parsed{'sortmp'});
         $col = ucfirst($col);
         if ($dir eq 'a' or $dir eq 'd') {
            $dir =~ s/a/ASC/;
            $dir =~ s/d/DESC/;
         }
         else {
            &ColorMessage("   Unsupported sort.", "YELLOW", '');
            return 1;
         }
         $$Parsed{'sort'} = join(' ', $col, $dir);
         &ColorMessage("   Sorting set to " . $$Parsed{'sort'}, 'YELLOW', '');
      }
      else {
         &ColorMessage("   Sorting on column $$Parsed{'sort'}" , 'YELLOW', '');
      }
      return 0;
   }
   elsif ($$Parsed{'cmd0'} eq 'dump') {
      my (@tables) = ('Presets','Keywords','Palettes','Ledmaps');
      if (exists($$Parsed{'tbl0'})) {
         foreach my $table (@tables) {
            if ($table =~ m/^$$Parsed{'tbl0'}/i) {
               return 1 if (&DumpDbTable($Dbh, $table));
            }
         }
      }
      return 0;
   } 
   elsif ($$Parsed{'cmd0'} eq 'quit') {
      return 0;
   } 
   &ColorMessage("   Unsupported command.", "YELLOW", '');
   return 1;
}

# =============================================================================
# FUNCTION:  LoadPalettes
#
# DESCRIPTION:
#    This routine loads custom palette data. WLED custom palettes are specified 
#    as pal:xxx in the preset JSON. Custom palettes are in the range 247-256.
#    This cooresponds to files palette0.json through palette9. The palette data
#    is stored in the specified hash; key 247-256, value JSON text data.
#
# CALLING SYNTAX:
#    $result = &LoadPalettes($Parsed, \%PalData);
#
# ARGUMENTS:
#    $Parsed       Pointer to parsed data hash.
#    $PalData      Pointer to hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub LoadPalettes {
   my($Parsed, $PalData) = @_;
   my(@data) = ();
   
   &DisplayDebug("LoadPalettes ...");
   foreach my $pal (256,255,254,253,252,251,250,249,248,247) {
      my $file = join('', 'palette', abs($pal - 256), '.json');
      if (exists($$Parsed{'file0'})) { 
         my $srcPath = '';
         if ($$Parsed{'file0'} =~ m#/#) {
            $srcPath = substr($$Parsed{'file0'}, 0, rindex($$Parsed{'file0'}, '/'));
         }
         $file = join('/', $srcPath, $file) if ($srcPath ne '');
         &DisplayDebug("LoadPalettes pal: $pal - file: $file");
         if (-e $file) {
            return 1 if (&ReadFile($file, \@data, 'trim'));
            $data[0] =~ s/[\r\n]+//g;
            $data[0] =~ s/\s{2,}/ /g;
            $$PalData{$pal} = $data[0];
            &DisplayDebug("LoadPalettes PalData: '$$PalData{$pal}'");
         }
      }
      elsif (exists($$Parsed{'wled0'})) {
         my $ip = $1 if ($$Parsed{'wled0'} =~ m/wled:(.+)/);
         my $url = join("/", 'http:/', $ip, $file);
         my $result = &GetUrl($url, \@data);
         if ($result == 0) {
            $data[0] =~ s/[\r\n]+//g;
            $data[0] =~ s/\s{2,}/ /g;
            $$PalData{$pal} = $data[0];
            &DisplayDebug("LoadPalettes pal: $pal - file: $file");
         }
      }
   }   
   return 0;
}

# =============================================================================
# FUNCTION:  LoadLedmaps
#
# DESCRIPTION:
#    This routine loads ledmap data. WLED ledmaps are specified as ledmap:x 
#    in the preset JSON. Ledmaps are in the range 0-9 and coorespond to 
#    files ledmap0.json through ledmap9.json. The ledmap data is stored in
#    the specified hash; key 0-9, value JSON text data.
#
# CALLING SYNTAX:
#    $result = &LoadLedmaps($Parsed, \%MapData);
#
# ARGUMENTS:
#    $Parsed       Pointer to parsed data hash.
#    $MapData      Pointer to hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub LoadLedmaps {
   my($Parsed, $MapData) = @_;
   my(@data) = ();
   
   &DisplayDebug("LoadLedmaps ...");
   foreach my $map (0..9) {
      my $file = join('', 'ledmap', $map, '.json');
      if (exists($$Parsed{'file0'})) { 
         my $srcPath = '';
         if ($$Parsed{'file0'} =~ m#/#) {
            $srcPath = substr($$Parsed{'file0'}, 0, rindex($$Parsed{'file0'}, '/'));
         }
         $file = join('/', $srcPath, $file) if ($srcPath ne '');
         &DisplayDebug("LoadLedmaps map: $map - file: $file");
         if (-e $file) {
            return 1 if (&ReadFile($file, \@data, 'trim'));
            my $ledmap = join('', @data);
            $ledmap =~ s/[\r\n]+//g;
            $ledmap =~ s/\s{2,}/ /g;
            $$MapData{$map} = $ledmap;
            &DisplayDebug("LoadLedmaps MapData: '$$MapData{$map}'");
         }
      }
      elsif (exists($$Parsed{'wled0'})) {
         my $ip = $1 if ($$Parsed{'wled0'} =~ m/wled:(.+)/);
         my $url = join("/", 'http:/', $ip, $file);
         my $result = &GetUrl($url, \@data);
         if ($result == 0) {
            my $ledmap = join('', @data);
            $ledmap =~ s/[\r\n]+//g;
            $ledmap =~ s/\s{2,}/ /g;
            $$MapData{$map} = $ledmap;
            &DisplayDebug("LoadLedmaps map: $map - file: $file");
         }
      }
   }   
   return 0;
}

# =============================================================================
# FUNCTION:  ImportDuplicate
#
# DESCRIPTION:
#    This routine gets the user action when a potential import duplication
#    with existing database record is detected. Originally part of the 
#    ImportPreset subroutine. Better functional organization as a separate
#    subroutine.
#
# CALLING SYNTAX:
#    $result = &ImportDuplicate($Dbh, $Parsed, \$DbData, \@DupArray,
#              \@Cols, \%newId, \%newPlist);
#
# ARGUMENTS:
#    $Dbh          Database object reference.
#    $Parsed       Pointer to parsed data hash.
#    $DbData       Pointer to import working hash.
#    $DupArray     Pointer to duplicating records.
#    $Cols         Pointer to dupArray column names.
#    $NewId        Pointer to new id hash.
#    $NewPlist     Pointer to new playlist hash.
#
# RETURNED VALUES:
#    0 = Continue,  1 = Error, 2 = Skip record.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub ImportDuplicate {
   my($Dbh, $Parsed, $DbData, $DupArray, $Cols, $NewId, $NewPlist) = @_;
   my($pidVal);   my($pidLimit) = 250;

   # Display the existing entries and prompt the user for action. 
   &ColorMessage("\nImport duplicate -> ", 'BRIGHT_YELLOW', 'nocr');
   &ColorMessage(ucfirst($$DbData{'Type'}) . " $$DbData{'Pid'} - " .
              "$$DbData{'Pname'}", 'BRIGHT_CYAN', '');
   # 'Lid','Type','Pid','Pname','Date','Src'
   foreach my $rec (@$DupArray) {
      my @col = split('\|', $rec);
      &ColorMessage("Existing -> ", 'BRIGHT_YELLOW', 'nocr');
      &ColorMessage("Lid: $col[0]  " . ucfirst($col[1]) . " $col[2] - $col[3] " .
                    "  Imported: $col[4]   Src: $col[5]", 'WHITE', '');
   }

   while (1) {
      # Get user input.
      my $resp = &PromptUser('Skip, Replace, New, Keep, or # (0 to abort) -> ',
                             'BRIGHT_YELLOW');
      # Perform user specified action.
      if ($resp =~ m/^s[kip]*$/i) {
         &ColorMessage("   Preset skipped.", 'YELLOW', '');
         return 2;
      }
      elsif ($resp =~ m/^k[eep]*$/i) {
         return 0;
      }
      elsif ($resp =~ m/^r[eplace]*$/i) {
         my @pFlds = ('Pid','Pname','Qll','Pdata','Type','Src','Date');
         # split on |. \| escapes 'or' meaning.
         my @col = split('\|', $$DupArray[0]);
         $$DbData{'Lid'} = $col[0];
         return 1 if (&UpdateDbData($Dbh, 'Presets', \%$DbData,, \@pFlds));
         if ($$DbData{'Tag'} ne 'new' or exists($$DbData{'Group'})) {
            my @kFlds = ('Tag');
            push (@kFlds, 'Group') if (exists($$DbData{'Group'}));
            $$DbData{'Kid'} = $col[0];
            return 1 if (&UpdateDbData($Dbh, 'Keywords', \%$DbData, \@kFlds));
         }
         &ColorMessage("   Existing Pid $col[2] replaced.", 'YELLOW', '');
         return 2;
      }
      elsif ($resp =~ m/^n[ew]*$/i) {
         my @inUse;  # Get the Pids that are in use.
         my $query = "SELECT Pid FROM Presets ORDER BY Pid LIMIT $pidLimit;";
         return 1 if (&SelectDbArray($Dbh, $query, \@inUse));
         $pidVal = 0;
         foreach my $pid (1..$pidLimit) {
            unless (grep(/^$pid$/, @inUse)) {
               $pidVal = $pid;
               last;
            }
         }
         if ($pidVal == 0) {
            &ColorMessage("   No available pid value.","BRIGHT_RED", '');
            return 1;
         }
      }
      elsif ($resp =~ m/^(\d+)$/) {
         $pidVal = $1;
         if ($pidVal == 0) {  # User entered 0 to abort.
            &ColorMessage('', "WHITE", '');
            return 1 
        }
        if ($pidVal < 1 or $pidVal > $pidLimit) {
           &ColorMessage("   Invalid pid value. Range 1-$pidLimit.", 
                         'BRIGHT_RED','');
           next;
        }
        # Get the Pids that are in use. 
         my @inUse; 
         my $query = "SELECT Pid FROM Presets ORDER BY Pid LIMIT $pidLimit;";
         return 1 if (&SelectDbArray($Dbh, $query, \@inUse));
         if (grep(/$pidVal/, @inUse)) {
            &ColorMessage("   Pid value in use.", 'BRIGHT_RED','');
            next;
         }
      }
      else {
         &ColorMessage("   Unsupported input '$resp'", 'BRIGHT_RED','');
         next;
      }
      # Save the following for later if a playlist id needs update.
      $$NewId{ $$DbData{'Pid'} } = $pidVal;   # save old => new
      # Set new preset id value.
      $$DbData{'Pid'} = $pidVal;
      $$DbData{'Pdata'} =~ s/^"(\d+)"/"$pidVal"/;
      # If playlist, save the Pdata for later update if needed.
      if ($$DbData{'Type'} =~ /playlist/) { 
         $$NewPlist{$pidVal} = $$DbData{'Pdata'};
      }
      last;    # Break out of while loop.
   }
   return 0;
}

# =============================================================================
# FUNCTION:  ImportPresets
#
# DESCRIPTION:
#    This routine imports the user specified preset data into the database.
#    The user entered command is parsed for the input file and any optional
#    tag/group words. tag:new is added if no tag/group words are specified.
#
#    Table: Presets  - Holds the JSON imported from WLED presets.json files.
#       Lid    - Database record id used for SQL table joins.
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
# CALLING SYNTAX:
#    $result = &ImportPresets($Dbh, $Parsed);
#
# ARGUMENTS:
#    $Dbh          Database object reference.
#    $Parsed       Pointer to parsed data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::cliOpts{p}, $main::cliOpts{r}
# =============================================================================
sub ImportPresets {
   my($Dbh, $Parsed) = @_;
   my($srcFile, $tstData, $lastPid);
   
   &DisplayDebug("ImportPresets file: '$$Parsed{'file0'}'  tag: '$$Parsed{'tag0'}'" .
      "  group: '$$Parsed{'group0'}'  wled: '$$Parsed{'wled0'}'");
   my (@data) = (); 
   if (exists($$Parsed{'file0'})) { 
      if (-e $$Parsed{'file0'}) {
         if ($$Parsed{'file0'} =~ m/palette/) {
            &ColorMessage("   Direct palette file import is not implemented.", "YELLOW", '');
            return 1;
         }
         else {
            # Load preset data into working array and validate.    
            return 1 if (&ReadFile($$Parsed{'file0'}, \@data, 'trim'));
            unless (grep /"0":\{\},/, @data) {         # Check for preset 0 "0":{},
               &ColorMessage("\nFile content doesn't look like WLED preset data. ",
                             "BRIGHT_YELLOW", 'nocr');
               my $resp = &PromptUser('Continue? [y/N] -> ','BRIGHT_YELLOW');
               &ColorMessage('', "WHITE", '');
               return 0 unless ($resp =~ m/y/i);
            }
            $srcFile = $$Parsed{'file0'};
            if ($srcFile =~ m#/#) {
               $srcFile = substr($srcFile, rindex($srcFile, '/')+1);
            }
         }
      }
      else {
         &ColorMessage("   File not found: $$Parsed{'file0'}", "BRIGHT_RED", '');
         return 1;
      }
   }
   elsif (exists($$Parsed{'wled0'})) {    # Get the WLED presets into @data
      my $ip = $1 if ($$Parsed{'wled0'} =~ m/wled:(.+)/);
      return 1 if (&GetUrl(join("/", 'http:/', $ip, 'presets.json'), \@data));
      $srcFile = 'wifi';
   }
   else {
      &ColorMessage("   No import source specified.", "YELLOW", '');
      return 1;
   }
   
   # Decode the json data.
   my $rawJson = join('', @data);
   return 1 if (&ValidateJson('', \$rawJson, 'clean', ''));
   # Get a working reference. Add utf8-> before decode to handle UTF-8.
   my $jsonRef = JSON->new->decode($rawJson);
   # $Data::Dumper::Sortkeys = 1;       
   # print Dumper $jsonRef;

   # Initialize working variables for Presets, Keywords, and Palettes DB insert.      
   my %dbData = ();                      # Working hash.
   my $insertTime = &DateTime('-', ':', '_');
   my %newId = ();     # Old -> New preset id working hash.
   my %newPlist = ();  # Playlist update working hash. 
   my %lidSave = ();   # Playlist update save array for Lid.
   $dbData{'Tag'} = $$Parsed{'tag0'} if (exists($$Parsed{'tag0'}));
   $dbData{'Group'} = $$Parsed{'group0'} if (exists($$Parsed{'group0'}));
   $dbData{'Tag'} = 'new' unless (exists($dbData{'Tag'}) or exists($dbData{'Group'}));
   my @presetFields = ('Pid','Pname','Qll','Src','Type','Date','Pdata');
   my @keywordFields = ('Kid','Tag','Group');
   my @paletteFields = ('Palid','Plid','Plnum','Pldata');
   my @ledmapFields = ('Mapid','Mlid','Mnum','Mdata');
   my %palData = ();   # Keeps track of already loaded palette data.
   my %mapData = ();   # Keeps track of already loaded ledmap data.
   
   # Step through the input presets. Isolate the data for the separate 
   # database fields. Check that each record begins with a preset id. 
   #
   # The $dbData{'Lid'} is set to NULL for insert which causes a unique DB 
   # generated value to be assigned to the record. &InsertDbData returns this 
   # value which is saved in $dbData{'Kid'} and used with the subsequent 
   # Keywords insert. The facilitates data JOIN that is used with SELECT 
   # database queries.
   foreach my $jKey (sort {$a <=> $b} keys(%$jsonRef)) {
      next if ($jKey eq '0');   # Don't import preset 0;
      $dbData{'Lid'} = 'NULL';
      $dbData{'Pid'} = $jKey;
      $dbData{'Pname'} = $jsonRef->{$jKey}{'n'};
      $dbData{'Qll'} = $jsonRef->{$jKey}{'ql'};  
      $dbData{'Type'} = 'preset';
      $dbData{'Type'} = 'playlist' if (exists($jsonRef->{$jKey}{'playlist'}));  
      $dbData{'Src'} = $srcFile;
      $dbData{'Date'} = $insertTime;
      if (exists( $main::cliOpts{r} )) {    # Don't reformat preset.
         my $pid = join('', '"', $jKey, '"');
         $dbData{'Pdata'} = join(':', $pid, JSON->new->encode($jsonRef->{$jKey}));
      }
      else {
         $dbData{'Pdata'} = &FormatPreset($jsonRef->{$jKey}, $jKey);
      }
      return 1 if ($dbData{'Pdata'} eq '');

      # Debug mode show pre-insert data.
      foreach my $fld (@presetFields) {
         &DisplayDebug("$fld: $dbData{$fld}");     
      }
      
      # If enabled, check for possible duplicate preset, query the presets.pdata 
      # column with the segments portion of this preset.
      unless (exists( $main::cliOpts{p} )) {      
         if ($dbData{'Type'} eq 'preset') {
            # All segment data.
            if ($dbData{'Pdata'} =~ m/("seg":\[.+\])/ms) {
               $tstData = $1;
            }
            # Everything but pid
            else {
               $tstData = substr($dbData{'Pdata'}, index($dbData{'Pdata'}, ':'));
            }
         }
         else {
            # Everything "playlist": to the end.
            $tstData = substr($dbData{'Pdata'}, index($dbData{'Pdata'}, '"playlist":'));
         }
         my @dupArray; 
         my @cols = ('Lid', 'Type','Pid','Pname','Date','Src');
         my $query = "SELECT " . join(',', @cols) . " FROM Presets " .
                     "WHERE Pdata LIKE '%$tstData%';";
         return 1 if (&SelectDbArray($Dbh, $query, \@dupArray));
         if ($#dupArray >= 0) {
            my $action = &ImportDuplicate($Dbh, $Parsed, \%dbData, \@dupArray,
                         \@cols, \%newId, \%newPlist);
            return 1 if ($action == 1);
            next if ($action == 2);
            $lastPid = $dbData{'Pid'};  # Suppress newline before success message below.  
         }
      }
      # Perform the Presets table insert. Save the returned value for Kid.
      $dbData{'Kid'} = &InsertDbData($Dbh, 'Presets', \%dbData, \@presetFields);
      return 1 if ($dbData{'Kid'} == -1);
      # Save this Lid in case we need it later to update playlist presets.
      $lidSave{ $dbData{'Pid'} } = $dbData{'Kid'} if ($dbData{'Type'} =~ /playlist/);
      
      foreach my $fld (@keywordFields) {
         &DisplayDebug("$fld: $dbData{$fld}");  # Show pre-insert data.
      }
      # Perform the Keywords table insert.
      return 1 if (&InsertDbData($Dbh, 'Keywords', \%dbData, \@keywordFields) == -1);
      print "\n" if ($lastPid eq '');
      &ColorMessage("   Successful import - $dbData{'Type'} $dbData{'Pid'}.", "YELLOW", ''); 
      $lastPid = $dbData{'Pid'};   
      
      # Perform Palette table processing. Check all segments for custom palette entries;
      # range 247-256. If importing direct wled, get the palette data. Otherwise, read 
      # the appropriate local file. If neither source is available, insert with no Pldata
      # and display a user message. Lid value links record(s) with preset.
      foreach my $segref (@{ $jsonRef->{$jKey}{'seg'} }) {     # Process each segment.
         if ($segref->{'pal'} >= 247 and $segref->{'pal'} <= 256) {
            $dbData{'Plnum'} = $segref->{'pal'};
            $dbData{'Palid'} = 'NULL';                 # Unique DB generated value.
            $dbData{'Plid'} = $dbData{'Kid'};          # New preset record Lid value.
            unless (%palData) {                        # Load palettes if empty hash.
               return 1 if (&LoadPalettes($Parsed, \%palData));
            } 
            if (exists($palData{ $dbData{'Plnum'} })) {
               $dbData{'Pldata'} = $palData{ $dbData{'Plnum'} };
            }
            else {
               $dbData{'Pldata'} = '';
               &ColorMessage("   No palette data entry $dbData{'Plnum'}.", "YELLOW", ''); 
            }
            # Insert the palette record if not already present for this Lid.
            if ($dbData{'Pldata'} ne '') {
               my @check = ();
               my $query = "SELECT Palid FROM Palettes WHERE Plid = $dbData{'Plid'};";
               return 1 if (&SelectDbArray($Dbh, $query, \@check));
               if ($#check < 0) {
                  return 1 if (&InsertDbData($Dbh, 'Palettes', \%dbData, \@paletteFields) == -1);
               }
            }
         }
      }
      # Perform ledmap table processing. Check for ledmap entry; ledmap:x (0-9). If
      # importing direct wled, get the ledmap data. Otherwise, read the appropriate
      # local file. If neither source is available, insert with no Mdata and display
      # a user message. Lid value links record(s) with preset.
      if (exists($jsonRef->{$jKey}{'ledmap'})) {
         $dbData{'Mnum'} = $jsonRef->{$jKey}{'ledmap'};
         $dbData{'Mapid'} = 'NULL';                 # Unique DB generated value.
         $dbData{'Mlid'} = $dbData{'Kid'};          # New preset record Lid value.
         unless (%mapData) {                        # Load palettes if empty hash.
            return 1 if (&LoadLedmaps($Parsed, \%mapData));
         } 
         if (exists($mapData{ $dbData{'Mnum'} })) {
            $dbData{'Mdata'} = $mapData{ $dbData{'Mnum'} };
         }
         else {
            $dbData{'Mdata'} = '';
            &ColorMessage("   No ledmap data entry $dbData{'Mnum'}.", "YELLOW", ''); 
         }
         # Insert the ledmap record if not already present for this Lid.
         if ($dbData{'Mdata'} ne '') {
            my @check = ();
            my $query = "SELECT Mapid FROM Ledmaps WHERE Mlid = $dbData{'Mlid'};";
            return 1 if (&SelectDbArray($Dbh, $query, \@check));
            if ($#check < 0) {
               return 1 if (&InsertDbData($Dbh, 'Ledmaps', \%dbData, \@ledmapFields) == -1);
            }
         }
      }
   }

   # All imports complete. If 'new' option used, update any imported playlist(s)
   # with the new preset ids if it contains an old preset id.  "ps":[13,14,15]
   foreach my $key (keys(%newPlist)) {
      if ($newPlist{$key} =~ m/"ps":[\[]*([0-9,]+)[\]]*/) {
         my $oldIds = $1;
         my @oldList = split(',', $oldIds);
         my @newList = ();
         for (my $x = 0; $x <= $#oldList; $x++) {
            my $id = $oldList[$x];
            # Keep old id unless it was changed; in newId.
            $id = $newId{ $oldList[$x] } if (exists($newId{ $oldList[$x] }));
            push (@newList, $id);
         }
         my $newIds = join(',', @newList);
         
         # Update this preset if playlists don't match.
         if ($newIds ne $oldIds) {   
            $newPlist{$key} =~ s/"ps":[\[]*$oldIds[\]]*/"ps":\[$newIds\]/;
            $dbData{'Pdata'} = $newPlist{$key};
            $dbData{'Lid'} = $lidSave{$key};
            my @pFlds = ('Pdata');
            &UpdateDbData($Dbh, 'Presets', \%dbData,, \@pFlds);
         }
      } 
   }
   return 0;
}

# =============================================================================
# FUNCTION:  ExportPresets
#
# DESCRIPTION:
#    This routine exports the $LidList specified preset data to a file or 
#    directly to WLED via its WIFI IP.
#
# CALLING SYNTAX:
#    $result = &ExportPresets($Dbh, $Parsed, $LidList);
#
# ARGUMENTS:
#    $Dbh          Database object reference.
#    $Parsed       Pointer to parsed data hash.
#    $LidList      Comma separated list of Lids.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub ExportPresets {
   my($Dbh, $Parsed, $LidList) = @_;
   my(@pdata, $pcntStr, @pldata, %palHash, @mdata, %mapHash);

   &DisplayDebug("ExportPresets ...  LidList: $LidList");
   &DisplayDebug("'$$Parsed{'file1'}'  '$$Parsed{'wled1'}'");

   if ($$Parsed{'file1'} eq '' and $$Parsed{'wled1'} eq '') {
      &ColorMessage("   Export file or wled not specified.","YELLOW",'');
      return 1;
   }
   
   # Get the pdata for the specified presets.
   my $query = "SELECT Pdata FROM Presets WHERE Lid IN ($LidList);";
   return 1 if (&SelectDbArray($Dbh, $query, \@pdata));
   
   $pcntStr = '   Exported ' . scalar @pdata . ' presets';
   $pcntStr =~ s/s$// if (scalar @pdata == 1);
   # Add preset 0 and JSON closure. 
   unshift (@pdata, '{"0":{}');
   for (my $x = 0; $x < $#pdata; $x++) {      # all but last entry.
      $pdata[$x] = join('', $pdata[$x], ",");
   }
   push (@pdata, '}');
   &DisplayDebug("Pdata: '@pdata'");
   # Validate the JSON and send the pdata.
   return 1 if (&ValidateJson(\@pdata, '', '', ''));
   
   # Get associated custom palettes.
   my $query = "SELECT Plnum,Pldata FROM Palettes WHERE Plid IN ($LidList);";
   return 1 if (&SelectDbArray($Dbh, $query, \@pldata));
   foreach my $rec (@pldata) {
      my @data = split('\|', $rec);
      my $name = join('', 'palette', abs($data[0] - 256), '.json');
      $palHash{$name} = $data[1];
   }
   # Get associated ledmaps.
   $query = "SELECT Mnum,Mdata FROM Ledmaps WHERE Mlid IN ($LidList);";
   return 1 if (&SelectDbArray($Dbh, $query, \@mdata));
   foreach my $rec (@mdata) {
      my @data = split('\|', $rec);
      my $name = join('', 'ledmap', $data[0], '.json');
      $mapHash{$name} = $data[1];
   }
   &ColorMessage('', "WHITE", '');
   
   # Export to file.
   if (exists($$Parsed{'file1'})) {
      &DisplayDebug("ExportPresets file: $$Parsed{'file1'}");
      if (-e $$Parsed{'file1'}) {
         my $resp = &PromptUser("Overwrite existing file $$Parsed{'file1'}" .
                                "? [y/N] -> ",'BRIGHT_YELLOW');
         unless ($resp =~ m/y/i) {
            &ColorMessage("   Export aborted.","YELLOW", '');
            return 1;
         }
         &ColorMessage('', "WHITE", '');
      }
      return 1 if (&WriteFile($$Parsed{'file1'}, \@pdata, ''));
      my $srcPath = '';
      if ($$Parsed{'file1'} =~ m#/#) {
         $srcPath = substr($$Parsed{'file1'}, 0, rindex($$Parsed{'file1'}, '/'));
      }
      foreach my $file (sort keys(%palHash)) {
         my @array = ("$palHash{$file}");
         return 1 if (&ValidateJson(\@array, '', '', '')); # Validate the JSON.
         $file = join('/', $srcPath, $file) if ($srcPath ne '');
         return 1 if (&WriteFile($file, \@array, ''));
         &ColorMessage("   Palette file created: $file","YELLOW", '');
      }
      foreach my $file (sort keys(%mapHash)) {
         my @array = ("$mapHash{$file}");
         return 1 if (&ValidateJson(\@array, '', '', '')); # Validate the JSON.
         $file = join('/', $srcPath, $file) if ($srcPath ne '');
         return 1 if (&WriteFile($file, \@array, ''));
         &ColorMessage("   Ledmap file created: $file","YELLOW", '');
      }
      &ColorMessage("$pcntStr to $$Parsed{'file1'}","YELLOW", '');
   }
   
   # Export to wled.
   if (exists($$Parsed{'wled1'})) {
      my $dirPath = &GetTmpDir();
      return 1 if ($dirPath eq '');
      my $file = join('/', $dirPath, 'presets.json');
      return 1 if (&WriteFile($file, \@pdata, ''));
      my $ip = $1 if ($$Parsed{'wled1'} =~ m/wled:(.+)/);
      my $wledUrl = "http://$ip";
      return 1 if (&PostUrl(join('/', $wledUrl, 'upload'), $file));
      unlink $file;
      foreach my $name (sort keys(%palHash)) {
         my $file = join('/', $dirPath, $name);
         my @array = ("$palHash{$name}");
         return 1 if (&ValidateJson(\@array, '', '', '')); # Validate the JSON.
         return 1 if (&WriteFile($file, \@array, ''));
         return 1 if (&PostUrl(join('/', $wledUrl, 'upload'), $file));
         &ColorMessage("   Sent palette to WLED: $name","YELLOW", '');
         unlink $file;
      }
      foreach my $name (sort keys(%mapHash)) {
         my $file = join('/', $dirPath, $name);
         my @array = ("$mapHash{$name}");
         return 1 if (&ValidateJson(\@array, '', '', '')); # Validate the JSON.
         return 1 if (&WriteFile($file, \@array, ''));
         return 1 if (&PostUrl(join('/', $wledUrl, 'upload'), $file));
         &ColorMessage("   Sent ledmap to WLED: $name","YELLOW", '');
         unlink $file;
      }
      &ColorMessage("$pcntStr to WLED.","YELLOW", '');
      
      # Perform WLED reset to activate the uploaded presets.
      &WledReset($ip);
      &ColorMessage("   WLED reset. Wait ~15 sec for network reconnect.",
                    "YELLOW", '');
   }
   return 0;
}

# =============================================================================
# FUNCTION:  AddTagGroup
#
# DESCRIPTION:
#    This routine adds the user specified tag/group words. $LidList points
#    to an array of keyword table ids created by the Show command. The words
#    to be added are specified by $Parsed{'tag1'} and $Parsed{'group1'}.
#
# CALLING SYNTAX:
#    $result = &AddTagGroup($Dbh, $Parsed, $LidList);
#
# ARGUMENTS:
#    $Dbh          Database object reference.
#    $Parsed       Pointer to parsed data hash.
#    $LidList      Comma separated list of Lids.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub AddTagGroup {
   my($Dbh, $Parsed, $LidList) = @_;
   my(@fields) = ('Kid','Tag','Group');
   my(@array, @words, @temp);   my(%newData);

   &DisplayDebug("AddTagGroup ...  LidList: $LidList");
   my $query = "SELECT Kid,Tag,Group from Keywords WHERE Kid IN ($LidList);";
   return 1 if (&SelectDbArray($Dbh, $query, \@array));
  
   # Change record data and update.
   foreach my $rec (@array) {
      my @data = split('\|', $rec);  # split on |. \| escapes 'or' meaning.
      if (exists($$Parsed{'tag1'})) {
         @words = split(',', $$Parsed{'tag1'});  # Might be multiple words.
         foreach my $word (@words) {
            unless ($data[1] =~ m/$word/) {      # Skip if word present.
               @temp = split(',', $data[1]);
               push (@temp, $word);
               $data[1] = join(',', sort @temp);
            }
         }
      }
      if (exists($$Parsed{'group1'})) {
         @words = split(',', $$Parsed{'group1'});  # Might be multiple words.
         foreach my $word (@words) {
            unless ($data[2] =~ m/$word/) {      # Skip if word present.
               @temp = split(',', $data[2]);
               push (@temp, $word);
               $data[2] = join(',', sort @temp);
            }
         }
      }
      # Skip update if no changes.
      my $check = join('|', @data);
      if ($check ne $rec) {
         $newData{'Kid'} = $data[0];
         $newData{'Tag'} = $data[1];
         $newData{'Group'} = $data[2];
         return 1 if (&UpdateDbData($Dbh, 'Keywords', \%newData, \@fields));
      }
   }
   &ColorMessage("   Tag/Group keyword(s) added.","YELLOW", '');
   return 0;
}

# =============================================================================
# FUNCTION:  RemoveTagGroup
#
# DESCRIPTION:
#    This routine removes the user specified tag/group words. $LidList points
#    to an array of keyword table ids created by the Show command. The words
#    to be removed are specified by $Parsed{'tag1'} and $Parsed{'group1'}.
#
# CALLING SYNTAX:
#    $result = &RemoveTagGroup($Dbh, $Parsed, $LidList);
#
# ARGUMENTS:
#    $Dbh          Database object reference.
#    $Parsed       Pointer to parsed data hash.
#    $LidList      Comma separated list of Lids.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub RemoveTagGroup {
   my($Dbh, $Parsed, $LidList) = @_;
   my(@fields) = ('Kid','Tag','Group');
   my(@array, @words);   my(%newData);

   &DisplayDebug("RemoveTagGroup ...  LidList: $LidList");
   my $query = "SELECT Kid,Tag,Group from Keywords WHERE Kid IN ($LidList);";
   return 1 if (&SelectDbArray($Dbh, $query, \@array));
  
   # Change record data and update.
   foreach my $rec (@array) {
      my @data = split('\|', $rec);  # split on |. \| escapes 'or' meaning.
      if (exists($$Parsed{'tag1'})) {
         @words = split(',', $$Parsed{'tag1'});  # Might be multiple words.
         foreach my $word (@words) {
            $data[1] =~ s/$word//;
         }
         $data[1] =~ s/,,/,/g;                # Remove extraneous commas.
         $data[1] =~ s/^,//;
         @words = split(',', $data[1]);       # Sort remaining words.
         $data[1] = join(',', sort @words);
      }
      if (exists($$Parsed{'group1'})) {
         @words = split(',', $$Parsed{'group1'}); # Might be multiple words.
         foreach my $word (@words) {
            $data[2] =~ s/$word//;
         }
         $data[2] =~ s/,,/,/g;                # Remove extraneous commas.
         $data[2] =~ s/^,//;
         @words = split(',', $data[2]);
         $data[2] = join(',', sort @words);
      }
      # Skip update if no changes.
      my $check = join('|', @data);
      if ($check ne $rec) {
         $newData{'Kid'} = $data[0];
         $newData{'Tag'} = $data[1];
         $newData{'Group'} = $data[2];
         return 1 if (&UpdateDbData($Dbh, 'Keywords', \%newData, \@fields));
      }
   }
   &ColorMessage("   Tag/Group keyword(s) removed.","YELLOW", '');
   return 0;
}

# =============================================================================
# FUNCTION:  GetLidList
#
# DESCRIPTION:
#    This routine extracts the lid column from the specified records and returns
#    them in a scalar comma separated.
#
# CALLING SYNTAX:
#    $lids = &GetLidList(\@DbData, \@Fields);
#
# ARGUMENTS:
#    $DbData        Pointer to records to process.
#    $Fields        Corresponding column names.
#
# RETURNED VALUES:
#    Comma separated lid values or '' if none found.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub GetLidList {
   my($DbData, $Fields) = @_;

   my @list = ();  
   foreach my $rec (@$DbData) {
      my @data = split('\|', $rec);  # split on |. \| escapes 'or' meaning.
      for (my $x = 0; $x <= $#$Fields; $x++) {
         push (@list, $data[$x]) if ($$Fields[$x] =~ m/^Lid$/i);
      }
   }
   my $lids = join(',', @list);
   &DisplayDebug("GetLidList lids: '$lids'");
   return $lids;
}

# =============================================================================
# FUNCTION:  DisplayPresets
#
# DESCRIPTION:
#    This routine is called to display the specified preset data to the user.
#    Data is tabular formatted.
#
# CALLING SYNTAX:
#    $result = &DisplayPresets($Dbh, $Parsed, \@Pdata);
#
# ARGUMENTS:
#    $Dbh          Database object reference.
#    $Parsed       Pointer to parsed data hash.
#    $Pdata        Pointer to preset data array.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub DisplayPresets {
   my($Dbh, $Parsed, $Pdata) = @_;
   my @cols = ('Type','Pid','Pname','Qll','Date','Lid','Tag','Group');
   my @cwid = (6,3,11,4,19,4,3,5);  # Default column widths
   my ($name, $sep, $col, @src);
   
   # Return if no data to process.
   if ($#$Pdata < 0) {
      &ColorMessage("   No presets to display.","YELLOW", '');
      return 1;
   }
   # Show the Src column if user specified.
   if (exists($$Parsed{'src0'})) {
      push (@cols, 'Src');  
      push (@cwid, 4);  
   }
   
   # First pass scan for max column widths.
   foreach my $rec (@$Pdata) {
      my @data = split('\|', $rec);  # split on |. \| escapes 'or' meaning.
      for (my $x = 0; $x <= $#cols; $x++) {
         $cwid[$x] = length($data[$x]) if (length($data[$x]) > $cwid[$x]);
      }
   }
   # Print column formatted results.
   # ----- Title line.
   &ColorMessage('', "WHITE", '');
   for (my $x = 0; $x <= $#cols; $x++) {
      printf("%-$cwid[$x]s   ", $cols[$x]);
   }
   &ColorMessage('', "WHITE", '');
   # ----- Separator line.
   for (my $x = 0; $x <= $#cols; $x++) {
      $sep = '-' x $cwid[$x];
      printf("%-$cwid[$x]s   ", $sep);
   }   
   &ColorMessage('', "WHITE", '');
   # ----- Data line, Pdata, and pal if specified.
   my @pdata = ();   my @pldata = ();   my (@mdata) = ();
   foreach my $rec (@$Pdata) {
      my $lid = 0;
      my @data = split('\|', $rec);  # split on |. \| escapes 'or' meaning.
      for (my $x = 0; $x <= $#cols; $x++) {
         $col = sprintf("%-$cwid[$x]s   ", $data[$x]);
         $lid = $data[$x] if ($cols[$x] =~ m/^Lid$/i); # Lid of record.
         print $col;
      }
      &ColorMessage('', "WHITE", '');
      # Get and display preset Pdata if specified by user.
      if (exists($$Parsed{'pdata0'}) and $lid != 0) {
         my $query = "SELECT Pdata FROM Presets WHERE Lid = $lid;";
         unless (&SelectDbArray($Dbh, $query, \@pdata)) {
            &ColorMessage("$pdata[0]", 'CYAN', '');
         }
      }
      # Get and display palette data if specified by user.
      if (exists($$Parsed{'pal0'}) and $lid != 0) {
         my $query = "SELECT Plnum,Pldata FROM Palettes WHERE Plid = $lid;";
         unless (&SelectDbArray($Dbh, $query, \@pldata)) {
            if ($#pldata >= 0) {
               &ColorMessage('', "WHITE", '') if ($#pdata >= 0);
               foreach my $rec (@pldata) {
                  my @data = split('\|', $rec);
                  my $name = join('', 'palette', abs($data[0] - 256));
                  &ColorMessage("$name  $data[0]  $data[1]", 'CYAN', '');
               }
            }
         }
      }
      # Get and display ledmap data if specified by user.
      if (exists($$Parsed{'map0'}) and $lid != 0) {
         my $query = "SELECT Mnum,Mdata FROM Ledmaps WHERE Mlid = $lid;";
         unless (&SelectDbArray($Dbh, $query, \@mdata)) {
            if ($#mdata >= 0) {
               &ColorMessage('', "WHITE", '') if ($#pdata >= 0 or $#pldata >= 0);
               foreach my $rec (@mdata) {
                  my @data = split('\|', $rec);
                  my $name = join('', 'ledmap', $data[0]);
                  &ColorMessage("$name  $data[1]", 'CYAN', '');
               }
            }
         }
      }
   }
   &ColorMessage('', "WHITE", '');
   return 0;
}

# =============================================================================
# FUNCTION:  ShowOnWled
#
# DESCRIPTION:
#    This routine is called to send the specified preset data to a WIFI 
#    connected WLED instance.
#
# CALLING SYNTAX:
#    $result = &ShowOnWled($Dbh, $Parsed, \@Pdata);
#
# ARGUMENTS:
#    $Dbh          Database object reference.
#    $Parsed       Pointer to parsed data hash.
#    $Pdata        Pointer to preset data array.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub ShowOnWled {
   my($Dbh, $Parsed, $Pdata) = @_;
   my(@data);
   
   return 1 if ($#$Pdata < 0);  # Nothing to do.
   my $ip = $1 if ($$Parsed{'wled0'} =~ m/wled:(.+)/);
   my $url = "http://$ip/json/state";
   return &PostIt($$Pdata[0], $url);
      
   # ----------
   # Post preset string to WLED.
   sub PostIt {
      my($Record, $Url) = @_;

      my @temp = split('\|', $Record);  # Lid is 5th column of record
      my $query = "SELECT Pdata FROM Presets WHERE Lid = $temp[5];";
      return 1 if (&SelectDbArray($Dbh, $query, \@data));
      my $json = $data[0];
      if ($json =~ m/"playlist":/) {   # Just playlist data pairs.
         $json = substr($json, index($json, '"playlist"'));
         return 1 if(&PostJson($Url, '{"on":true}'));  # Leds on.
      }
      elsif ($json =~ m/"seg":/) {     # Just segment data pairs. 
         $json = substr($json, index($json, '"seg"'));
         return 1 if(&PostJson($Url, '{"on":true}'));  # Leds on.
      }
      else {
         $json =~ s/^"\d+":\{//;       # Remove preset id container. 
         $json =~ s/\}$//;
      }
      return 1 if(&PostJson($Url, "{$json}"));  # Send preset json.
      return 0;
   }
}

# =============================================================================
# FUNCTION:  ShowPresets
#
# DESCRIPTION:
#    This routine shows database content based on the supplied $Parsed data.
#    It also launches a second command, if user specified, to process the
#    SHOW selected records. 
#
# CALLING SYNTAX:
#    $result = &ShowPresets($Dbh, $Parsed);
#
# ARGUMENTS:
#    $Dbh          Database object reference.
#    $Parsed       Pointer to parsed data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub ShowPresets {
   my($Dbh, $Parsed) = @_;
   
   &DisplayDebug("ShowPresets ...");
   
   # Incorporate user specified selection data into the WHERE clause.
   my $where = 'WHERE';
   my @valid = ('type','pid','pname','qll','date','lid','tag','group');

   my $filter;
   foreach my $key (@valid) {
      if (exists($$Parsed{"${key}0"})) {
         my $value = $$Parsed{"${key}0"};
         my $table = 'Presets';
         $table = 'Keywords' if ($key eq 'tag' or $key eq 'group');
         $where = join(' ', $where, 'AND') unless ($where =~ m/^WHERE$/);
         if ($key eq 'pid' or $key eq 'lid') {
            if ($value =~ m/,/) {
               $filter = join('', "$table.$key IN (", $value,")");
            }
            else {
               $filter = join('', "$table.$key = ", $value);
            }
         }
         elsif ($key eq 'tag' or $key eq 'group') {
            if ($value =~ m/,/) {
               my @words = split(',', $value);
               my @temp = ();
               for (my $x = 0; $x <= $#words; $x++) {
                  push(@temp, join('', "$table.$key LIKE '%", $words[$x],"%'"));
                  push (@temp, "OR") if ($x < $#words);
               }
               $filter = join(' ', @temp);
            }
            else {
               $filter = join('', "$table.$key LIKE '%", $value,"%'");
            }
         }
         else {
            $filter = join('', "$table.$key LIKE '%", $value,"%'");
         } 
         $where = join(' ', $where, $filter);
      }
   }
   $where = '' if ($where eq 'WHERE');  # If no valid filters specified.
   push (@valid, 'Src') if (exists($$Parsed{'src0'}));  # Add src column.
   
   # Perform the database query to get the user specified records. Extract a list
   # of the database lid values. If specified, perform second command using the 
   # lid values. Display the query results.
   my $query = join(' ', "SELECT", join(',', @valid), 
      "FROM Presets LEFT JOIN Keywords ON Presets.Lid = Keywords.Kid",
      $where, "ORDER BY $$Parsed{'sort'};");
   my @array;   my @lidList;
   return 1 if (&SelectDbArray($Dbh, $query, \@array));

   # Perform secondary command if specified.
   if (exists($$Parsed{'cmd1'})) {
      if ($#array >= 0) {
         my $lids = &GetLidList(\@array, \@valid);
         if ($$Parsed{'cmd1'} eq 'remove') {
            return 1 if (&RemoveTagGroup($Dbh, $Parsed, $lids));
         }
         elsif ($$Parsed{'cmd1'} eq 'add') {
            return 1 if (&AddTagGroup($Dbh, $Parsed, $lids));
         }
         elsif ($$Parsed{'cmd1'} eq 'export') {
            return 1 if (&ExportPresets($Dbh, $Parsed, $lids));
         }
         # Display 2nd command results.
         my $query = join(' ', "SELECT", join(',', @valid), 
            "FROM Presets LEFT JOIN Keywords ON Presets.Lid = Keywords.Kid",
            "WHERE Presets.Lid IN ($lids) ORDER BY $$Parsed{'sort'};");
         return 1 if (&SelectDbArray($Dbh, $query, \@array));
      }
      else {
         &ColorMessage("   No preset data to process.","YELLOW", '');
         return 0;
      }
   }
   
   # Display results.
   print "\n" unless (exists($$Parsed{'cmd1'}));
   return 1 if (&DisplayPresets($Dbh, $Parsed, \@array));
   
   # Send send preset data to WLED if specified.
   if (exists($$Parsed{'wled0'})) {
      return 1 if (&ShowOnWled($Dbh, $Parsed, \@array));
   }
   return 0;
}

# =============================================================================
# FUNCTION:  DeletePresets
#
# DESCRIPTION:
#    This routine deletes database content based on the supplied $Parsed data.
#
# CALLING SYNTAX:
#    $result = &DeletePresets($Dbh, $Parsed);
#
# ARGUMENTS:
#    $Dbh          Database object reference.
#    $Parsed       Pointer to parsed data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub DeletePresets {
   my($Dbh, $Parsed) = @_;
   my @array = ();   my @cwid = ();   my @lidList = ();
   
   &DisplayDebug("DeletePresets ...");
   
   # Create WHERE clause with user specified filter(s).
   my $where = 'WHERE';
   my @valid = ('type','pid','pname','qll','date','lid','tag','group');
   my $filter;
   foreach my $key (@valid) {
      if (exists($$Parsed{"${key}0"})) {
         my $value = $$Parsed{"${key}0"};
         my $table = 'Presets';
         $table = 'Keywords' if ($key eq 'tag' or $key eq 'group');
         $where = join(' ', $where, 'AND') unless ($where =~ m/^WHERE$/);
         if ($key eq 'pid' or $key eq 'lid') {
            if ($value =~ m/,/) {
               $filter = join('', "$table.$key IN (", $value,")");
            }
            else {
               $filter = join('', "$table.$key = ", $value);
            }
         }
         elsif ($key eq 'tag' or $key eq 'group') {
            if ($value =~ m/,/) {
               my @words = split(',', $value);
               my @temp = ();
               for (my $x = 0; $x <= $#words; $x++) {
                  push(@temp, join('', "$table.$key LIKE '%", $words[$x],"%'"));
                  push (@temp, "OR") if ($x < $#words);
               }
               $filter = join(' ', @temp);
            }
            else {
               $filter = join('', "$table.$key LIKE '%", $value,"%'");
            }
         }
         else {
            $filter = join('', "$table.$key LIKE '%", $value,"%'");
         } 
         $where = join(' ', $where, $filter);
      }
   }
   if ($where eq 'WHERE') {
      &ColorMessage("   No filter specified.", "YELLOW", '');
      return 1;
   }

   # Show user the records to be deleted.
   my $query = join(' ', "SELECT", join(',', @valid), 
      "FROM Presets LEFT JOIN Keywords ON Presets.Lid = Keywords.Kid",
      $where, "ORDER BY Lid;");
   unless (&SelectDbArray($Dbh, $query, \@array)) {
      &ColorMessage('', "WHITE", '');
      return 1 if (&DisplayPresets($Dbh, $Parsed, \@array));
      my $lids = &GetLidList(\@array, \@valid);
      &DisplayDebug("ShowPresets lids: 'lids'");

      my $prompt = "Delete this preset? y/N -> ";
      $prompt = "Delete these presets? y/N -> " if ($#array > 0);
      my $resp = &PromptUser($prompt,'BRIGHT_YELLOW');
      unless ($resp =~ m/^Y[es]*$/i) {
         &ColorMessage("   Delete aborted.", 'YELLOW', '');
         return 0;
      }
      # Delete the presets and associated keywords.
      my $delCnt = 0;
      my @lidList = split(',', $lids);
      foreach my $lid (@lidList) {
         if (&DeleteDbData($Dbh, 'Presets', $lid) == 0) {
            &DeleteDbData($Dbh, 'Keywords', $lid);
            &DeleteDbData($Dbh, 'Palettes', $lid);
            &DeleteDbData($Dbh, 'Ledmaps', $lid);
            $delCnt++;
         }
      }
      &ColorMessage("   $delCnt presets deleted.", 'YELLOW', '');
   }
   return 0;
}

# =============================================================================
# FUNCTION:  EditPresets
#
# DESCRIPTION:
#    This routine is used to edit database content based on the supplied 
#    $Parsed data. A single lid value is required.
#
# CALLING SYNTAX:
#    $result = &EditPresets($Dbh, $Parsed);
#
# ARGUMENTS:
#    $Dbh          Database object reference.
#    $Parsed       Pointer to parsed data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub EditPresets {
   my($Dbh, $Parsed) = @_;
   my @columns = ('type','pid','pname','qll','date','lid','tag','group');
   my @options = ('Pid','Pname','Qll','Src');
   my(@dbCols) = ();   my(%values) = ();
   my($opt);   my(@array);

   if (exists($$Parsed{'lid0'})) {
      $values{'Lid'} = $$Parsed{'lid0'};
      push (@columns, 'src') if (exists($$Parsed{'src0'}));  # Add src column.
      
      # See if record is in the database.
      my $query = "SELECT Lid FROM Presets WHERE Presets.Lid = $values{'Lid'};";
      return 1 if (&SelectDbArray($Dbh, $query, \@array));
      unless ($#array == 0) {
         &ColorMessage("   Lid $values{'Lid'} not found.", 'YELLOW', '');
         return 1;
      }
      # Process user specified values.
      foreach my $col (@options) {
         $opt = join('', lc($col), '0');
         if (exists($$Parsed{$opt})) {
            push (@dbCols, $col);
            $values{$col} = $$Parsed{$opt}; 
         }
      }
      if ($#dbCols >= 0) {
         return 1 if (&UpdateDbData($Dbh, 'Presets', \%values, \@dbCols));
         if ($#dbCols > 0) {
            &ColorMessage("   Values changed.","YELLOW", '');
         }
         else {
            &ColorMessage("   Value changed.","YELLOW", '');
         }
         # Show updated record.
         my $query = join(' ', "SELECT", join(',', @columns), 
            "FROM Presets LEFT JOIN Keywords ON Presets.Lid = Keywords.Kid " .
            "WHERE Presets.Lid = $values{'Lid'};");
         return 1 if (&SelectDbArray($Dbh, $query, \@array));
         return 1 if (&DisplayPresets($Dbh, $Parsed, \@array));
      }
      else {
         &ColorMessage("   Nothing to change.", 'YELLOW', '');
         return 1;
      }
   }
   else {
      &ColorMessage("   Required lid:<i> not specified.", 'YELLOW', '');
      return 1;
   }
   return 0;
}

# =============================================================================
# FUNCTION:  DuplPreset
#
# DESCRIPTION:
#    This routine is used to duplicate the lid specified. Optional parameters
#    are used to overite the replicated preset values. A single lid value is
#    required.
#
# CALLING SYNTAX:
#    $result = &DuplPreset($Dbh, $Parsed);
#
# ARGUMENTS:
#    $Dbh          Database object reference.
#    $Parsed       Pointer to parsed data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None
# =============================================================================
sub DuplPreset {
   my($Dbh, $Parsed) = @_;
   my @columns = ('type','pid','pname','qll','date','lid','tag','group');
   my(@dbCols) = ();   my(%repData) = ();
   my(@array, $key);

   if (exists($$Parsed{'lid0'})) {
      # Get the Presets table column names. Returns a comma separated list.
      $query = "SELECT GROUP_CONCAT(NAME,',') FROM PRAGMA_TABLE_INFO('Presets');";
      return 1 if (&SelectDbArray($Dbh, $query, \@array));
      @dbCols = split(',', $array[0]);
      
      # See if record is in the database.
      my $query = "SELECT " . join(',', @dbCols) . " FROM Presets WHERE " .
                  "Presets.Lid = $$Parsed{'lid0'};";
      return 1 if (&SelectDbArray($Dbh, $query, \@array));
      unless ($#array == 0) {
         &ColorMessage("   Lid $$Parsed{'lid0'} not found.", 'YELLOW', '');
         return 1;
      }
      # Load the data to be replicated into the insert hash. If there is a
      # user specified value for the column, use it. Src and Date columns
      # are also updated.
      my @data = split('\|', $array[0]);
      for (my $x = 0; $x <= $#dbCols; $x++) {
         if ($dbCols[$x] eq 'Lid') {
            $repData{'Lid'} = 'NULL';
            next;
         }
         $repData{$dbCols[$x]} = $data[$x];
         if ($dbCols[$x] eq 'Src') {
            $repData{$dbCols[$x]} = "Dupl of lid $$Parsed{'lid0'}";
         }
         elsif ($dbCols[$x] eq 'Date') {
            $repData{$dbCols[$x]} = &DateTime('-', ':', '_');
         }
         else {
            $key = join('', lc($dbCols[$x]), '0');
            if (exists($$Parsed{$key})) {
               $repData{$dbCols[$x]} = $$Parsed{$key};
            }
         }
      }
      
      # Prepare Keywords table data if user specified.
      $repData{'Tag'} = '';
      $repData{'Tag'} = $$Parsed{'tag0'} if (exists($$Parsed{'tag0'}));
      $repData{'Group'} = '';
      $repData{'Group'} = $$Parsed{'group0'} if (exists($$Parsed{'group0'}));
      # Debug pre-insert data.
      &DisplayDebug("\n");
      foreach my $key (sort keys(%repData)) {
         &DisplayDebug("DuplPreset $key: '$repData{$key}'");
      }
      
      # Perform the Presets table insert.
      $repData{'Kid'} = &InsertDbData($Dbh, 'Presets', \%repData, \@dbCols);
      return 1 if ($repData{'Kid'} == -1);
      # Perform the Keywords table insert.
      my @keywordCols = ('Kid','Tag','Group');
      return 1 if (&InsertDbData($Dbh, 'Keywords', \%repData, \@keywordCols) == -1);
      &ColorMessage("   Lid $repData{'Kid'} created.", 'YELLOW', '');
      # Check for associated palatte entries and duplicate them too.
      my $query = "SELECT Plnum,Pldata FROM Palettes WHERE Plid = $$Parsed{'lid0'};";
      my @paldata = ();
      unless (&SelectDbArray($Dbh, $query, \@paldata)) {
         my @paletteCols = ('Palid','Plid','Plnum','Pldata');
         foreach my $rec (@paldata) {
            my @data = split('\|', $rec);
            $repData{'Palid'} = 'NULL';     # Unique DB generated value.
            $repData{'Plid'} = $repData{'Kid'};
            $repData{'Plnum'} = $data[0];
            $repData{'Pldata'} = $data[1];
            return 1 if (&InsertDbData($Dbh, 'Palettes', \%repData, \@paletteCols) == -1);
         }
      }
      # Check for associated ledmap entry and duplicate it too.
      my $query = "SELECT Mnum,Mdata FROM Ledmaps WHERE Mlid = $$Parsed{'lid0'};";
      my @mapdata = ();
      unless (&SelectDbArray($Dbh, $query, \@mapdata)) {
         my @ledmapCols = ('Mapid','Mlid','Mnum','Mdata');
         foreach my $rec (@paldata) {
            my @data = split('\|', $rec);
            $repData{'Mapid'} = 'NULL';     # Unique DB generated value.
            $repData{'Mlid'} = $repData{'Kid'};
            $repData{'Mnum'} = $data[0];
            $repData{'Mdata'} = $data[1];
            return 1 if (&InsertDbData($Dbh, 'Ledmaps', \%repData, \@ledmapCols) == -1);
         }
      }
      # Show updated record.
      my $query = join(' ', "SELECT", join(',', @columns), 
         "FROM Presets LEFT JOIN Keywords ON Presets.Lid = Keywords.Kid " .
         "WHERE Presets.Lid = $repData{'Kid'};");
      return 1 if (&SelectDbArray($Dbh, $query, \@array));
      return 1 if (&DisplayPresets($Dbh, $Parsed, \@array));
   }
   else {
      &ColorMessage("   Required lid:<i> not specified.", 'YELLOW', '');
      return 1;
   }
   return 0;
}

1;
