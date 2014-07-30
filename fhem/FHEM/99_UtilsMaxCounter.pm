##############################################
# $Id: 99_UtilsMaxCounter.pm 2013-04-07 08:00:00 john $
# V 1.01a

package main;

use strict;
use warnings;
use POSIX;

my $DEBUG=1;
my %MaxCounter=();    # hash fuer variablen
my $MaxTimerID="CounterTimer";
my $MaxModule="MaxCounter";



sub MaxCounterRun($);

# --------------------------------------------------
sub UtilsMaxCounter_Initialize($$)
{
  my ($hash) = @_;


  # timer fuer das scanning aktivieren
  RemoveInternalTimer($MaxTimerID);  # wenn schon vorhanden, dann loeschen
  %MaxCounter=(); # hash loeschen falls vorhanden
  if (defined($defs{MaxCounterAT}))
    { fhem("delete MaxCounterAT");}
  fhem("define MaxCounterAT at *00:00:00 {MaxCounterAtDo();;}");
  Log 2,"$MaxModule is starting"  if ($DEBUG == 1); 
}

sub cntDateStr2Serial($) {
   my $datestr = shift;
   my ($yyyy,$mm,$dd,$hh,$mi,$ss) = $datestr =~ /(\d+)-(\d+)-(\d+) (\d+)[:](\d+)[:](\d+)/;
   # months are zero based
   my $t2= fhemTimeLocal($ss, $mi, $hh, $dd, $mm-1, $yyyy-1900);
   return $t2;
}
# --------------------------------------------------
sub MaxCounterAtDo()
{

  Log 2,"MaxCounterAtDo" if ($DEBUG == 1);
  my $strShutter="SHUTTER.BRENNER";  # fix festlegen
  my $hash = $defs{$strShutter};
  my $cntPerDay =ReadingsVal($strShutter,"cntPerDay","0"); 
  my $strState = ReadingsVal($strShutter,"onoff","0");

  my $strCounterDayTime=ReadingsTimestamp($strShutter,"cntPerDay","");
  my $sdCounterDate = cntDateStr2Serial($strCounterDayTime); # string zu sd wandeln

  my $numCountOnTimePerDayHours=ReadingsVal($strShutter,"cntOntimePerDayHours","0");
  my $numCountOnTimeHours=ReadingsVal($strShutter,"cntOntimeHours","0");

  Log 2,"Tageswechsel" if ($DEBUG == 1);
  my $diff=0;
  if ($strState eq "1") {
    Log 2,"Brenner EIN" if ($DEBUG == 1);
     my $sdCurTime = gettimeofday();                         # aktuelle zeit
     $diff = int($sdCurTime - $sdCounterDate);            # zeit diff
     # to do fuer cntOntimePerDayLast
  }
    Log 2,"diff:$diff numCountOnTimePerDayHours:$numCountOnTimePerDayHours";
  $numCountOnTimeHours = ($diff/3600 + $numCountOnTimePerDayHours);
  my $ss=sprintf("%8.4f",$numCountOnTimeHours);
  readingsBeginUpdate($hash);
     readingsBulkUpdate($hash,"cntPerDay",0);     # counts pro Tag laufend, damit wird auch zeitstempel aktualisiert
     readingsBulkUpdate($hash,"cntPerDayLast",$cntPerDay); # counts pro Tag letzter Tag merken

     readingsBulkUpdate($hash,"cntOntimeIncrement",0);     # aktuelles Inkrement
     readingsBulkUpdate($hash,"cntOntimePerDaySeconds",0); # tageslaufzeit in sekunden
     readingsBulkUpdate($hash,"cntOntimePerDay","00:00");  # tageslaufzeit format : 00:00:00
     readingsBulkUpdate($hash,"cntOntimePerDayHours","0"); #  tageslaufzeit nummerisch Stunden 
     readingsBulkUpdate($hash,"cntOntimeHoursLast",$ss); #  gesamtlaufzeit nummerisch Stunden 
   readingsEndUpdate($hash, 1);

}
# --------------------------------------------------

sub cntFmtTime($)
{
  my @t = localtime(shift);
  return sprintf("%02d:%02d:%02d", $t[2]-1, $t[1], $t[0]);
}

# --------------------------------------------------

sub CounterNotify($$$) { 
  my $modul="CounterNotify";
  my ($strShutter,$strOnOff,$strState)=@_;
  InternalTimer(gettimeofday()+1,$MaxTimerID, $strShutter, 0);
}



