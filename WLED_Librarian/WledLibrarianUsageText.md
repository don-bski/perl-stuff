# WLED Preset Librarian Usage Text
### Librarian Command Summary
This text is displayed on the console at program start and whenever the `Home` key is pressed.
Square brackets `[]` indicate an optional input. Angle brackets `<>` designate a value; 
`<i> integer: 1,42`, `<w> word: 4th`, `<n> name: 'Phased Reef'`, `<ip> IP address: 4.3.2.1`.
`|` indicates selectable values. `+` indicates a supported second command.
```=====================================================================================
WLED Preset Librarian

Enter command and arguments. The show command allows a second command which operates
on the show selected presets. Use arrow keys for command recall. Default tag:new is
set for imported presets when no tag or group is specified. lid, pid, tag, and group
support multiple comma separated values. e.g. tag:<w>,<w>. Home key shows this header.

Commands:
   show [tag:<w>] [group:<w>] [pid:<i>] [date:<d>] [lid:<i>] [pname:<n>] [qll:<w>]
          [type:<w>] [pdata] [src] [pal] [map] [wled[:<ip>]]
      + [add [tag:<w>] [group:<w>]]
      + [remove [tag:<w>] [group:<w>]]
      + [export [file:<file>] [wled[:<ip>]]]
   delete [lid:<i>] [pid:<i>] [tag:<w>] [group:<w>]
   dupl lid:<i> [pid:<i>] [pname:<n>] [qll:<w>] [tag:<w>] [group:<w>]]
   edit lid:<i> [pid:<i>] [pname:<n>] [qll:<w>] [src:<w>]
   import [file:<file>] [wled:[<ip>]] [tag:<w>] [group:<w>]
   sort [lid|pid|date|pname|tag|group]:[a|d]
   help [add|change|delete|edit|export|general|import|quit|remove|show]
   quit

=====================================================================================
Enter ->
```
### Librarian Help

#### General
Wled librarian is a simple tool that is used for the storage of WLED presets as
individual entities in a database. These preset data are tagged and grouped by the
user as needed. Presets can then be selected ad-hoc or by tag/group for export to a
WLED presets file or directly to WLED over WIFI.

The database is contained in a single file, default: `wled_librarian.dbs`, that is
located in the librarian startup directory or optionally specified on the program
start CLI, `-f <file>`. For database safeguard, periodically copy the file to a
safe external location using an appropriate operating system command. To restore,
copy the backup file to the working database file name.

Some operations involve the `SHOW` command and second command on the same user input
line. SHOW and its filter options select the presets that will be affected by the
second command. Use the SHOW command alone until the desired records are displayed.
Then, recall the SHOW command and add the second command to the end of the line.

**Note:** The program has minimal operational guardrails. If told to delete a preset,
beyond a simple warning, it will do so. Use with care.

The following options can be specified on the program start CLI:
```
   -h            Displays the program CLI help.
   -a            Monochrome output. No ANSI color.
   -d            Run the program in debug mode.
   -p            Disable import preset ID checks.
   -r            Disable import preset data reformat.
   -f <file>     Use the specified database file.
   -c '<cmd>'    Process <cmds> non-interactive.
```
The `-p` option disables preset ID duplication checks during import. Preset data are
import with existing ID values. Also during import, the preset data is reformatted for
user readability when the `SHOW pdata` is used. The `-r` option disables this processing 
which may result in inconsistent key:value pair locations within the `pdata` output.

The `-f` option specifies an alternate database file. This is a wholly seperate database
that is created/used instead of the default database. Alternate databases are useful
in some test scenarios or when read-only access is user set by OS file permissions. 

The `-c` option performs the specified command directly; no interactive prompt. Piped
STDIN input is also supported. Results are sent to STDOUT and STDERR. Used to integrate 
with an external program. `"<cmd>"` and piped input must comply with interactive input 
usage rules.

