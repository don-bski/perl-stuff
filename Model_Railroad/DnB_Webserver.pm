#!/usr/bin/perl
# ============================================================================
# FILE: DnB_Webserver.pm                                           10-12-2020
#
# SERVICES:  DnB WEBSERVER and RELATED FUNCTIONS
#
# DESCRIPTION:
#    This perl module provides a basic webserver interface to the D&B model 
#    railroad. There is a lot going on in this module since it uses perl, 
#    webserver, CSS, javaScript, and HTML constructs to realize the necessary
#    functions. The data decoration CSS might be a bit much.
#
#    The webserver is started during the DnB.pl initialization phase. A
#    message is output on the console detailing the IP:Port value that is
#    used to connect an external web browser. This IP:port value is manually
#    entered into the browser's address bar. Upon successful connection, the
#    the D&B Model Railroad home page is displayed.
#
#    The webserver code monitors the IP:Port for browser requests. Validated
#    requests result in a corresponding data page to be created and sent to
#    the browser for display to the user. All dynamically created HTML pages
#    are stored and served from /dev/shm. Static files are served from the
#    DnB.pl confirgure $WebRootDir directory.
#
#    The webserver runs as a forked child process. As such, it does not have
#    access to current operational data. The main loop in DnB.pl therefore
#    writes the needed data to the /dev/shm directory about once per second.
#    This data is used to build the web pages that are sent to the browser.
#
# PERL VERSION: 5.24.1
#
# =============================================================================
use strict;
# -----------------------------------------------------------------------------
# Package Declaration
# -----------------------------------------------------------------------------
package DnB_Webserver;
require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
   Webserver
);

# -------------------------------------------------------------------------
# External module definitions.
use HTTP::Daemon;
use HTTP::Status;
use POSIX qw(strftime);
use DnB_Message;

# =============================================================================
# FUNCTION:  Webserver
#
# DESCRIPTION:
#    This routine is called during main program startup to launch the webserver
#    as a backgroung process. Directing an external web browser to the Rpi IP
#    (or hostname) and $ListenPort displays the home web page. Links on the 
#    home page provide access to the other data pages; e.g. turnout positions.
#
#    Depending on the browser version, the raw IP:Port might be needed for the
#    initial connection. 'sudo ifconfig' will display the network interfaces
#    on the Rpi.
#
# CALLING SYNTAX:   (using Super::Fork)
#    $pid = fork {sub => \&Webserver, args => [ $WebRoot, $ListenPort, 
#                                               $WebDataDir ] };
#
# ARGUMENTS:
#    $WebRoot            Webserver document root directory.
#    $ListenPort         Port to listen to for connections.
#    $WebDataDir         Directory for dynamic data content.
#
# RETURNED VALUES:
#    non-zero pid = Success,  undef($pid) = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::ChildName
# =============================================================================
sub Webserver {
   my($WebRoot, $ListenPort, $WebDataDir) = @_;
   my($result, $host, $url, $ipp, $daemon, $connect, $getRequest, $method);

   # Assume we just booted. Give time for WIFI to setup.
   sleep 10;

   # Remove any previous dynamic HTML files. The other data files are handled
   # by the main loop code.
   unlink glob("$WebDataDir/file_*.html");

   # Define some working variables and display webserver connection point. 
   $host = `/bin/hostname`;
   if (($? >> 8) != 0) {
      &DisplayError("Failed to get hostname. Webserver not started.");
      exit(1);
   }
   chomp($host);
   $url = join(':', $host, $ListenPort);

   # Determine raw ip:port for alternate browser connection point.
   $host = `/bin/hostname -I`;
   if ($host =~ m/^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s/) {
      $host = $1;
   }
   $ipp = join(':', &Trim($host), $ListenPort);
   $main::ChildName = "Webserver Process $ipp";

   # Establish connection point and start the webserver.
   unless($daemon = HTTP::Daemon->new(LocalPort => $ListenPort, ReuseAddr => 1,
                    Family => AF_INET, Type => SOCK_STREAM,  Listen => 5)) {
      &DisplayError("Webserver failed to start: $!");
   }
   else {
      &DisplayMessage("Webserver started.  Client connection url: $url or $ipp");
   
      # Process client connections.
      while ($connect = $daemon->accept) {
         while ($getRequest = $connect->get_request) {
            $method = $getRequest->method;
            if ($method eq 'GET') {
               &NewConnection($WebRoot, $getRequest, $connect, $WebDataDir);
               $connect->close;
               last;
            }
            else {
               $connect->send_error(RC_BAD_REQUEST, 'Unsupported method: $method');
               &DisplayError("Webserver, unsupported method: $method");
            }
         }
      }
   }
   &DisplayMessage("Webserver terminated.");
   exit(0);         
}

