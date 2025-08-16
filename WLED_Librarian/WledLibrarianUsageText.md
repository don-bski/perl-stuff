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
          [type:<w>] [pdata] [src] [pal] [wled[:<ip>]]
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
### Librarian Help Text
The `Help` command will display the full help text on the console. To limit the ouput
to a specific area, add one or two characters of the desired area. e.g. `help ex`.
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
   -c '<cmds>'   Process <cmds> non-interactive.
```
The `-p` option disables preset ID duplication checks during import. Preset data are
import with existing ID values. Also during import, the preset data is reformatted for
user readability when the `SHOW pdata` is used. The `-r` option disables this processing 
which may result in inconsistent key:value pair locations within the `pdata` output.

The `-f` option specifies an alternate database file. This is a wholly seperate database
that is created/used instead of the default database. Alternate databases are useful
in some test scenarios or when read-only access is user set by OS file permissions. 

The `-c` option performs the specified command(s) directly. Results are sent to
STDOUT and errors to STDERR. Used to integrate with a script or other external
program. `"<cmds>"` must comform to the interactive usage rules.

more