#### Interactive Keys
```
   UpArrow  DnArrow       Recall previously used command.
   LftArrow  RgtArrow     Move curcor position in current CLI.
   Del  Backspace         Remove character in current CLI.
   Tab                    file: name search/entry, similar to OS. No ~ support.
   Home                   Display program headline command summary.
```
All librarian commands and options are case insensitive. Options and their value(s)
must be colon `:` joined. Commands are capitalized in this help text for clairity.

#### SHOW command
`SHOW tag:<w> group:<w> pid:<i> date:<d> lid:<i> pname:<w> type:<w> pdata pal src wled`<br/>
Used to display database records matching the specified criteria. For multiple
options, they are logically joined by AND in the database query.`tag:new
(and) date:2025-06-13`. For options that support multiple value input, the items
are logically OR-ed. `pid:5,9`, 5 or 9 or both.

Text based option input `<w>` is used in a 'contains' manner. `pname:blu` shows
all presets with the letters 'blu' in the preset name. Numeric option input `<i>`
is matched exactly. The type option selects presets or playlists. `type:pl`. Preset 
data `pdata`, custom palette `pal`, and source `src` options display the specified 
data for each record output.

Option `wled[:<ip>]` will send the preset data to the specified WIFI connected WLED
instance. Unlike export, this action does not affect existing presets stored on the
WLED instance. If a playlist is sent, the presets it uses need to be present. If
multiple records are selected, only the first record is displayed.<br/>
Example: `SHOW lid:2,4,7 pdata`  or  `SHOW lid:3 wled`

#### ADD command
`ADD tag:<w>[:<w>] group:<w>[:<w>]`<br/>
Used to add one or more tag and/or group words to the selected presets. Use the
SHOW command to filter for the desired preset(s). Then, recall the SHOW command and
add this command to the end.<br/>
Example: `SHOW tag:new ADD tag:xmas,4th`

#### REMOVE command
`REMOVE tag:<w> group:<w>`<br/>
Used to remove tag and/or group word(s) from the selected presets. Use the SHOW
command to filter for the desired preset(s). Then, recall the SHOW command and add
this command to the end.<br/>
Example: `SHOW group:test REMOVE group:test,xmas`

#### EXPORT command
`EXPORT file:<file> or wled[:<ip>]`<br/>
Used to send the SHOW selected preset data to a file or a WLED instance. The file
is WLED compatible for subsequent upload into WLED using its Config->**Restore presets**
function. Custom palette files, e.g. palette0.json, are also created if needed by one
or more of the presets.<br/>
Example: `SHOW group:4th EXPORT file:/home/pi/wled/4th-presets.json`

When `wled` is specified, the preset data is sent to an active WLED over its WIFI
connection and replaces the current presets data. Preset used custom palettes are
also sent. The default WLED WIFI address is 4.3.2.1 if not specified.<br/>
Example: `SHOW tag:xmas EXPORT wled:192.168.1.20`

Following WIFI transfer, the active WLED is reset to activate the presets.

#### DELETE command
`DELETE [lid:<i>] [pid:<i>] [tag:<w>] [group:<w>] [pal:<i>]`<br/>
Used to delete preset data record(s). Specify one or more record selection filters.
Respond to the confirmation prompt to proceed with the operation. Use caution. There
is no un-delete function.<br/>
Example: `DELETE lid:10,13`

#### DUPL command
`DUPL lid:<i> [pid:<i>] [pname:<n>] [qll:<w>] [tag:<w>] [group:<w>]`<br/>
Used to duplicate a preset data record. The `lid` specified source record is replicated
to the next available lid. Tag/group words associated with the source record are not
replicated. Optional parameters, if specified, are applied to the new preset record.<br/>
Example: `DUPL lid:17 pid:67 pname:TwinkleRedGrn tag:xmas`

#### EDIT command
`EDIT lid:<i> [pid:<i>] [pname:<n>] [qll:<w>] [src:<w>]`<br/>
Used to change the preset ID `Pid`, preset name `Pname`, quick load label `Qll`, or
import source `src` value. `Lid:` specifies the database record to change. `Pid:, pname:
qll: and src:` specify the replacement values. If the new preset name includes a space,
enclose the new value in single quotes.<br/>
Example: `EDIT lid:2 pid:42 pname:'The Answer'`

