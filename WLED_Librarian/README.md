## WledLibrarian.pl
A simple WLED preset librarian with old school CLI user interface. It is used to import WLED 
presets as individual entities into a database. These preset data can be tagged and grouped by 
the user as needed. For example, 'xmas' might identify the presets used in a holiday display. 
Presets can be selected ad-hoc or by tag/group word for export to a WLED presets file or 
directly to WLED over WIFI. 

The program is currently beta release code. It was developed and tested in Linux. Preliminary
testing in the Windows environment (strawberry perl) has also been completed. Launch the 
program and enter **Help** for operational details. [WledLibrarian usage text](WledLibrarianUsageText.md).

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

**WledLibrarian-v0.3.zip** - WledLibrarian standalone Windows executable, built with perl PAR::Packer.<br/>
WledLibrarian.exe `md5: 75a99c67cddb7004027e7576fc387c4c`<br/><br/>
<img src="librarian.png" alt="screenshot" width="600"/>
