#!/bin/bash
# from https://kb.pulsesecure.net/articles/Pulse_Secure_Article/KB25581
# stop pulse access service
# remove local guid from connstore.dat
# restart service
sudo launchctl unload /Library/LaunchDaemons/net.pulsesecure.AccessService.plist
sudo rm -rf "/Library/Application Support/Pulse Secure/Pulse/DeviceId"
sudo sed -i .bak "/guid/d" "/Library/Application Support/Pulse Secure/Pulse/connstore.dat"
sudo launchctl load /Library/LaunchDaemons/net.pulsesecure.AccessService.plist