# $Id$
##############################################################################
#
#     98_Heating_Control.pm
#     written by Dietmar Ortmann
#     modified by Tobias Faust
#
#     This file is part of fhem.
#
#     Fhem is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 2 of the License, or
#     (at your option) any later version.
#
#     Fhem is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with fhem.  If not, see <http://www.gnu.org/licenses/>.
#
##############################################################################

package main;
use strict;
use warnings;
use POSIX;

sub Time_Control_Update($);

##################################### 
sub
Time_Control_Initialize($)
{
  my ($hash) = @_;

# Consumer
  $hash->{DefFn}   = "Time_Control_Define";
  $hash->{UndefFn} = "Time_Control_Undef";
  $hash->{GetFn}   = "Time_Control_Get";
  $hash->{AttrList}= "loglevel:0,1,2,3,4,5 ".
                        $readingFnAttributes;
}

sub
Time_Control_Get($@)
{
  my ($hash, @a) = @_;
  return "argument is missing" if(int(@a) != 2);

  $hash->{LOCAL} = 1;
  Time_Control_GetUpdate($hash);
  delete $hash->{LOCAL};
  my $reading= $a[1];
  my $value;

  if(defined($hash->{READINGS}{$reading})) {
        $value= $hash->{READINGS}{$reading}{VAL};
  } else {
        return "no such reading: $reading";
  }
  return "$a[0] $reading => $value";
}