#### IMPORT command
`IMPORT file:<file> wled[:<ip>] tag:<w>[,<w>] group:<w>[,<w>]`<br/>
Used to load JSON formatted WLED preset data into the database. The WLED presets
backup function in the WLED configuration menu can be used to create a file. Tag
and/or group words can be applied to all presets during import. `tag:new` is
applied if neither is specified.<br>
Example: `IMPORT file:presets.json group:xmas`

The presets on an active WLED instance can be directly imported over WIFI. The
above tag/group word rules apply. Specify the IP address if WLED is not using
the 4.3.2.1 default.<br/>
Example: `IMPORT wled:192.168.1.12 tag:test,xmas`

Presets, palettes, and ledmaps are user created in the WLED UI. Each consists of JSON formatted
field:value pairs. The palette and ledmap entities are associated with a preset and saved in the 
WLED UI by the user. Field:value pairs within the preset JSON link the palette and ledmap. This 
association is used to store the preset, palette, and ledmap JSON data in the WledLibrarian's 
database.

During import, the preset JSON is checked for a custom palette linkage; `pal:256` through `pal:247` which 
corresponds to `palette0.json` through `palette9.json` files. These files must be present along with the
preset.json when an `IMPORT file:` is performed. `IMPORT wled:` will automatically transfer the 
associated palette data from the WLED instance.

Import of ledmap data functions in a similar manner. The importing preset is checked for `ledmap:0`
through `ledmap:9` which corresponds to `ledmap0.json` through `ledmap9.json`. During subsequent preset 
EXPORT, the palette and ledmap JSON entities are recreated; files or direct-to-WLED data transfers.

Checks are performed on each incoming preset to help mitigate duplications. If the
preset is already in the database, the user is prompted for an action; **S**kip, 
**R**eplace, **N**ew, **K**eep, or **#**. # is a numeric value in the range 0-250.
The importing preset ID is changed to the entered value. Enter **0** to abort the 
import. For choice `New`, the importing preset ID is changed to the lowest unused 
ID value. Choice `Keep` imports the preset with its existing pid.

Additional processing occurs for choice New or a user entered ID value. During
the import operation, any importing playlists that use the old ID value will be
changed to use the new ID value.

Duplicate preset ID's or preset data will not affect the librarian database. All
presets are assigned a unique library ID `lid`. The preset ID `pid`, like tag or
group, is mainly used for SHOW command selection purposes. Import pid checks can
be disabled by adding the `-p` option to the program start CLI.

#### SORT command
`SORT lid | pid | date | pname | tag | group:a|d`<br/>
Specifies the column and direction to order the SHOW command output. **a**scending, low to
hig), **d**escending, high to low. The setting remains in effect until changed. Default
column is `Lid:a`.<br/>
Example: `SORT date:d`

#### CFG command
`CFG [wled:<ip>] [pop:<i>] [bri:<i>] [info[:c|:p]]`
Sets the default configuration value for power-on-preset (pop) and/or global brightness
(bri) on the WIFI connected WLED instance. Include the wled: option if the WLED instance
is not using address 4.3.2.1. These settings are not kept in the database. They are
stored on the WLED instance and used by WLED during startup. The pop: specified preset is
activated on the WLED instance for confirmation when set. If no options are specified
the WLED instance is read and the current values for these parameters are displayed.

The info: option displays the current WLED configuration and preset data that is present
on the WLED instance. Use :c or :p to limit the output; unspecified displays both. The
configuration JSON is complete with the pop: and bri: settings shown in the 'def' section.
The preset data in this output is abreviated. See database (pdata) for full JSON.<br/>
Examples: `CFG pop:3   CFG info`

#### HELP command
`HELP [add | change | delete | edit | export | general | import | quit | remove | show]`<br/>
Displays the full help text on the console. To limit the ouput to a specific area, add 
one or two characters of the desired area.<br/>
Example: `help ex`

#### QUIT command
`QUIT`<br/>
The quit command terminates the WLED ligrarian program. The current state of the database 
is preserved.<br/>
Example: `QUIT`