# --------------------------------------------------
#  define  testme notify ($strShutters):onoff.* { CounterNotify("@","%EVTPART0","%EVTPART1") };
#  .cntStateOld
#  cntOntimeIncrement       - letztes inkrement in Sekunden
#  cntOntimePerDaySeconds   - Einschaltzeit in Sekunden aktueller Tag
#  cntOntimePerDay          - Einschaltzeit Tag formatiert in 00:00:00
#  cntOntimePerDayHours     - Einschaltzeit Tag formatiert in Stunden
#
#  cntPerDay		 - starts pro Tag laufend
#  cntPerDayLast - Starts des letzten Tages 
#
# 2013-04-07 13:28:58 MAX SHUTTER.BRENNER cntPerDay: 0
# 2013-04-07 13:28:58 MAX SHUTTER.BRENNER cntPerDayLast: 0
# 2013-04-07 13:28:58 MAX SHUTTER.BRENNER cntOntimeIncrement: 0
# 2013-04-07 13:28:58 MAX SHUTTER.BRENNER cntOntimePerDaySeconds: 0
# 2013-04-07 13:28:58 MAX SHUTTER.BRENNER cntOntimePerDay: 0
# 2013-04-07 13:28:58 MAX SHUTTER.BRENNER cntOntimePerDayHours: 0


sub CounterTimer($) {
  my $modul="CounterTimer";
  my ($strShutter)=@_;

  my $hash = $defs{$strShutter};
  my $strState = ReadingsVal($strShutter,"onoff","0");
  my $strOnName = "1";
  my $trigger=1;

  my $llevel=GetLogLevel($strShutter, 5); 

  Log $llevel+1,"$modul --------------------------------------";

  # wenn oldvalue noch nicht definiert
  my $strStateOld=ReadingsVal($strShutter,"cntStateOld","?");
  Log $llevel,"$modul.$strShutter strState:$strState strStateOld:$strStateOld";  

  # ------------------ initialisierung
  if ( $strStateOld eq "?") {
     readingsBeginUpdate($hash);

     readingsBulkUpdate($hash,"cntStateOld",$strState); # alten Zustand aktualisieren
     readingsBulkUpdate($hash,"cntPerDay",0);     # counts pro Tag laufend
     readingsBulkUpdate($hash,"cntPerDayLast",0); # counts pro Tag letzter Tag

     readingsBulkUpdate($hash,"cntOntimeIncrement",0); # counts pro Tag letzter Tag
     readingsBulkUpdate($hash,"cntOntimePerDaySeconds",0); # tageslaufzeit in sekunden
     readingsBulkUpdate($hash,"cntOntimePerDay",0); # tageslaufzeit format : 00:00:00
     readingsBulkUpdate($hash,"cntOntimePerDayHours",0); #  tageslaufzeit nummerisch Stunden 
     readingsBulkUpdate($hash,"cntOntimeHoursLast",0); #  gesamtlaufzeit nummerisch Stunden letzter Tag 

     readingsEndUpdate($hash, $trigger);

     Log $llevel,"$modul.$strShutter defined  (strState:$strState)";  
     if ($strState ne $strOnName) {
        return;
     }

  }

  # nur nach aenderung weitermachen
  if ( $strState eq $strStateOld) {
    Log $llevel+1,"$modul.$strShutter no change ($strState)";
    return;
  }

  # zeitstempel letzte aktualisierung vom Startzähler holen
  my $strCounterDayTime=ReadingsTimestamp($strShutter,"cntPerDay","");
  my $cntDay;
  
  # positive Flanke
  if ($strState  eq $strOnName) {
     $cntDay=ReadingsVal($strShutter,"cntPerDay","0")+1; # counter inkrementieren

     readingsBeginUpdate($hash);
     readingsBulkUpdate($hash,"cntStateOld",$strState);  # alten zustand merken
     readingsBulkUpdate($hash,"cntPerDay",$cntDay);       # zaehler aktualisieren
     readingsEndUpdate($hash, $trigger);

     Log $llevel+1,"$modul.$strShutter rising edge (cntDay:$cntDay strState:$strState )";
  }

  # negative Flanke
  else {

     my $sdCounterDate = cntDateStr2Serial($strCounterDayTime); # string zu sd wandeln
     my $sdCurTime = gettimeofday();                         # aktuelle zeit
     my $diff = int($sdCurTime - $sdCounterDate);            # zeit diff

     my $cntRunTimeDay = ReadingsVal($strShutter,"cntOntimePerDaySeconds","0")+$diff; # tageslaufzeit berechnen
     my $cntRunTimeDayFmt = cntFmtTime($cntRunTimeDay);

     readingsBeginUpdate($hash);
     readingsBulkUpdate($hash,"cntStateOld",$strState);  # alten zustand merken
     readingsBulkUpdate($hash,"cntOntimeIncrement",$diff);   # letztes inkrement
     readingsBulkUpdate($hash,"cntOntimePerDaySeconds",$cntRunTimeDay);  # tageslaufzeit in sekunden
     readingsBulkUpdate($hash,"cntOntimePerDay",$cntRunTimeDayFmt);  # tageslaufzeit format : 00:00:00

     my $cntRunTimeDayHour = sprintf("%8.4f",$cntRunTimeDay/3600);  # Stundenzaehler mit Tagesreset
     readingsBulkUpdate($hash,"cntOntimePerDayHours",$cntRunTimeDayHour);  # tageslaufzeit nummerisch Stunden 
     readingsEndUpdate($hash, $trigger);

     Log $llevel+1,"$modul.$strShutter falling edge diff:$diff cntRunTimeDayFmt:$cntRunTimeDayFmt";
  }


}


1;