sub
Time_Control_Define($$)
{
  my ($hash, $def) = @_;
  # define <name> Time_Control <device> <switching times> <condition|command>
  # define HeizungKueche Time_Control HeizungKueche 19:28:22_20:30:23_20:45:24_20:55:25_21:30:26_21:38:27 set @ desired-temperature %

  my  @a = split("[ \t]+", $def);
 
  return "Usage: define <name> Time_Control <device> <switching times> <condition|command>"
     if(@a < 4);

  my $name       = shift @a;
  my $type       = shift @a;
  my $device     = shift @a;
  my @switchingtimes;
  my $conditionOrCommand = "";
  my @Wochentage = ("Montag","Dienstag","Mittwoch","Donnerstag","Freitag","Samstag","Sonntag");

  return "invalid Device, given Device <$device> not found" if(!$defs{$device});

  #Altlasten bereinigen
  delete($hash->{helper}{CONDITION})         if($hash->{helper}{CONDITION});
  delete($hash->{helper}{COMMAND})           if($hash->{helper}{COMMAND});
  delete($hash->{helper}{SWITCHINGTIMES})    if($hash->{helper}{SWITCHINGTIMES});
  for (my $w=0; $w<@Wochentage; $w++) {
    delete($hash->{"PROFILE ".($w+1).": ".$Wochentage[$w]}) if($hash->{"PROFILE ".($w+1).": ".$Wochentage[$w]});
  }
  delete($hash->{SWITCHINGTIMES});

  for(my $i=0; $i<@a; $i++) {
    #prüfen auf Angabe eines Schaltpunktes
    my @t = split(/\|/, $a[$i]);
    my $anzahl = @t;
    #Log 3, "Switchingtime: $a[$i] => $t[0] -> $t[1]";
    if ( $anzahl ~~ [2,3]) {
      push(@switchingtimes, $a[$i]);
    } else { 
      #der Rest ist das auzuführende Kommando/condition
      $conditionOrCommand = trim(join(" ", @a[$i..@a-1]));
      last; 
    }
  }

  $hash->{NAME}           = $name;
  $hash->{helper}{SWITCHINGTIMES} = join(" ", @switchingtimes); 
  $hash->{DEVICE}         = $device;
  
  if($conditionOrCommand =~  m/^\(.*\)$/g) {         #condition (*)
     $hash->{helper}{CONDITION} = $conditionOrCommand;
  } elsif(length($conditionOrCommand) > 0 ) {
     $hash->{helper}{COMMAND} = $conditionOrCommand;
  }  

  my (@st, @days, $daylist, $time, $temp);
  for(my $i=0; $i<@switchingtimes; $i++) {
    
    @st = split(/\|/, $switchingtimes[$i]);
    if ( @st == 2) {
      $daylist = "1234567"; #jeden Tag/woche ist vordefiniert
      $time    = $st[0];
      $temp    = $st[1];
    } elsif ( @st == 3) {
      $daylist = $st[0];
      $time    = $st[1];
      $temp    = $st[2];
    }

    # nur noch die Einzelteile per regExp testen
    return "invalid daylist in $name <$daylist> 123... | Sa,So,..."
      if(!($daylist =~  m/^(\d){0,7}$/g    ||     $daylist =~  m/^((Sa|So|Mo|Di|Mi|Do|Fr)(,|$)){0,7}$/g      ));

    # Sa, So ... in den Index übersetzen
    my $idx = 0;
    foreach my $day ("Mo","Di","Mi","Do","Fr","Sa","So") {
       $idx++;
       $daylist =~ s/$day/$idx/g;
    }

    # Kommas entfernen
    $daylist =~ s/,//g;
    @days = split("", $daylist);

    # doppelte Tage entfernen
    my %hdays=();
    @hdays{@days}=1;
    #korrekt die Tage sortieren
    @days = sort(SortNumber keys %hdays);

    return "invalid time in $name <$time> HH:MM"
      if(!($time =~  m/^[0-2][0-9]:[0-5][0-9]$/g));
    return "invalid temperature in $name <$temp> 99.9"
      if(!($temp =~  m/^\d{1,2}(\.\d){0,1}$/g));

    for (my $d=0; $d<@days; $d++) {
      #Log 3, "Switchingtime: $switchingtimes[$i] : $days[$d] -> $time -> $temp ";
      $hash->{helper}{SWITCHINGTIME}{$days[$d]}{$time} = $temp;
      $hash->{"PROFILE ".($days[$d]).": ".$Wochentage[$days[$d]-1]} .= sprintf("%s: %.1f°C, ", $time, $temp);
    }
  }

  #desired-temp des Zieldevices auswählen
  if($defs{$device}{TYPE} eq "MAX") {
    $hash->{helper}{DESIRED_TEMP_READING} = "desiredTemperature"
  } else {
    $hash->{helper}{DESIRED_TEMP_READING} = "desired-temp";
  }

  #$hash->{STATE} = 0;
  my $now    = time();
  InternalTimer ($now+30, "Time_Control_Update", $hash, 0);

  readingsBeginUpdate  ($hash);
  readingsBulkUpdate   ($hash, "nextUpdate",   strftime("Heute, %H:%M:%S",localtime($now+30)));
  readingsBulkUpdate   ($hash, "nextValue",    "???");
  readingsBulkUpdate   ($hash, "state",        "waiting...");
  readingsEndUpdate    ($hash, defined($hash->{LOCAL} ? 0 : 1));

  return undef;
}

sub
Time_Control_Undef($$)
{
  my ($hash, $arg) = @_;

  RemoveInternalTimer($hash);
  return undef;
}

