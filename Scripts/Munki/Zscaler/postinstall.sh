#!/bin/sh

cd /tmp

binary=$( ls | grep "ZSCALER-" )

sudo sh /tmp/$binary/Contents/MacOS/installbuilder.sh --unattendedmodeui none --userDomain example.com --cloudName example --hideAppUIOnLaunch 1 --mode unattended

sleep 30

sudo rm -R /tmp/$binary

exit 0