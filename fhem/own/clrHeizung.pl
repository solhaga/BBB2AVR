#!/usr/bin/perl -w
# 
#  Serielle Ausgabe zum AVR-RFM-Modul 
#                                       14.08.13 d.s.
#

use Device::SerialPort;

# Set up the serial port
# 19200, 81N on the USB ftdi driver
my $port = Device::SerialPort->new("/dev/ttyAMA0");
$port->databits(8);
$port->baudrate(19200);
$port->parity("none");
$port->stopbits(1);

#
my $ZiP = "Y";
my $LaP = "W";
my $KW9 = "U";
my $KW3 = "S";
my $onoff = $ARGV[1];

    
    my $serial_out = $port->write("$ZiP\r\n");
sleep(1);
    $serial_out = $port->write("$LaP\r\n");
sleep(1);
    $serial_out = $port->write("$KW9\r\n");
sleep(1);
    $serial_out = $port->write("$KW3\r\n");
