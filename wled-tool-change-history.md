**11-13-2025 - wled-tool v1.5**
1. The interactive preset audition mode (-i) has been enhanced.
   - The initial header now includes informational data as read from the target WLED instance. This data is similar to what is shown in the WLED GUI->Info page.
     - WLED version, build number, and revision string.
     - WLED file system used/total values, fullness percentage, and free heap size.
     - WLED wifi channel, signal strength, and user configured max LED current setting.
   - Added command 'f' to show information related to the active preset as read from the target WLED instance. The data is reread from WLED for each command entry.
     - Active preset, LED frame rate, and estimated LED current.
   - Added the 'r' command to perform WLED reboot.
   - Show preset list, duration, and transition data when a playlist is specified for audition.
2. The -P and -p options now scan the presets during processing and display the names of any custom palettes. This serves to notify the user of potentially needed -G or -g operations.
3. Enhacements to the -A option which combines the restore of configuration, preset, palette, and ledmap data into a single operation. Under some conditions, an incomplete restore would occur. The code was refactored to improve robustness and error detection.

**11-01-2025 - wled-tool-v1.4**
1. Added code to display the presets and durations content when a WLED resident playlist is selected in the interactive audition (-i) mode.
 
**9-13-2025 - wled-tool-v1.3**
1. Refactored the format (-f) function to handle preset.json and cfg.json data. Code from WledLibrarian used having better key:value pair typing and exception handling. 
2. Combined multiple code blocks into a common subroutine for all json data cleanup and validation.

**9-10-2025 - wled-tool-v1.2**
1. Commands have been added to the interactive audition (-i) mode.
   - Default brightness 'db'.
   - Default preset 'dp'.
   - Quit 'q'.
   - Exit 'e'.
2. Added code to get and display the current brightness setting from WLED when only 'b' is entered during interactive audition mode.

**8-15-2025 - wled-tool-v1.1**
1. Added ledmap.json backup and restore (-m and -M) startup CLI options.
2. Included ledmaps in all data (-a and -A) backup and restore options.
3. Improved performance related to processing of palette.json files. The code now properly handles a WLED returned 404 status for unknown palette entry.

**8-04-2025 - wled-tool-v1.0**<br/>
Initial code release.