# =============================================================================
# FUNCTION:  NewConnection
#
# DESCRIPTION:
#    This routine is called to process new webserver connections. HTTP::Daemon
#    class methods are used to obtain request parameters ($Request) and send the
#    response to the $Connect attached browser. Supported requests are processed
#    by the RequestHandler() code.
#
#    All subsequent subroutines obtain their working parameters from the $Request
#    hash.
#
# CALLING SYNTAX:
#    $result = &NewConnection($WebRoot, $Request, $Connect, $WebDataDir);
#
# ARGUMENTS:
#    $WebRoot             Webserver document root directory.
#    $GetRequest          Request data structure.
#    $Connect             Connection socket structure.
#    $WebDataDir          Directory for dynamic data content.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub NewConnection {
   my($WebRootDir, $GetRequest, $Connect, $WebDataDir) = @_;
   my(@array);

   my(%dispatch) = ('top' => \&TopPageData, 'grade' => \&GradePageData,
                    'block' => \&BlockPageData, 'sensor' => \&SensorPageData,
                    'signal' => \&SignalPageData, 'turnout' => \&TurnoutPageData,
                    'main' => \&MainLiveData, 'yard' => \&YardLiveData);

   &DisplayDebug(1, "NewConnection, ========================================");
   
   my(%request) = ('OBJECT' => $GetRequest->uri->path, 'ROOT' => $WebRootDir,
                   'SHARE' => $WebDataDir, 'BUILDER' => '', 'PAGE' => '', 
                   'TYPE' => '');
   
   # Validate the request and call the request handler. If no page is specified,
   # the 'Top' page is served. Only a limited set of OBJECT requests are honored. 
   &DisplayDebug(1, "NewConnection, object: '$request{OBJECT}'");
   if ($request{OBJECT} =~ m#^/(.*)#) {
      $request{PAGE} = $1;
      $request{PAGE} = 'top' if ($request{PAGE} eq '');
      if (exists($dispatch{ $request{PAGE} })) {
         $request{BUILDER} = $dispatch{ $request{PAGE} };
         $request{TYPE} = 'text/html; charset=utf-8';
         &RequestHandler($GetRequest, $Connect, \%request);
      }
      elsif ($request{PAGE} =~ m/\.ico$/i) {
         $request{PAGE} = join('/', $WebRootDir, $request{PAGE});
         $request{TYPE} = 'image/x-icon';
         &RequestHandler($GetRequest, $Connect, \%request);
      }
      elsif ($request{PAGE} =~ m/\.(css)$/i or 
             $request{PAGE} =~ m/\.(webmanifest)$/i) {
         $request{PAGE} = join('/', $WebRootDir, $request{PAGE});
         $request{TYPE} = 'text/$1';
         &RequestHandler($GetRequest, $Connect, \%request);
      }
      
      # For live page overlay files, send the file indicated in the corresponding
      # .dat file that was set by the main loop.
      elsif ($request{PAGE} =~ m/([h|m|y]-overlay\.dat$)/i or 
             $request{PAGE} =~ m/(L\d\d-overlay\.dat$)/i or
             $request{PAGE} =~ m/(GC\d\d-overlay\.dat$)/i or
             $request{PAGE} =~ m/(Yard-S\d-overlay.dat$)/i) { 
         &ReadFile("$WebDataDir/$1", \@array, '');
         if ($array[0] =~ m/\.(gif)$/i or $array[0] =~ m/\.(jpg)$/i or 
             $array[0] =~ m/\.(png)$/i) {
            $request{TYPE} = join('/', 'image', $1);
            $request{PAGE} = join('/', $WebRootDir, $array[0]);
         }
         if (-e $request{PAGE}) {
            &RequestHandler($GetRequest, $Connect, \%request);
         }
         else {
            $Connect->send_error(RC_NOT_FOUND, 'File: $request{PAGE}');
            &DisplayError("NewConnection, File not found: $request{PAGE}");
         }
      }
      elsif ($request{PAGE} =~ m/\.(gif)$/i or $request{PAGE} =~ m/\.(jpg)$/i or 
             $request{PAGE} =~ m/\.(png)$/i) {
         $request{TYPE} = join('/', 'image', $1);
         $request{PAGE} = join('/', $WebRootDir, $request{PAGE});
         if (-e $request{PAGE}) {
            &RequestHandler($GetRequest, $Connect, \%request);
         }
         else {
            $Connect->send_error(RC_NOT_FOUND, 'File: $request{PAGE}');
            &DisplayError("NewConnection, File not found: $request{PAGE}");
         }
      }
      else {
         $Connect->send_error(RC_BAD_REQUEST, 'File: $request{PAGE}');
         &DisplayError("NewConnection, Bad request: $request{PAGE}");
      }
   }
   else {
      $Connect->send_error(RC_BAD_REQUEST, "Can't parse object: $request{OBJECT}");
      &DisplayError("NewConnection, Can't parse object: $request{OBJECT}");
   }

   return 0;
}

# =============================================================================
# FUNCTION:  RequestHandler
#
# DESCRIPTION:
#    This routine is called to process requests and send the response data to
#    the browser. Page requests utilize subroutines to generate the necessary 
#    response HTML. Run the program with debug level 1 to see the response 
#    data on the console. Alternately, enable developer mode in the browser
#    (usually F12). 
#
# CALLING SYNTAX:
#    $result = &RequestHandler($GetRequest, $Connect, \%Request);
#
# ARGUMENTS:
#    $GetRequest       Request data structure.
#    $Connect          Connection socket structure.
#    $Request          Pointer to request data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    $main::DebugLevel
# =============================================================================
sub RequestHandler {
   my($GetRequest, $Connect, $Request) = @_;
   my($contentLength, $timestamp); 
   my($contentFile) = "$$Request{SHARE}/file_$$.html";
   my(@resp) = ();
   
   &DisplayDebug(1, "RequestHandler, page: '$$Request{PAGE}'");
                   
   # Send response content.
   if ($$Request{TYPE} =~ m/html/) {
      
      # Generate the HTML <head> section data.
      push (@resp, qq(<!DOCTYPE html><html><head>));
      push (@resp, qq(<title>D&amp;B Model Railroad</title>));
      
      # Add javaScript if appropriate for page being built.
      &ScriptData(\@resp, $Request);
      
      # Add links to CSS and icon files. 
#      push(@resp, qq(<link rel="stylesheet" href="DnB-large.css">));      
      push(@resp, qq(<link rel="stylesheet" media="screen and (min-height: 801px)") .
                  qq( href="DnB-large.css">));      
      push(@resp, qq(<link rel="stylesheet" media="screen and (max-height: 800px)") .
                  qq( href="DnB-small.css">));      
      push(@resp, qq(<link rel="apple-touch-icon" sizes="180x180" ) . 
                  qq(href="/apple-touch-icon.png">));
      push(@resp, qq(<link rel="icon" type="image/png" sizes="32x32" ) .
                  qq(href="/favicon-32x32.png">));
      push(@resp, qq(<link rel="icon" type="image/png" sizes="16x16" ) .
                  qq(href="/favicon-16x16.png">));
      push(@resp, qq(<link rel="manifest" href="/site.webmanifest">));
      push(@resp, qq(</head><body><div class="tab">));
         
      # Generate the HTML <body> section data.
      $$Request{BUILDER}->(\@resp, $Request) if (exists($$Request{BUILDER}));
         
      # Complete the <html> page.
      push(@resp,  qq(</div></body></html>));

      # Tried to send the HTML data directly without creating a file but a
      # number of transmission reliability issues and program crashes were
      # encountered. Suspect this was due to socket data overload but could
      # not identify the root cause.        
      if (&WriteFile($contentFile, \@resp, "")) {
         $Connect->send_error(RC_NO_CONTENT, 'File: $$Request{PAGE}  ' .
                                             'HTML file creation error.');
         return 1;
      }
      else {
         $contentLength = -s $contentFile;
         if ($main::DebugLevel >= 1) {
            foreach my $rec (@resp) {
               &DisplayDebug(1, "RequestHandler, resp: '$rec'");
            }
         }
      }
      
      # Send the response header to the browser.
      $timestamp = strftime "%a, %d %b %Y %H:%M:%S GMT", gmtime;
      $Connect->send_status_line(RC_OK,'OK', 'HTTP/1.1');
      $Connect->send_header('Date', $timestamp);
      $Connect->send_header('Server', 'D&B Model Railroad Rpi Webserver');
      $Connect->send_header('Content-Type', $$Request{TYPE});
      $Connect->send_header('Cache-Control', 'public');
      $Connect->send_header('Accept-Ranges', 'bytes');
      $Connect->send_header('Content-Length', $contentLength);
      $Connect->send_crlf;
      
      # Send the HTML data.
      $Connect->send_file($contentFile);
      $Connect->send_crlf;
      &DisplayDebug(1, "RequestHandler, sent html: $contentFile");
   }
   
   # Send image data.
   elsif ($$Request{TYPE} =~ m/image/ or $$Request{TYPE} =~ m/text/) {
      $Connect->send_file_response( $$Request{PAGE} );
      &DisplayDebug(1, "RequestHandler, sent file: $$Request{PAGE}");
   }
   return 0;
}