sub
Time_Control_Update($)
{
  my ($hash) = @_;
  my $now    = time();
  my $next   = 0;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($now);

  readingsBeginUpdate($hash);

  #my $jetzt = $wday . strftime("_%H:%M:%S",localtime($now));
  my $AktDesiredTemp = ReadingsVal($hash->{DEVICE}, $hash->{helper}{DESIRED_TEMP_READING}, 0);
  my $newDesTemperature = $AktDesiredTemp; #default#
  my $nextDesTemperature = 0;
  my $nextSwitch = 0;
  my $nowSwitch = 0;

  my @days = ($wday..7, 1..$wday-1);
  
  for (my $d=0; $d<@days; $d++) {
    #über jeden Tag
    last if ($nextSwitch > 0);
    foreach my $st (sort (keys %{ $hash->{helper}{SWITCHINGTIME}{$days[$d]} })) {
      #my $wst = $days[$d] . "_" . $st; # den Wochentag davor setzen
      #berechnen, des Schaltpunktes
      my $secondsToSwitch = 3600*(int(substr($st,0,2)) - $hour) +
         60*(int(substr($st,3,2)) - $min ) - $sec;
      # Tagesdiff dazurechnen
      if($wday <= int($days[$d])) {
        $secondsToSwitch += 3600*24*(int($days[$d])-$wday)
      } else {
        $secondsToSwitch += 3600*24*(7-$wday+int($days[$d]))
      }

      #if ($secondsToSwitch < 0) {
      #   $secondsToSwitch += 24*60*60 + 15;
      #}

      $next = time()+$secondsToSwitch;
      #Log 3, "".strftime('%d.%m.%Y %H:%M:%S',localtime($now))." - ".strftime('%d.%m.%Y %H:%M:%S',localtime($next))." -> $hash->{helper}{SWITCHINGTIME}{$days[$d]}{$st}";

      if ($now > $next) {
        $newDesTemperature =  $hash->{helper}{SWITCHINGTIME}{$days[$d]}{$st};
        #Log 3, "temperature------------>$newDesTemperature";
        $nowSwitch = $now;
      } else {
        $nextSwitch = $next;
        $nextDesTemperature = $hash->{helper}{SWITCHINGTIME}{$days[$d]}{$st};
        last;
      }
    }
  }

  if ($nextSwitch eq "") {
     $nextSwitch = $now + 3600;
  }

  my $name = $hash->{NAME};
  my $command;
  
  #Log 3, "NowSwitch: ".strftime('%d.%m.%Y %H:%M:%S',localtime($nowSwitch))." ; AktDesiredTemp: $AktDesiredTemp ; newDesTemperature: $newDesTemperature";
  if ($nowSwitch gt "" && $AktDesiredTemp != $newDesTemperature) {
    if (defined $hash->{helper}{CONDITION}) {
      $command = '{ fhem("set @ '.$hash->{helper}{DESIRED_TEMP_READING}.' %") if' . $hash->{helper}{CONDITION} . '}';
    } elsif (defined $hash->{helper}{COMMAND}) {
      $command = $hash->{helper}{COMMAND};
    } else {
      $command = '{ fhem("set @ '.$hash->{helper}{DESIRED_TEMP_READING}.' %") }';
    }
  }

  if ($command) {
    $command =~ s/@/$hash->{DEVICE}/g;
    $command =~ s/%/$newDesTemperature/g;
    $command = SemicolonEscape($command);
    my $ret = AnalyzeCommandChain(undef, $command);
    Log GetLogLevel($name,3), $ret if($ret);
  }

  

  #Log 3, "nextSwitch=".strftime('%d.%m.%Y %H:%M:%S',localtime($nextSwitch));

  InternalTimer($nextSwitch, "Time_Control_Update", $hash, 0);
  readingsBulkUpdate($hash, "nextUpdate", strftime("%d.%m.%Y %H:%M:%S",localtime($nextSwitch)));
  readingsBulkUpdate($hash, "nextValue", $nextDesTemperature . "°C");
  readingsBulkUpdate($hash, "state", $newDesTemperature."°C");
  readingsEndUpdate($hash, defined($hash->{LOCAL} ? 0 : 1)); 
  
  #$hash->{state} = $newDesTemperature."°C";

  return 1;
}

sub SortNumber {
 if($a < $b)
  { return -1; }
 elsif($a == $b)
  { return 0; }
 else
  { return 1; }
}

1;

=pod
=begin html

<a name="Time_Control"></a>
<h3>Heating Control</h3>

=end html
=begin html_DE

<a name="Time_Control"></a>
<h3>Heating Control</h3>

=end html_DE
=cut