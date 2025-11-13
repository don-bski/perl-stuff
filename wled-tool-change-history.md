**11-13-2025** - wled-tool v1.5 contains the following changes.
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