# =============================================================================
# FUNCTION:  ScriptData
#
# DESCRIPTION:
#    This routine is called to add a <script> section to the specified array.
#    The live pages use javaScript to auto-refresh the images that show the
#    active track blocks. These transparent images overlay the page background
#    image and color the active track blocks. The DnB.pl main loop updates the
#    overlay images about once a second. 
#
#    A 'refresh(node)' function is launched for each overlay image when it is
#    initially displayed by the 'window.onload = function()'. The initial 
#    display of the image is immediate because its URL does not contain a 
#    timestamp string. Subsequent URLs include a new timestamp so the browser
#    is forced to re-GET the image from the webserver and not redisplay it 
#    from cache.
#
# CALLING SYNTAX:
#    $result = &ScriptData($Array, $Request);
#
# ARGUMENTS:
#    $Array            Pointer to array for records.
#    $Request          Pointer to request data hash.
#
# RETURNED VALUES:
#    0 = Success.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ScriptData {
   my($Array, $Request) = @_;

   push(@$Array, qq(<script>));
   if ($$Request{PAGE} =~ m/main/i) {      # Add javascript for mainline live page.
      push(@$Array, qq(function refresh(node) { ));
      push(@$Array, qq(  var timer = 2000;   // delay in msec ));
      push(@$Array, '  (function startRefresh() { ');  # perl doesn't like single (
      push(@$Array, qq(    var address; ));
      push(@$Array, qq(    if(node.src.indexOf('?')>-1) ));
      push(@$Array, qq(      address = node.src.split('?')[0]; ));
      push(@$Array, qq(    else ));
      push(@$Array, qq(      address = node.src; ));
      push(@$Array, qq(      node.src = address+"?time="+new Date().getTime(); ));
      push(@$Array, qq(      setTimeout(startRefresh,timer); ));
      push(@$Array, '  })(); ');                       # perl doesn't like single )
      push(@$Array, qq(} ));
      push(@$Array, qq(window.onload = function() { ));
      push(@$Array, qq(  var node = document.getElementById('y-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('m-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('h-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      
      push(@$Array, qq(  var node = document.getElementById('L01-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('L02-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('L03-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('L04-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('L05-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('L06-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('L07-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('L08-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('L09-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('L10-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('L11-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('L12-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      
      push(@$Array, qq(  var node = document.getElementById('GC01-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('GC02-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(} ));
   }
   
   elsif ($$Request{PAGE} =~ m/yard/i) {   # Add javascript for yard live page.
      push(@$Array, qq(function refresh(node) { ));
      push(@$Array, qq(  var timer = 2000;   // delay in msec ));
      push(@$Array, '  (function startRefresh() { ');  # perl doesn't like single (
      push(@$Array, qq(    var address; ));
      push(@$Array, qq(    if(node.src.indexOf('?')>-1) ));
      push(@$Array, qq(      address = node.src.split('?')[0]; ));
      push(@$Array, qq(    else ));
      push(@$Array, qq(      address = node.src; ));
      push(@$Array, qq(      node.src = address+"?time="+new Date().getTime(); ));
      push(@$Array, qq(      setTimeout(startRefresh,timer); ));
      push(@$Array, '  })(); ');                       # perl doesn't like single )
      push(@$Array, qq(} ));
      push(@$Array, qq(window.onload = function() { ));
      push(@$Array, qq(  var node = document.getElementById('S1-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('S2-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('S3-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('S4-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('S5-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(  var node = document.getElementById('S6-Ovr'); ));
      push(@$Array, qq(  refresh(node); ));
      push(@$Array, qq(} ));
   }
   
   # The following pages have javaScript added to periodically auto-refresh 
   # their entire content at 5 second intervals. Since the page data is minimal,
   # this technique results in manageable overhead. 
   elsif ($$Request{PAGE} =~ m/block/i or $$Request{PAGE} =~ m/grade/i or
          $$Request{PAGE} =~ m/sensor/i or $$Request{PAGE} =~ m/signal/i or
          $$Request{PAGE} =~ m/turnout/i) {
      push(@$Array, qq(window.onload = setupRefresh;));
      push(@$Array, qq(function setupRefresh() {));
      push(@$Array, qq(  setTimeout("refreshPage();", 5000); // milliseconds));
      push(@$Array, qq(}));
      push(@$Array, qq(function refreshPage() {));
      push(@$Array, qq(  window.location = location.href;));
      push(@$Array, qq(}));
   }
   push(@$Array, qq(</script>));
   return 0;
}

# =============================================================================
# FUNCTION:  TopPageData
#
# DESCRIPTION:
#    This routine is called to add top page data to the specified array. This
#    is the first page that is output when a user connects. It contains the
#    button controls for accessing the other data pages. 
#
# CALLING SYNTAX:
#    $result = &TopPageData($Array, $Request);
#
# ARGUMENTS:
#    $Array               Pointer to array for records.
#    $Request             Pointer to request data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub TopPageData {
   my($Array, $Request) = @_;
   
   push(@$Array, qq(<div class="TopTitle"><h1>D&amp;B Model Railroad</h1>));
   push(@$Array, qq(<div id="ImageContainer"><img class="TopImage" src=) .
                 qq("loco-490x260RT.gif" alt="loco-490x260RT.gif"></div>));
   push(@$Array, qq(<h4>Select from the following to see additional information.) .
                 qq( &nbsp;</h4></div>));
   &GenNavBar($Array, $Request);
   push(@$Array, qq(</div>));
   push(@$Array, qq(<p class="copy">D&amp;B Model Railroad webserver ));
   push(@$Array, qq(v1.5<br>Copyright &copy; 2020 Don Buczynski));
   return 0;
}

# =============================================================================
# FUNCTION:  BlockPageData
#
# DESCRIPTION:
#    This routine is called to write the block detector related HTML and 
#    data to the specified array. Block detector status is obtained from
#    the sensor.dat file. Refer to the DnB.pl %SensorBit hash.
#
#    sensor.dat       (generated by main loop)
#       Sensor: 32 sensor bits as a numeric value.
#          bit position: 1 = active, 0 = idle.
#
# CALLING SYNTAX:
#    $result = &BlockPageData($Array, $Request);
#
# ARGUMENTS:
#    $Array               Pointer to array for records.
#    $Request             Pointer to request data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub BlockPageData {
   my($Array, $Request) = @_;
   my(@data, @bits);
   my($sensorBits) = 0;                     # No sensor bits set.
   my($bitMask) = 0x1;                      # Start at B01 bit position.
   my($tStr) = strftime "%r", localtime;
   my(%blockDesc) = ('B01' => '1-GPIOA0: Holdover track 1.', 
                     'B02' => '1-GPIOA1: Holdover track 2.',
                     'B03' => '1-GPIOA2: Holdover / Midway transition track.',
                     'B04' => '1-GPIOA3: Midway siding track.',
                     'B05' => '1-GPIOA4: Midway mainline track.',
                     'B06' => '1-GPIOA5: Midway / Wye transition track.',
                     'B07' => '1-GPIOA6: Wye / Yard approach. Yard track 1.',
                     'B08' => '1-GPIOA7: Wye / Yard viaduct approach. Yard track 2.',
                     'B09' => '1-GPIOB0: Yard track 4.',
                     'B10' => '1-GPIOB1: Yard track 3.');

   # Start the HTML page.
   push(@$Array, qq(<div class="BlockTitle"><h1>D&amp;B Block Detector Status</h1>) .
                 qq(</div>));
   push(@$Array, qq(<div class="BlockBack">));
   push(@$Array, qq(<table align="center"><tr><td class="BlockSnap"><b>Snapshot ) .
                 qq(time:</b>&nbsp; $tStr</td></tr><tr><td>&nbsp;</td></tr>) .
                 qq(</table>));
   push(@$Array, qq(<table class="Block"));
   push(@$Array, qq(<colgroup><col width=70px><col width=80px></colgroup>));
   push(@$Array, qq(<tr><th>Block</th><th>State</th><th>Description</th></tr>));

   # Get the sensor bit data from the file.
   unless (&ReadFile("$$Request{SHARE}/sensor.dat", \@data, "NoTrim")) {
      @bits = grep /Sensor:/, @data;
      if ($bits[0] =~ m/^Sensor:\s*(\d+)/) {
         $sensorBits = $1;
      }
   }
   &DisplayDebug(1, "BlockPageData, sensorBits: " . sprintf("%0.32b", $sensorBits));

   # Build the table records HTML.   
   foreach my $block (sort keys(%blockDesc)) {
      &DisplayDebug(1, "BlockPageData,    bitmask: " . sprintf("%0.32b", $bitMask) .
                       "  $block   And result: " . ($sensorBits & $bitMask));
      if (($sensorBits & $bitMask) != 0) {
         push(@$Array, qq(<tr><td>&nbsp;$block</td><td class="Blu">Active</td>) .
                       qq(<td>$blockDesc{$block}</td></tr>));
      }
      else {
         push(@$Array, qq(<tr><td>&nbsp;$block</td><td class="blu">&nbsp;&nbsp;) .
                       qq(idle</td><td>$blockDesc{$block}</td></tr>));
      }
      $bitMask = $bitMask << 1;  # Move mask to next block bit position.
   }
   
   # Finish the HTML page.
   push(@$Array, qq(</table></div><br><br>));
   &GenNavBar($Array, $Request);
   push(@$Array, qq(</div>));
   return 0;
}

# =============================================================================
# FUNCTION:  GradePageData
#
# DESCRIPTION:
#    This routine is called to write the grade crossing related HTML and data
#    to the specified array. Data is obtained from the grade.dat file. Refer
#    to the DnB.pl %GradeCrossingData hash.
# 
# grade.dat        (generated by ProcessGradeCrossing)
#    GC01: <state>:<lamps>:<gates>:<aprW>:<road>:<aprE>
#    GC02: <state>:<lamps>:<gates>:<aprW>:<road>:<aprE>
#       <state> = 'idle', 'gateLower', 'approach', 'road', 'gateRaise' or 'depart'
#       <lamps> = 'on' or 'off'.
#       <gates> = 'Open', 'Closed', or '- none -'
#       <sensor> = 1 (active>) or 0 (idle). 
#
# CALLING SYNTAX:
#    $result = &GradePageData($Array, $Request);
#
# ARGUMENTS:
#    $Array               Pointer to array for records.
#    $Request             Pointer to request data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub GradePageData {
   my($Array, $Request) = @_;
   my(@data, @gcs, $name, $state, $lamps, $gates, $aprW, $road, $aprE);
   my($tStr) = strftime "%r", localtime;
   my(%gcDesc) = ('GC01' => 'Lakeside shipping.', 
                  'GC02' => 'Columbia Feed Mill.');
   
   # Start the HTML page.
   push(@$Array, qq(<div class="GradeTitle"><h1>D&amp;B Grade Crossing Status) .
                 qq(</h1></div>));
   push(@$Array, qq(<p class="GradeSnap"><b>&nbsp; Snapshot time:</b> &nbsp;) .
                 qq( $tStr</p>));                 
   push(@$Array, qq(<br><table style="font-family:Sans-serif">));
   push(@$Array, qq(<tr><td width=300px>));
  
   # Get the grade crossing data from the file.
   unless (&ReadFile("$$Request{SHARE}/grade.dat", \@data, "NoTrim")) {
      @gcs = grep /GC\d\d: /, @data;

   # Build the table records HTML.   
      foreach my $gc (sort @gcs) {
         chomp($gc);
         &DisplayDebug(1, "GradePageData, gc: '$gc'");

         #  GCxx: <state>:<lamps>:<gates>:<aprW>:<road>:<aprE>
         if ($gc =~ m/(GC\d\d):\s*(.+?):(.+?):(.+?):(\d):(\d):(\d)/) {
            ($name, $state, $lamps, $gates, $aprW, $road, $aprE) = ($1, $2, $3, $4,
                                                                    $5, $6, $7);
            push(@$Array, qq(<div class="GradeData"><table><tr><td align="right">) .
                          qq(<b>Signal:&nbsp;</b></td><td>$name</td></tr>));
            push(@$Array, qq(<tr><td align="right"><b>Location:&nbsp;</b></td>) .
                          qq(<td>$gcDesc{$name}</td></tr>));

            push(@$Array, qq(<tr><td align="right"><b>State:&nbsp;</b></td>) .
                          qq(<td>) . ucfirst($state) . qq(</td></tr>));

            push(@$Array, qq(<tr><td align="right"><b>Lamps:&nbsp;</b></td>) .
                          qq(<td>) . ucfirst($lamps) . qq(</td></tr>));

            push(@$Array, qq(<tr><td align="right"><b>Gates:&nbsp;</b></td>));
            # ---
            if ($gates eq 'none') {
               push(@$Array, qq(<td class="blu">$gates</td></tr>));
            }
            else {
               push(@$Array, qq(<td>) . ucfirst($gates) . qq(</td></tr>));
            }
            # ---
            if ($aprW == 1) {       
               push(@$Array, qq(<tr><td align="right"><b>AprW:&nbsp;</b></td>) .
                             qq(<td class="Blu">Active</td></tr>));
            }
            else {
               push(@$Array, qq(<tr><td align="right"><b>AprW:&nbsp;</b></td>) .
                             qq(<td class="blu">idle</td></tr>));
            }
            # ---
            if ($road == 1) {       
               push(@$Array, qq(<tr><td align="right"><b>Road:&nbsp;</b></td>) .
                             qq(<td class="Blu">Active</td></tr>));
            }
            else {
               push(@$Array, qq(<tr><td align="right"><b>Road:&nbsp;</b></td>) .
                             qq(<td class="blu">idle</td></tr>));
            }
            # ---
            if ($aprE == 1) {       
               push(@$Array, qq(<tr><td align="right"><b>AprE:&nbsp;</b></td>) .
                             qq(<td class="Blu">Active</td></tr>));
            }
            else {
               push(@$Array, qq(<tr><td align="right"><b>AprE:&nbsp;</b></td>) .
                             qq(<td class="blu">idle</td></tr>));
            }
            # ---
            push(@$Array, qq(</table></div><br>));

         }
      }
      # Next table data row.
      @$Array[$#$Array] =~ s#<br>$#</td><td width=200px align="right">#;
   }
   
   # Finish the HTML page.
   push(@$Array, qq(<div id="ImageContainer"><img class="GradeImage" src=) .
                 qq("WigWag.gif" ALT="WigWag.gif"></div>));
   push(@$Array, qq(</td></tr></table><br>));
   &GenNavBar($Array, $Request);
   push(@$Array, qq(</div>));
   return 0;
}

# =============================================================================
# FUNCTION:  SensorPageData
#
# DESCRIPTION:
#    This routine is called to write the sensor related HTML and data to the
#    specified array. Sensor status is obtained from the sensor.dat file. 
#    Refer to the DnB.pl %SensorBit hash.
#
#    sensor.dat       (generated by main loop)
#       Sensor: 32 sensor bits as a numeric value.
#          bit position: 1 = active, 0 = idle.
#
# CALLING SYNTAX:
#    $result = &SensorPageData($Array, $Request);
#
# ARGUMENTS:
#    $Array               Pointer to array for records.
#    $Request             Pointer to request data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub SensorPageData {
   my($Array, $Request) = @_;
   my(@data, @bits);
   my($sensorBits) = 0;                     # No sensor bits set.
   my($bitMask) = 0x10000;                  # Start at S01 bit position.
   my($tStr) = strftime "%r", localtime;
   my(%sensorDesc) = ('S01' => '2-GPIOA0: B03 to holdover entry.',
                      'S02' => '2-GPIOA1: Holdover track 2 exit.',
                      'S03' => '2-GPIOA2: Holdover track 1 exit.',
                      'S04' => '2-GPIOA3: spare.',
                      'S05' => '2-GPIOA4: B04 exit to B03 (Close T05).',
                      'S06' => '2-GPIOA5: B05 exit to B06 (Open T06).',
                      'S07' => '2-GPIOA6: B06 to Wye entry.',
                      'S08' => '2-GPIOA7: B07 to Wye entry via yard track 1.',
                      'S09' => '2-GPIOB0: B08 to Wye entry via yard track 2.', 
                      'S10' => '2-GPIOB1: Holdover track 1 exit yellow.',
                      'S11' => '2-GPIOB2: Holdover track 1 exit red.',
                      'S12' => '2-GPIOB3: Holdover track 2 exit yellow.',
                      'S13' => '2-GPIOB4: Holdover track 2 exit red.');

   # Start the HTML page.
   push(@$Array, qq(<div class="SensorTitle"><h1>D&amp;B Sensor Status</h1></div>));
   push(@$Array, qq(<div class="SensorBack">));
   push(@$Array, qq(<table align="center"><tr><td class="SensorSnap"><b>Snapshot ) .
                 qq(time:</b>&nbsp; $tStr</td></tr><tr><td>&nbsp;</td></tr></table>));
   push(@$Array, qq(<table class="Sensor"));
   push(@$Array, qq(<colgroup><col width=70px><col width=80px></colgroup>));
   push(@$Array, qq(<tr><th>Sensor</th><th>State</th><th>Description</th></tr>));
   
   # Get the sensor bit data from the file.
   unless (&ReadFile("$$Request{SHARE}/sensor.dat", \@data, "NoTrim")) {
      @bits = grep /Sensor:/, @data;
      if ($bits[0] =~ m/^Sensor:\s*(\d+)/) {
         $sensorBits = $1;
      }
   }
   &DisplayDebug(1, "SensorPageData, sensorBits: " . sprintf("%0.32b", $sensorBits));

   # Build the table records HTML.   
   foreach my $sensor (sort keys(%sensorDesc)) {
      &DisplayDebug(1, "SensorPageData,    bitmask: " . sprintf("%0.32b", $bitMask) .
                       "  $sensor");
      if ($sensorDesc{$sensor} =~ m/spare/i) {
         push(@$Array, qq(<tr class="grayout"><td>&nbsp;$sensor</td><td>&nbsp;) .
                       qq(&nbsp;idle</td><td>$sensorDesc{$sensor}</td></tr>));
      }
      elsif (($sensorBits & $bitMask) != 0) {
         push(@$Array, qq(<tr><td>&nbsp;$sensor</td><td class="Blu">Active</td>) .
                       qq(<td>$sensorDesc{$sensor}</td></tr>));
      }
      else {
         push(@$Array, qq(<tr><td>&nbsp;$sensor</td><td class="blu">&nbsp;&nbsp;) .
                       qq(idle</td><td>$sensorDesc{$sensor}</td></tr>));
      }
      $bitMask = $bitMask << 1;  # Move mask to next sensor bit position.
   }
   
   # Finish the HTML page.
   push(@$Array, qq(</table></div><br><br>));
   &GenNavBar($Array, $Request);
   push(@$Array, qq(</div>));
   return 0;
}

# =============================================================================
# FUNCTION:  SignalPageData
#
# DESCRIPTION:
#    This routine is called to write the signal related HTML and data to the
#    specified array. Signal status is obtained from the sensor.dat file.
#    Refer to the DnB.pl %SignalData hash.
#
#    sensor.dat       (generated by main loop)
#       Signal: L01=x,L02=x, ... L12=x
#          x = 'Off', 'Grn', 'Yel', or 'Red'.
#
# CALLING SYNTAX:
#    $result = &SignalPageData($Array, $Request);
#
# ARGUMENTS:
#    $Array               Pointer to array for records.
#    $Request             Pointer to request data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub SignalPageData {
   my($Array, $Request) = @_;
   my(@data, @signals, $sigList, $color);
   my($tStr) = strftime "%r", localtime;
   my(%signalDesc) = ('L01' => '00,01: Holdover to B03 upgrade.',
                      'L02' => '02,03: B04 / B05 to B03 downgrade.',
                      'L03' => '04,05: B03 to B04 upgrade.',
                      'L04' => '06,07: B06 to B04 downgrade.',
                      'L05' => '08,09: B03 to B05 upgrade.',
                      'L06' => '10,11: B06 to B05 downgrade.',
                      'L07' => '12,13: B04 / B05 to B06 upgrade.',
                      'L08' => '14,15: B07 / B08 to B06 downgrade. (sem)',
                      'L09' => '16,17: B06 to B07 upgrade.', 
                      'L10' => '18,19: B09 / B10 to B07 downgrade.',
                      'L11' => '20,21: B06 to B08 upgrade.',
                      'L12' => '22,23: B09 / B10 to B08 downgrade.');

   # Start the HTML page.
   push(@$Array, qq(<div class="SignalTitle"><h1>D&amp;B Signal Status</h1></div>));
   push(@$Array, qq(<div class="SignalBack">));
   push(@$Array, qq(<table align="center"><tr><td class="SignalSnap"><b>Snapshot) .
                 qq( time:</b>&nbsp; $tStr</td></tr><tr><td>&nbsp;</td></tr>) .
                 qq(</table>));
   push(@$Array, qq(<table class="Signal"));
   push(@$Array, qq(<colgroup><col width=70px><col width=70px></colgroup>));
   push(@$Array, qq(<tr><th>Signal</th><th>State</th><th>Description</th></tr>));
   
   # Get the signal data from the file.
   unless (&ReadFile("$$Request{SHARE}/sensor.dat", \@data, "NoTrim")) {
      @signals = grep /Signal:/, @data;
      if ($signals[0] =~ m/^Signal:\s*(.+)/) {
         $sigList = $1;
      }
   }

   # Build the table records HTML.   
   foreach my $signal (sort keys(%signalDesc)) {
      if ($sigList =~ m/$signal=(.{3})/) {
         $color = $1;
      }
      else {
         $color = '===';    # If we don't match.
      }
      
      if ($color =~ m/Red/i) {
         push(@$Array, qq(<tr><td>&nbsp;$signal</td><td class="red">&nbsp;Red</td>) .
                       qq(</td><td>$signalDesc{$signal}</td></tr>));
      }
      elsif ($color =~ m/Yel/i) {
         push(@$Array, qq(<tr><td>&nbsp;$signal</td><td class="yel">&nbsp;Yel</td>) .
                       qq(</td><td>$signalDesc{$signal}</td></tr>));
      }
      elsif ($color =~ m/Grn/i) {
         push(@$Array, qq(<tr><td>&nbsp;$signal</td><td class="grn">&nbsp;Grn</td>) .
                       qq(</td><td>$signalDesc{$signal}</td></tr>));
      }
      elsif ($color =~ m/===/i) {
         push(@$Array, qq(<tr><td>&nbsp;$signal</td><td class="blu">&nbsp;$color) .
                       qq(</td></td><td>$signalDesc{$signal}</td></tr>));
      }
      else {
         push(@$Array, qq(<tr><td>&nbsp;$signal</td><td class="blu">&nbsp;Off</td>) .
                       qq(</td><td>$signalDesc{$signal}</td></tr>));
      }
   }

   # Finish the HTML page.
   push(@$Array, qq(</table></div><br><br>));
   &GenNavBar($Array, $Request);
   push(@$Array, qq(</div>));
   return 0;
}

# =============================================================================
# FUNCTION:  TurnoutPageData
#
# DESCRIPTION:
#    This routine is called to write the turnout related HTML and data to the
#    specified array. Turnout status is obtained from the sensor.dat file. 
#    Refer to the DnB.pl %TurnoutData hash.
#
#    sensor.dat       (generated by main loop)
#       T01=<value1>:<value2>: ... <value8>
#       T02=<value1>:<value2>: ... <value8>
#       ...
#
#       value order = Pos, Rate, Open, Middle, Close, MinPos, MaxPos, Id
#
# CALLING SYNTAX:
#    $result = &TurnoutPageData($Array, $Request);
#
# ARGUMENTS:
#    $Array               Pointer to array for records.
#    $Request             Pointer to request data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub TurnoutPageData {
   my($Array, $Request) = @_;
   my(@data, @tData, @tParm, $html, $x, $pos, $spare);
   my($tStr) = strftime "%r", localtime;

   # Start the HTML page.
   push(@$Array, qq(<div class="TurnoutTitle"><h1>D&amp;B Turnout Status</h1></div>));
   push(@$Array, qq(<div class="TurnoutBack">));
   push(@$Array, qq(<table align="center"><tr><td class="TurnoutSnap"><b>Snapshot ) .
                 qq(time:</b>&nbsp; $tStr<br><br></td></tr></table>));
   push(@$Array, qq(<table class="Turnout"));   
   push(@$Array, qq(<colgroup><col width=45px><col width=45px><col width=45px>));
   push(@$Array, qq(<col width=45px><col width=45px><col width=45px><col width=45px>));
   push(@$Array, qq(<col width=45px><col width=230px></colgroup>));
   
   push(@$Array, qq(<tr><th>Id</th><th>Pos</th><th>Rate</th><th>Open</th>));
   push(@$Array, qq(<th>Midl</th><th>Close</th><th>MinP</th><th>MaxP</th>));
   push(@$Array, qq(<th>Description</th></tr>));
   
   # Get the turnout data from the file.
   unless (&ReadFile("$$Request{SHARE}/sensor.dat", \@data, "NoTrim")) {
      
   # Build the table records HTML.   
      foreach my $tNmbr (1..32) {
         $tNmbr = "0${tNmbr}" if (length($tNmbr) == 1);
         $tNmbr = join('', 'T', $tNmbr);
         @tData = grep /^$tNmbr=/, @data;
         chomp($tData[0]);
         &DisplayDebug(1, "TurnoutPageData, tNmbr: $tNmbr   tData[0]: '$tData[0]'");
         if ($tData[0] =~ m/^$tNmbr=(.+)/) {
            @tParm = split(':', $1);
            if ($tParm[$#tParm] =~ m/spare/i) {                 # Grayout spares
               $html = qq(<tr class="grayout"><td>$tNmbr</td>);
               $spare = 1;
            }
            else {
               $html = qq(<tr><td>$tNmbr</td>);
               $spare = 0;
            }
            for ($x = 0; $x <= $#tParm; $x++) {
               $pos = $tParm[$x] if ($x == 0);  # Copy pos for open/close color check.

               # Account for temperature adjusted pos value.
               if ($x == 2 and $spare == 0 and $pos > ($tParm[$x]-10) and 
                   $pos < ($tParm[$x]+10)) {
                  $html = join('', $html, qq(<td class="red">$tParm[$x]</td>));
               }
               elsif ($x == 3 and $spare == 0 and $pos > ($tParm[$x]-10) and
                      $pos < ($tParm[$x]+10)) {
                  $html = join('', $html, qq(<td class="yel">$tParm[$x]</td>));
               }
               elsif ($x == 4 and $spare == 0 and $pos > ($tParm[$x]-10) and
                      $pos < ($tParm[$x]+10)) {
                  $html = join('', $html, qq(<td class="grn">$tParm[$x]</td>));
               }
               else {
                  $html = join('', $html, qq(<td>$tParm[$x]</td>));
               }
            }
            $html = join('', $html, '</tr>');
            push(@$Array, $html);
         }
      }
   }

   # Finish the HTML page.
   push(@$Array, qq(</table></div><br>));
   &GenNavBar($Array, $Request);
   push(@$Array, qq(</div>));
   return 0;
}

# =============================================================================
# FUNCTION:  MainLiveData
#
# DESCRIPTION:
#    This routine is called to add mainline live data to the specified array.
#    This page displays layout information in near real time in the browser. Java 
#    script is added to the HTML page header to instruct the browser to refresh
#    the overlay images about every two seconds.
#
#    The overlay images are specified as .dat files. The NewConnection code
#    substitutes the current main line specified overlay file when processing
#    the request.  CSS z-index is used to stack the overlays for proper display. 
#
# CALLING SYNTAX:
#    $result = &MainLiveData($Array, $Request);
#
# ARGUMENTS:
#    $Array               Pointer to array for records.
#    $Request             Pointer to request data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub MainLiveData {
   my($Array, $Request) = @_;
   
   push(@$Array, qq(<div class="MainLiveTitle"><h1>D&amp;B Model Railroad Mainline ) .
                 qq(Live</h1></div>));
   push(@$Array, qq(<img class="MainBackImage" src="TrackPlan.png" ) .
                 qq(alt="TrackPlan.png"></div>));
                 
   push(@$Array, qq(<img id="y-Ovr" class="yardImage" src="y-overlay.dat" ) .
                 qq(alt="y-overlay.dat">));
   push(@$Array, qq(<img id="m-Ovr" class="midwayImage" src="m-overlay.dat" ) .
                 qq(alt="m-overlay.dat">));
   push(@$Array, qq(<img id="h-Ovr" class="holdoverImage" src="h-overlay.dat" ) .
                 qq(alt="h-overlay.dat">));
                 
   push(@$Array, qq(<img id="L01-Ovr" class="L01color" src="L01-overlay.dat" ) .
                 qq(alt="L01-overlay.dat">));
   push(@$Array, qq(<img id="L02-Ovr" class="L02color" src="L02-overlay.dat" ) .
                 qq(alt="L02-overlay.dat">));
   push(@$Array, qq(<img id="L03-Ovr" class="L03color" src="L03-overlay.dat" ) .
                 qq(alt="L03-overlay.dat">));
   push(@$Array, qq(<img id="L04-Ovr" class="L04color" src="L04-overlay.dat" ) .
                 qq(alt="L04-overlay.dat">));
   push(@$Array, qq(<img id="L05-Ovr" class="L05color" src="L05-overlay.dat" ) .
                 qq(alt="L05-overlay.dat">));
   push(@$Array, qq(<img id="L06-Ovr" class="L06color" src="L06-overlay.dat" ) .
                 qq(alt="L06-overlay.dat">));
   push(@$Array, qq(<img id="L07-Ovr" class="L07color" src="L07-overlay.dat" ) .
                 qq(alt="L07-overlay.dat">));
   push(@$Array, qq(<img id="L08-Ovr" class="L08color" src="L08-overlay.dat" ) .
                 qq(alt="L08-overlay.dat">));
   push(@$Array, qq(<img id="L09-Ovr" class="L09color" src="L09-overlay.dat" ) .
                 qq(alt="L09-overlay.dat">));
   push(@$Array, qq(<img id="L10-Ovr" class="L10color" src="L10-overlay.dat" ) .
                 qq(alt="L10-overlay.dat">));
   push(@$Array, qq(<img id="L11-Ovr" class="L11color" src="L11-overlay.dat" ) .
                 qq(alt="L11-overlay.dat">));
   push(@$Array, qq(<img id="L12-Ovr" class="L12color" src="L12-overlay.dat" ) .
                 qq(alt="L12-overlay.dat">));
                 
   push(@$Array, qq(<img id="GC01-Ovr" class="GC01Image" src="GC01-overlay.dat" ) .
                 qq(alt="GC01-overlay.dat">));
   push(@$Array, qq(<img id="GC02-Ovr" class="GC02Image" src="GC02-overlay.dat" ) .
                 qq(alt="GC02-overlay.dat">));
   &GenNavBar($Array, $Request);
   push(@$Array, qq(<div class="LiveEndPad">&nbsp;</div>));
   return 0;
}

# =============================================================================
# FUNCTION:  YardLiveData
#
# DESCRIPTION:
#    This routine is called to add yard live data to the specified array. This 
#    page displays layout information in near real time in the browser. Java 
#    script is added to the HTML page header to instruct the browser to refresh
#    the overlay images about every two seconds.
#
#    The yard trackage diagram is divided into multiple sections based upon
#    certain turnouts. The tracks in each section are colored with overlayss
#    using the turnout positions within the section. CSS z-index is used to
#    stack the overlays for proper display. 
#
# CALLING SYNTAX:
#    $result = &MainLiveData($Array, $Request);
#
# ARGUMENTS:
#    $Array               Pointer to array for records.
#    $Request             Pointer to request data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub YardLiveData {
   my($Array, $Request) = @_;
   
   push(@$Array, qq(<div class="YardLiveTitle"><h1>D&amp;B Model Railroad Yard ) .
                 qq(Live</h1></div>));
   push(@$Array, qq(<img class="YardBackImage" src="YardWebBase.png" ) .
                 qq(alt="YardWebBase.png"></div>));
   push(@$Array, qq(<img id="S1-Ovr" class="Yard-S1" src="Yard-S1-overlay.dat" ) .
                 qq(alt="Yard-S1-overlay.dat"></div>));
   push(@$Array, qq(<img id="S2-Ovr" class="Yard-S2" src="Yard-S2-overlay.dat" ) .
                 qq(alt="Yard-S2-overlay.dat"></div>));
   push(@$Array, qq(<img id="S3-Ovr" class="Yard-S3" src="Yard-S3-overlay.dat" ) .
                 qq(alt="Yard-S3-overlay.dat"></div>));
   push(@$Array, qq(<img id="S4-Ovr" class="Yard-S4" src="Yard-S4-overlay.dat" ) .
                 qq(alt="Yard-S4-overlay.dat"></div>));
   push(@$Array, qq(<img id="S5-Ovr" class="Yard-S5" src="Yard-S5-overlay.dat" ) .
                 qq(alt="Yard-S5-overlay.dat"></div>));
   push(@$Array, qq(<img id="S6-Ovr" class="Yard-S6" src="Yard-S6-overlay.dat" ) .
                 qq(alt="Yard-S6-overlay.dat"></div>));
   &GenNavBar($Array, $Request);
   push(@$Array, qq(<div class="LiveEndPad">&nbsp;</div>));
   return 0;
}

# =============================================================================
# FUNCTION:  GenNavBar
#
# DESCRIPTION:
#    This routine is called to add the navigation button HTML to the specified
#    array. The 'Top' page gets the page link buttons. All other pages have the 
#    'Home' and 'Refresh' buttons added to the page link buttons.
# 
#
# CALLING SYNTAX:
#    $result = &GenNavBar($Array, $Request);
#
# ARGUMENTS:
#    $Array               Pointer to array for records.
#    $Request             Pointer to request data hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub GenNavBar {
   my($Array, $Request) = @_;

   if ($$Request{PAGE} =~ m/main/i) {
      push(@$Array, qq(<div class="navGroupLiveMain"><table class="navTable"><tr>));
   }
   elsif ($$Request{PAGE} =~ m/yard/i) {
      push(@$Array, qq(<div class="navGroupLiveYard"><table class="navTable"><tr>));
   }
   else {
      push(@$Array, qq(<div class="navGroup"><table class="navTable"><tr>));
   }
  
   push(@$Array, qq(<td><button><a href="/block" class="navButton">Block</a>) .
                 qq(</button></td>));
   push(@$Array, qq(<td><button><a href="/grade" class="navButton">Grade</a>) .
                 qq(</button></td>));
   push(@$Array, qq(<td><button><a href="/sensor" class="navButton">Sensor</a>) .
                 qq(</button></td>));
   push(@$Array, qq(<td><button><a href="/signal" class="navButton">Signal</a>) .
                 qq(</button></td>));
   push(@$Array, qq(<td><button><a href="/turnout" class="navButton">Turnout</a>) .
                 qq(</button></td>));

   if ($$Request{PAGE} =~ m/top/i) {
      push(@$Array, qq(</tr><tr><td>&nbsp;</td>));
      push(@$Array, qq(<td><button><a href="/main" class="navButton">Main</a>) .
                    qq(</button></td>));
      push(@$Array, qq(<td>&nbsp;</td>));
      push(@$Array, qq(<td><button><a href="/yard" class="navButton">Yard</a>) .
                    qq(</button></td><td>&nbsp;</td>));
   }
   elsif ($$Request{PAGE} =~ m/main/i or $$Request{PAGE} =~ m/yard/i) {
      push(@$Array, qq(</tr><tr><td>&nbsp;</td><td>&nbsp;</td>));
      push(@$Array, qq(<td><button><a href="/top" class="navButton">Home</a>) .
                    qq(</button></td>));
      push(@$Array, qq(<td>&nbsp;</td><td>&nbsp;</td>));
   }
   else {
      push(@$Array, qq(</tr><tr><td><button><a href="/top" class="navButton">) .
                    qq(Home</a></button></td>));
      push(@$Array, qq(<td><button><a href="/main" class="navButton">Main</a>) .
                    qq(</button></td>));
      push(@$Array, qq(<td>&nbsp;</td>));
      push(@$Array, qq(<td><button><a href="/yard" class="navButton">Yard</a>) .
                    qq(</button></td>));
      push(@$Array, qq(<td><button><a href="/$$Request{PAGE}" class="navButton">) .
                    qq(Refresh</a></button></td>));
   }
   push(@$Array, qq(</tr></table></div>));
   return 0;
}

# =============================================================================
# FUNCTION:  ExtractVariables
#
# DESCRIPTION:
#    This routine is called to parse the specified string for URL name/value
#    pairs and return them in the specified hash. Name/value pairs, if any, 
#    begin after the first '?' character. Name and value are seperated by the
#    '=' character. Multiple name/value pairs are '&' seperated.
#
# CALLING SYNTAX:
#    $result = &ExtractVariables($Url, \%Variables);
#
# ARGUMENTS:
#    $Url                 String to process.
#    $Variables           Pointer to hash.
#
# RETURNED VALUES:
#    0 = Success,  1 = Error.
#
# ACCESSED GLOBAL VARIABLES:
#    None.
# =============================================================================
sub ExtractVariables {
   my($Url, $Variables) = @_;
   my($data, @pairs, $name, $value);

   %$Variables = ();
   if ($Url =~ m/^(.+?)\?(.+)/) {
      $data = $2;
      if ($data ne '') {
         @pairs = split('&', $data);
         foreach my $pair (@pairs) {
            if ($pair =~ m/^(.+?)=(.+)$/) {
               $name = $1;
               $value = $2;
               $name =~ s/%(..)/chr(hex($1))/eg;
               $value =~ s/%(..)/chr(hex($1))/eg;
               $$Variables{$name} = $value;
            }
         }
      }
   }
   return 0;
}

return 1;
