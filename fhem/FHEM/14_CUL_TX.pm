##############################################
# $Id: 14_CUL_TX.pm 2407 2013-01-03 12:55:22Z rudolfkoenig $
package main;

# From peterp
# Lacrosse TX3-TH thermo/hygro sensor

use strict;
use warnings;

sub
CUL_TX_Initialize($)
{
  my ($hash) = @_;

  $hash->{Match}     = "^TX..........";        # Need TX to avoid FHTTK
  $hash->{DefFn}     = "CUL_TX_Define";
  $hash->{UndefFn}   = "CUL_TX_Undef";
  $hash->{ParseFn}   = "CUL_TX_Parse";
  $hash->{AttrList}  = "IODev do_not_notify:1,0 ignore:0,1 " .
                        "showtime:1,0 loglevel:0,1,2,3,4,5,6 " .
                        $readingFnAttributes;
}

#############################
sub
CUL_TX_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "wrong syntax: define <name> CUL_TX <code> [corr] [minsecs]"
        if(int(@a) < 3 || int(@a) > 5);

  $hash->{CODE} = $a[2];
  $hash->{corr} = ((int(@a) > 3) ? $a[3] : 0);
  $hash->{minsecs} = ((int(@a) > 4) ? $a[4] : 0);
  $hash->{lastT} =  0;
  $hash->{lastH} =  0;

  $modules{CUL_TX}{defptr}{$a[2]} = $hash;
  $hash->{STATE} = "Defined";
  Log 4, "CUL_TX defined  $a[0] $a[2]";

  return undef;
}

#####################################
sub
CUL_TX_Undef($$)
{
  my ($hash, $name) = @_;
  delete($modules{CUL_TX}{defptr}{$hash->{CODE}})
     if(defined($hash->{CODE}) &&
        defined($modules{CUL_TX}{defptr}{$hash->{CODE}}));
  return undef;
}

###################################
sub
CUL_TX_Parse($$)
{
  my ($hash, $msg) = @_;
  $msg = substr($msg, 1);
  # Msg format: TXTHHXYZXY, see http://www.f6fbb.org/domo/sensors/tx3_th.php
  my @a = split("", $msg);
  my $id2 = hex($a[4]) & 1; #meaning unknown
  my $id3 = (hex($a[3])<<3) + (hex($a[4])>>1);

  if($a[5] ne $a[8] || $a[6] ne $a[9]) {
    Log 4, "CUL_TX $id3 ($msg) data error";
    return "";
  }

  my $def = $modules{CUL_TX}{defptr}{$id3};
  if(!$def) {
    Log 2, "CUL_TX Unknown device $id3, please define it";
    return "UNDEFINED CUL_TX_$id3 CUL_TX $id3" if(!$def);
  }
  my $now = time();

  my $name = $def->{NAME};

  my $ll4 = GetLogLevel($name,4);
  Log $ll4, "CUL_TX $name $id3 ($msg)";

  my ($msgtype, $val);
  my $valraw = ($a[5].$a[6].".".$a[7]);
  my $type = $a[2];
  if($type eq "0") {
    if($now - $def->{lastT} < $def->{minsecs} ) {
      return ""; 
    }
    $def->{lastT} = $now;
    $msgtype = "temperature";
    $val = sprintf("%2.1f", ($valraw - 50 + $def->{corr}) );
    Log $ll4, "CUL_TX $msgtype $name $id3 T: $val F: $id2";

  } elsif ($type eq "E") {
    if($now - $def->{lastH} < $def->{minsecs} ) {
      return ""; 
    }
    $def->{lastH} = $now;
    $msgtype = "humidity";
    $val = $valraw;
    Log $ll4, "CUL_TX $msgtype $name $id3 H: $val F: $id2";

  } else {
    my $ll2 = GetLogLevel($name,4);
    Log $ll2, "CUL_TX $type $name $id3 ($msg) unknown type";
    return "";

  }


  my $state="";
  my $t = ReadingsVal($name, "temperature", undef);
  my $h = ReadingsVal($name, "humidity", undef);
  if(defined($t) && defined($h)) {
    $state="T: $t H: $h";

  } elsif(defined($t)) {
    $state="T: $t";

  } elsif(defined($h)) {
    $state="H: $h";

  }

  readingsBeginUpdate($def);
  readingsBulkUpdate($def, "state", $state);
  readingsBulkUpdate($def, $msgtype, $val);
  readingsEndUpdate($def, 1);

  return $name;
}

1;


=pod
=begin html

<a name="CUL_TX"></a>
<h3>CUL_TX</h3>
<ul>
  The CUL_TX module interprets TX2/TX3 type of messages received by the CUL,
  see also http://www.f6fbb.org/domo/sensors/tx3_th.php.
  This protocol is used by the La Crosse TX3-TH thermo/hygro sensor and other
  wireless themperature sensors. Please report the manufacturer/model of other
  working devices.  <br><br>

  <a name="CUL_TXdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; CUL_TX &lt;code&gt; [corr] [minsecs]</code> <br>

    <br>
    &lt;code&gt; is the code of the autogenerated address of the TX device (0
    to 127)<br>
    corr is a correction factor, which will be added to the value received from
    the device.<br>
    minsecs are the minimum seconds between two log entries or notifications
    from this device. <br>E.g. if set to 300, logs of the same type will occure
    with a minimum rate of one per 5 minutes even if the device sends a message
    every minute. (Reduces the log file size and reduces the time to display
    the plots)
  </ul>
  <br>

  <a name="CUL_TXset"></a>
  <b>Set</b> <ul>N/A</ul><br>

  <a name="CUL_TXget"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="CUL_TXattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#ignore">ignore</a></li><br>
    <li><a href="#do_not_notify">do_not_notify</a></li><br>
    <li><a href="#showtime">showtime</a></li><br>
    <li><a href="#loglevel">loglevel</a></li><br>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
  </ul>
  <br>

  <a name="CUL_TXevents"></a>
  <b>Generated events:</b>
  <ul>
     <li>temperature: $temp</li>
     <li>humidity: $hum</li>
  </ul>
  <br>

</ul>


=end html
=cut
