#!/bin/sh

cd /tmp

binary=$( find . -name "RAPID7-*-*[-.]sh" )

sudo $binary install_start --token yourtokenhere

sleep 5

sudo rm -R /tmp/$binary

exit 0