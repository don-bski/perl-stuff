## WledLibrarian.pl
A simple WLED preset librarian with old school CLI user interface (a.k.a., TUI or Text User Interface). 
It is used to import WLED presets as individual entities into a database. These preset data can be 
tagged and grouped by the user as needed. For example, 'xmas' might identify the presets used in a 
holiday display. Presets can be selected ad-hoc or by tag/group word for export to a WLED presets file 
or directly to WLED over WIFI. 

The program has been tested in Linux and Windows (strawberry perl) environments. To install on 
Linux, download the contents of the Wled_Librarian folder to a user directory. Launch the 
program, e.g. `perl WledLibrarian.pl`, in a CLI terminal. Use `cpanm` to install any dependent 
perl modules that are identified. 

To install the PAR::Packer generated Windows exe, download the WledLibrarian zip file to a user 
folder and unzip it. Right click the WledLibrarian.exe file and select `CRC SHA` to check its 
SHA256 to the value shown below. To run WledLibrarian, right click and select Open. To use any 
ledLibrarian.exe CLI options, create a shortcut and add them via the shortcut properties. 
ALternately, open a Command window, change to the WledLibrarian folder, and enter 
`WledLibrarian.exe`. The -h option will display startup available options.

When WledLibrarian is running, enter **Help** for operational details. 
[WledLibrarian usage text](WledLibrarianUsageText.md) , [WledLibrarian Tutorial](WledLibrarianTutorial.md).

Coded in Perl, the librarian utilizes the [DBD::SQLite](https://metacpan.org/pod/DBD::SQLite) 
module which is a self-contained RDBMS database. Librarian commands provide the database 
interfacing functions. [SQLite-tools command-line shell](https://www.sqlite.org/), can 
also be used to access/modify the database if you are familiar with SQL. The librarian code 
performs a database check during startup. It will report an error and terminate if the expected 
tables and their columns are not present. 

The user is prompted to create a new empty database if an existing database file is not found. A 
sample database file *wled_librarian.dbs.zip* is included in this archive. Unzip it in a working 
directory for use if desired. The presets in the group *wall* are mostly configured for a single 
711 LED string. The presets in group *house* are configured for four LED channels. Some of these 
presets use multiple segments. Have a look at the preset Pdata using the librarian SHOW command.

The program reformats the preset JSON during import to improve user readability. This has been tested 
with a number of LED strip types, primarily WS2815, and ESP32. Other hardware combinations may reveal 
errors due to untested WLED json keys. A CLI option is available to disable this processing.<br/>

**WledLibrarian-v1.1.zip** - WledLibrarian standalone Windows executable, built with perl PAR::Packer.<br/>
WledLibrarian.exe `SHA256: AE413B5B454E082C358637DA4138496E2A1E0D62D446CD3760354D223C940DFC`<br/><br/>
<img src="librarian.png" alt="screenshot" width="600"/>
