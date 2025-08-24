**8-24-2025** - WledLibrarian v0.5 corrects issues with the -c option and operating system pipes. These
methods can be used to integrate the librarian with external programs for higher level integration or
automation.<br/> 

**8-19-2025** - WledLibrarian v0.4 processes LED maps that are associated with a preset. Led maps
are created/edited using the WLED GUI; `http://<wled-ip>/edit`. See the WledLibrarian help and 
the WLED Wiki for information about LED maps. The mapping data is handled transparently as part of 
import/export and stored in a new **Ledmaps** database table. The SHOW command option `map` is used 
to display preset associated mapping data.<br/> 

The v0.4 librarian code warns the user of a missing Ledmaps table during start up and prompts for
corrective action. Respond `Yes` to create the new table. Future preset imports/exports with 
associated led mapping data will be properly processed. Any existing presets that use led maps
should be re-import.<br/>

FYI: As of this date, there is an [open issue](https://github.com/wled/WLED/issues/1592)
related to the WLED /edit function.<br/><br/>

**8-15-2025** - WledLibrarian v0.3 is updated to process custom palettes that are associated with a 
preset. The palette data is handled as part of import/export. Future librarian features may include 
standalone palette file import/export.<br/>

Palette data is stored in a new Palettes database table. The v0.2 database is not compatible with 
the v0.3 librarian code. If using the v0.2 version, recreate the database or use the v0.3 sample 
database.<br/><br/>

**8-03-2025** - Initial WledLibrarian v0.2 release.
