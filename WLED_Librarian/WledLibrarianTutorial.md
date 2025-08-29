##WLED Preset Librarian Tutorial

###Librarian Install<br/>
Download the librarian program from gitHub using a web browser. Github
doesn't make this easy for a single subfolder. Proceed as follows.
<pre>
 1. Select the github WLED_Librarian folder. All librarian files are shown.
 2. Copy the URL from your browser's address bar. Or use: https://github.com/don-bski/perl-stuff/tree/main/WLED_Librarian
 3. In another browser tab, goto DownGit (https://downgit.github.io/#/home).
 4. Paste URL into the `Directory Link` box and click download. The file WLED_Librarian.zip is 
created in your browser's download folder.
 5. Move the ZIP file to a dedicated folder, e.g. WLED, in your PC user space and
decompress it. All librarian files are now present.
 6. If Windows PC and you plan to use the librarian executabe instead of perl, decompress the 
`WledLibrarian.zip` file.
 7. Decompress the sample database; `wled_librarian.dbs-vX.X.zip`.
</pre>

###Librarian Launch<br/>
Open a linux terminal or Windows Command window.
Use CLI `cd` command to set the current working directory to the install folder.
Launch the librarian program; `perl WledLibrarian.pl` or Windows `WledLibrarian.exe`. The
librarian command summary displayed. If prompted to create a new database, respond **No**.
(We'll get to this later.) 
Either the sample database was not properly decompressed or the specified `cd` path is
incorrect. Use `ls' (linux) or `dir' (Windows) to check current working directory. The file
`wled_librarian.dbs` must be present to continue with  this tutorial.

###Librarian Test Drive<br/>
The librarian command summary shows the supported commands and options. This summary
can be displayed by pressing the keyboard `Home` key. Take a moment to familiarize
yourself with the librarian commands and options. Note that all librarian command and
option input is case insensitive. Commands are shown in caps below as a reading aide.

Behind the scenes, the librarian uses a dedicated database to store WLED presets. Presets 
are IMPORT into the database using WLED preset.json backup files or directly from WLED 
using its WIFI access point. During import, the presets are stored as individual entities 
in the librarian database. For example, if you've created 5 presets using the WLED GUI,
there will be 5 corresponding librarian preset entries after import.

Once in the database, the presets can be organized using tag and/or grouping keywords.
Enter `SHOW tag:hween` at the librarian prompt and press enter. The presets in the sample
database that are tagged with `hween` (Halloween) with be displayed.

`Enter -> show tag:hween

Type       Pid   Pname              Qll    Date                  Lid    Tag              Group   
--------   ---   ----------------   ----   -------------------   ----   --------------   -----   
preset     1     LEDs Off                  2025-08-13_16:21:02   1      4th,hween,xmas   house   
preset     2     LEDs On                   2025-08-13_16:21:02   2      4th,hween,xmas   house   
preset     3     DanceOrgVio        HD     2025-08-13_16:21:02   3      hween            house   
preset     4     Twinklecat pal4    TC     2025-08-13_16:21:02   4      hween            house   
...
preset     9     HalloweenMix 2     H2     2025-08-13_16:21:02   9      hween            house   
preset     10    HalloweenMix 3     H3     2025-08-13_16:21:02   10     hween            house   
playlist   30    HallowPlaylist     HP     2025-08-13_16:21:02   11     hween            house   

Enter -> `

Likewise, the command `SHOW group:wall` will display the presets with the word 'wall' in the 
grouping option.
 
`Enter -> show group:wall

Type       Pid   Pname               Qll    Date                  Lid    Tag       Group   
--------   ---   -----------------   ----   -------------------   ----   -------   -----   
preset     1     Rainbow Bounce      RB     2025-08-14_12:08:11   50     WallyB1   wall    
preset     3     Candy Dual Scan     CD     2025-08-14_12:08:11   51     WallyB1   wall    
playlist   4     PowerOnPlaylist     PO     2025-08-14_12:08:11   52     WallyB1   wall    
preset     5     Rainbow Starburst   RS     2025-08-14_12:08:11   53     WallyB1   wall    
...    
preset     46    3RGB-Twink-Glit2    G2     2025-08-14_12:08:11   90     WallyB1   wall    
preset     47    3RGB-Twink-Glit3    G3     2025-08-14_12:08:11   91     WallyB1   wall    
Enter -> `

If the command `SHOW tag:hween group:wall` is entered, no presets are shown. This is because 
there are no presets in the sample database with `tag:hween` AND `group:wall`.

`Enter -> show tag:hween group:wall
   No presets to display.
Enter ->` 

The `SHOW` command with no options shows all database entries. They are sorted by their
library ID (Lid) by default. To change the sorting to preset ID (Pid), type `SORT pid` 
and press enter. Subsequent SHOW commands will now display the presets ordered by preset 
ID. The command `SORT lid:d` causes the show command preset output to be displayed by 
library ID in descending order. 

Let's create a small preset **test** grouping. Enter the command `SHOW lid:3,13,31`
and press enter. This displays the database entries that will be affected by the 
next operation.

`Enter -> show lid:3,13,31

Type     Pid   Pname           Qll    Date                  Lid    Tag     Group   
------   ---   -------------   ----   -------------------   ----   -----   -----   
preset   3     DanceOrgVio     HD     2025-08-13_16:21:02   3      hween   house   
preset   4     FireworksDuo2   F2     2025-08-13_16:21:33   13     4th     house   
preset   5     DanceRedBlu     D3     2025-08-13_16:23:22   31     xmas    house   

Enter ->` 

Recall the SHOW command using the up-arrow key. Type a space and `ADD group:test` 
at the end of the recalled command. Then press enter.

`Enter -> show lid:3,13,31 add group:test   Tag/Group keyword(s) added.

Type     Pid   Pname           Qll    Date                  Lid    Tag     Group        
------   ---   -------------   ----   -------------------   ----   -----   ----------   
preset   3     DanceOrgVio     HD     2025-08-13_16:21:02   3      hween   house,test   
preset   4     FireworksDuo2   F2     2025-08-13_16:21:33   13     4th     house,test   
preset   5     DanceRedBlu     D3     2025-08-13_16:23:22   31     xmas    house,test   

Enter ->`

Use `SHOW group:test` to display this new grouping.

`Enter -> show group:test

Type     Pid   Pname           Qll    Date                  Lid    Tag     Group        
------   ---   -------------   ----   -------------------   ----   -----   ----------   
preset   3     DanceOrgVio     HD     2025-08-13_16:21:02   3      hween   house,test   
preset   4     FireworksDuo2   F2     2025-08-13_16:21:33   13     4th     house,test   
preset   5     DanceRedBlu     D3     2025-08-13_16:23:22   31     xmas    house,test   

Enter ->`

Let's remove **house** from the grouping. Recall the previous command `SHOW group:test`.
Type a space and `REMOVE group:house`. Then press enter.

`Enter -> show group:test remove group:house   Tag/Group keyword(s) removed.

Type     Pid   Pname           Qll    Date                  Lid    Tag     Group   
------   ---   -------------   ----   -------------------   ----   -----   -----   
preset   3     DanceOrgVio     HD     2025-08-13_16:21:02   3      hween   test    
preset   4     FireworksDuo2   F2     2025-08-13_16:21:33   13     4th     test    
preset   5     DanceRedBlu     D3     2025-08-13_16:23:22   31     xmas    test    

Enter ->`

We'll now export these entries to a WLED json file. The file can then be loaded into
WLED using its GUI `Config->Restore Presets` function. Press the up-arrow key twice
and add a space and `EXPORT file:test_presets.json`. Then press enter. Since no file
path was included, the file will found in the current working directory.

`Enter -> show group:test export file:test_presets.json
   Exported 3 presets to test_presets.json

Type     Pid   Pname           Qll    Date                  Lid    Tag     Group   
------   ---   -------------   ----   -------------------   ----   -----   -----   
preset   3     DanceOrgVio     HD     2025-08-13_16:21:02   3      hween   test    
preset   4     FireworksDuo2   F2     2025-08-13_16:21:33   13     4th     test    
preset   5     DanceRedBlu     D3     2025-08-13_16:23:22   31     xmas    test    

Enter ->`

As an exercise, restore **house** to these presets and remove **test** from them.
Note that we could have just as easily added **test** to the tags of these presets
and used `tag:test` for the export operation.

You may be thinking, what if one or more of the preset IDs I want to export is the
same? Can the preset ID be changed. Yes, the EDIT command is used for this purpose.
But recall that up to this point we've been using commands that don't affect any
of the current preset data. The edit command changes the preset data. Any other
tags or groupings that use the preset will reference the edited preset data. In 
some cases, this is okay, but likely not always. 

This is where the DUPL command can be used to make a database copy of the preset
and make changes to the copy. This preserves the original preset and its
tag/group associations.

`Enter -> dupl lid:3 tag:test   Lid 92 created.

Type     Pid   Pname         Qll    Date                  Lid    Tag    Group   
------   ---   -----------   ----   -------------------   ----   ----   -----   
preset   3     DanceOrgVio   HD     2025-08-28_10:17:33   92     test           

Enter ->`

If we add the `src` option to the SHOW command, we can see the preset source.

`Enter -> show lid:92 src

Type     Pid   Pname         Qll    Date                  Lid    Tag    Group   Src             
------   ---   -----------   ----   -------------------   ----   ----   -----   -------------   
preset   42    DanceOrgVio   HD     2025-08-28_10:17:33   92     test           Dupl of lid 3   

Enter ->`

Note the newly created librarian ID value 92. Use this Lid value to edit the 
copy and change the preset ID; and/or other supported fields.

`Enter -> edit lid:92 pid:42   Value changed.

Type     Pid   Pname         Qll    Date                  Lid    Tag    Group   
------   ---   -----------   ----   -------------------   ----   ----   -----   
preset   42    DanceOrgVio   HD     2025-08-28_10:17:33   92     test           

Enter ->`

In our examples here, preset lids 13 and 31 would be duplicated and edited 
the same way. The results of this are as follows.

`Enter -> show tag:test src

Type     Pid   Pname           Qll    Date                  Lid    Tag    Group   Src              
------   ---   -------------   ----   -------------------   ----   ----   -----   --------------   
preset   42    DanceOrgVio     HD     2025-08-28_10:17:33   92     test           Dupl of lid 3    
preset   43    FireworksDuo2   F2     2025-08-28_10:32:33   93     test           Dupl of lid 13   
preset   44    DanceRedBlu     D3     2025-08-28_10:32:59   94     test           Dupl of lid 31   

Enter ->`

We'll now try a few operations with a WIFI connected WLED instance. Ensure you have a
WLED GUI presets backup before you start if the current presets are needed.

The SHOW command provides a `wled` option. This option supports an IP address if the
WLED instance is not at the default 4.3.2.1 value. When specified, the first preset of the SHOW 
command output is sent to the WIFI connected WLED instance. This is done using a method that 
does not affect the existing WLED presets. This can be used to audition a preset on the WLED 
instance.

`Enter -> show lid:92 wled

Type     Pid   Pname         Qll    Date                  Lid    Tag    Group   
------   ---   -----------   ----   -------------------   ----   ----   -----   
preset   42    DanceOrgVio   HD     2025-08-28_10:17:33   92     test           

Enter ->`

To do a bit of database cleanup from this tutorial, we'll use the DELETE command. This
command permanently removes database entries so use with care. Use IMPORT or DUPL 
to recover an errant record deletion.

`Enter -> delete tag:test

Type     Pid   Pname           Qll    Date                  Lid    Tag    Group   
------   ---   -------------   ----   -------------------   ----   ----   -----   
preset   42    DanceOrgVio     HD     2025-08-28_10:17:33   92     test           
preset   43    FireworksDuo2   F2     2025-08-28_10:32:33   93     test           
preset   44    DanceRedBlu     D3     2025-08-28_10:32:59   94     test           

Delete these presets? y/N -> y   3 presets deleted.
Enter ->`

The SHOW command with secondary command `EXPORT wled` sends the displayed presets to the
WLED instance. This action **replaces** the current presets on the WLED instance; the
same as restoring a preset.json file using the WLED GUI. This operation is typically
used for seasonal preset groupings.

`Enter -> show tag:xmas export wled
   Sent palette to WLED: palette1.json
   Sent palette to WLED: palette2.json
   Sent palette to WLED: palette3.json
   Exported 23 presets to WLED.
   WLED reset. Wait ~15 sec for network reconnect.

Type       Pid   Pname              Qll    Date                  Lid    Tag              Group   
--------   ---   ----------------   ----   -------------------   ----   --------------   -----   
preset     1     LEDs Off                  2025-08-13_16:21:02   1      4th,hween,xmas   house   
preset     2     LEDs On                   2025-08-13_16:21:02   2      4th,hween,xmas   house   
preset     3     DanceGrnRed        D1     2025-08-13_16:23:22   29     xmas             house   
preset     4     DanceGrnBlu        D2     2025-08-13_16:23:22   30     xmas             house   
... 
playlist   32    GlitPlaylist       GP     2025-08-13_16:23:22   48     xmas             house   
playlist   33    XmasAlllist        XA     2025-08-13_16:23:22   49     xmas             house   

Enter ->`

Note in the above output, the librarian also sent palette data to the WLED instance. WLED
supports custom palettes. Up to 10 can be user created with the WLED GUI and associated with
one or more presets. The librarian detects these associations and automatically imports/exports
them in addition to the preset data. They are stored in a database table. A similar process
is used for a WLED custom LED map. Refer to the WLED Wiki for details about custom palettes
and LED maps.

Up to this point, we've been using the sample database that is included with the librarian.
We'll now create a new empty database and import from a presets.json file or WLED instance.
We'll use one of the librarian startup CLI options for this.

* Terminate the WLED Librarian using the QUIT command.
* Launch the librarian program with the -f option specified; `perl WledLibrarian.pl -f myDb.dbs` 
or Windows `WledLibrarian.exe -f myDb.dbs`. 

When launched, you will see something similar the following. Respond **Yes**.

`Database file not found: /home/wled/wled_librarian.dbs
Create a new one? [y|N] -> y` 

The SHOW command will report an empty database.

`Enter -> show
   No presets to display.
Enter ->` 

This brings up an operational point to remember. If the prompt to create a new database is
output unexpectedly, either the current working directory is incorrect or the startup CLI 
specified database file is incorrect. When the -f option specifies a non-default database
file, it should be included for all subsequent librarian starts that use this database file.

We'll now import the presets on your WLED instance. There are two ways to do this; using a WLED
presets.json backup file or directly using a WIFI connection. The presets.json backup file is
created using the WLED GUI **Config->Backup presets** function. Upon completion, the file is
found in your browser's download folder. For WIFI, ensure the computer WIFI is connected to 
an active WLED access point.

This tutorial will use a small presets.json file for the following. You should use your actual 
WLED presets for the exercises. Replace `file:presets.json` in the example with `wled` or your
presets.json backup file.

`Enter -> import file:presets.json
   Successful import - playlist 1.
   Successful import - preset 2.
   Successful import - preset 3.
Enter -> show src

Type       Pid   Pname            Qll    Date                  Lid    Tag   Group   Src            
--------   ---   --------------   ----   -------------------   ----   ---   -----   ------------   
playlist   1     Playlist         PL     2025-08-29_08:47:50   1      new           presets.json   
preset     2     Rainbow Bounce   RB     2025-08-29_08:47:50   2      new           presets.json   
preset     3     Flame            PN     2025-08-29_08:47:50   3      new           presets.json   

Enter ->`

Note the Date, Src, and Tag values reflect the completed import. You would likely use the
SHOW ADD and SHOW REMOVE commands to change the default `new` tag keyword. You can specify 
the desired tag and/or group keyword(s) as part of IMPORT to save some database rework.
We'll delete these presets and re-import them.

`Enter -> delete lid:1,2,3

Type       Pid   Pname            Qll    Date                  Lid    Tag   Group   
--------   ---   --------------   ----   -------------------   ----   ---   -----   
playlist   1     Playlist         PL     2025-08-29_08:51:45   1      new           
preset     2     Rainbow Bounce   RB     2025-08-29_08:51:45   2      new           
preset     3     Flame            PN     2025-08-29_08:51:45   3      new           

Delete these presets? y/N -> y   3 presets deleted.
Enter -> import file:presets.json tag:test group:test
   Successful import - playlist 1.
   Successful import - preset 2.
   Successful import - preset 3.
Enter -> show src

Type       Pid   Pname            Qll    Date                  Lid    Tag    Group   Src            
--------   ---   --------------   ----   -------------------   ----   ----   -----   ------------   
playlist   1     Playlist         PL     2025-08-29_08:54:08   1      test   test    presets.json   
preset     2     Rainbow Bounce   RB     2025-08-29_08:54:08   2      test   test    presets.json   
preset     3     Flame            PN     2025-08-29_08:54:08   3      test   test    presets.json   

Enter ->`

The raw preset data in its JSON format can be viewed with the SHOW command.

`Enter -> show pdata

Type       Pid   Pname            Qll    Date                  Lid    Tag    Group   
--------   ---   --------------   ----   -------------------   ----   ----   -----   
playlist   1     Playlist         PL     2025-08-29_08:54:08   1      test   test    
"1":{"on":true,"n":"Playlist","ql":"PL","playlist":{
   "ps":[2,3],
   "dur":[300,200],
   "transition":[15,15],
   "r":false,"repeat":"0","end":"0"}}
preset     2     Rainbow Bounce   RB     2025-08-29_08:54:08   2      test   test    
"2":{"on":true,"n":"Rainbow Bounce","ql":"RB","bri":100,"transition":7,"mainseg":0,"seg":[
   {"id":0,"start":0,"stop":750,"grp":1,"spc":0,"of":0,"on":true,"bri":255,"frz":false,
   "col":[[255,170,0],[0,0,0],[0,0,0]],"fx":111,"sx":0,"ix":7,"pal":11,"rev":false,"sel":true,
   "mi":false,"cct":127},
   {"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},
   {"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},
   {"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},
   {"stop":0}]}
preset     3     Flame            PN     2025-08-29_08:54:08   3      test   test    
"3":{"on":true,"n":"Flame","ql":"PN","bri":180,"transition":10,"mainseg":0,"seg":[
   {"id":0,"start":151,"stop":210,"grp":1,"spc":0,"of":0,"on":true,"bri":200,"frz":false,
   "col":[[255,160,0],[0,0,0],[0,0,0]],"fx":66,"sx":70,"ix":70,"pal":35,"rev":false,"c1":128,"c2":180,"c3":25,"sel":true,
   "set":0,"o1":0,"o2":0,"o3":0,"si":0,"m12":0,"mi":false,"cct":127},
   {"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},
   {"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},
   {"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},{"stop":0},
   {"stop":0}]}

Enter ->`

During import, the librarian checks for potential preset duplication. This check compares
each importing preset `pdata`, specifically the segment or playlist data, with those present 
in the database. If a match is found, the user is prompted for an action. We'll import the
presets.json file again to illustrate.

`Enter -> import file:presets.json
Import duplicate -> Playlist 1 - Playlist
Existing -> Lid: 1  Playlist 1 - Playlist   Imported: 2025-08-29_08:54:08   Src: presets.json
Skip, Replace, New, Keep, or # (0 to abort) ->`

One of the following user responses is required.
* 0 - Abort the import. Any previous imported presets are retained.
* # - Import and change the preset ID to the specified numeric value. 
* Keep - Keep the importing preset as-is and import. 
* New - Import and change the preset ID to the next unused preset ID value.
* Replace - Replace the database preset with the importing preset.
* Skip - Skip import of this preset.

`Import duplicate -> Playlist 1 - Playlist
Existing -> Lid: 1  Playlist 1 - Playlist   Imported: 2025-08-29_08:54:08   Src: presets.json
Skip, Replace, New, Keep, or # (0 to abort) -> skip   Preset skipped.

Import duplicate -> Preset 2 - Rainbow Bounce
Existing -> Lid: 2  Preset 2 - Rainbow Bounce   Imported: 2025-08-29_08:54:08   Src: presets.json
Skip, Replace, New, Keep, or # (0 to abort) -> k   Successful import - preset 2.

Import duplicate -> Preset 3 - Flame
Existing -> Lid: 3  Preset 3 - Flame   Imported: 2025-08-29_08:54:08   Src: presets.json
Skip, Replace, New, Keep, or # (0 to abort) -> r   Existing Pid 3 replaced.
Enter -> show

Type       Pid   Pname            Qll    Date                  Lid    Tag    Group   
--------   ---   --------------   ----   -------------------   ----   ----   -----   
playlist   1     Playlist         PL     2025-08-29_08:54:08   1      test   test    
preset     2     Rainbow Bounce   RB     2025-08-29_08:54:08   2      test   test    
preset     3     Flame            PN     2025-08-29_09:06:51   3      test   test    
preset     2     Rainbow Bounce   RB     2025-08-29_09:06:51   4      new            

Enter ->` 

This is probably enough to provide you a general sense of what the librarian can do. 
Use the librarian `HELP` command to display all or part of the command help text for more
information.
