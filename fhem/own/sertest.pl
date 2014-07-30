#!/usr/bin/perl -w
# 
#  Serielle Ausgabe zum AVR-RFM-Modul 
#  					14.08.13 d.s.
#

use Device::SerialPort;

# Set up the serial port tty Raspberry Pi
# 19200, 8N1
my $port = Device::SerialPort->new("/dev/ttyO1");
$port->databits(8);
$port->baudrate(19200);
$port->parity("none");
$port->stopbits(1);

#
my $comand = $ARGV[0];
my $onoff = $ARGV[1];

    
        
        my $serial_out = $port->write("$comand $onoff\r\n");
#           $serial_out = $port->write("$onoff\r\n"); 


