#!/bin/sh

#  Author:  Tobias Almén
#  Version: 1.0
#  Created: 2023-05-29
#
#  Description: This script is used to package the Zscaler installer into a DMG, create the PLIST and import to Munki.        
#  
#  File name: Zscaler.sh
#
#  Usage: 
#           - Clone the repo
#           - Change the `ZSCALER_VERSION` var to the new version
#           - Change the `MUNKI_REPO` var to the munki repo path locally
#           - Edit the postinstall.sh script with your own values
#           - Copy the new Zscaler installer to a folder where you execute this script
#           - Run ./Zscaler.sh
#           - Commit and push changes to Git repo
#

ZSCALER_VERSION=${latest_version:=}
ZSCALER_PATH="${HOME}/Apps-Dev/ZSCALER/zscaler/macOS"
MUNKI_REPO=""
PLISTBUDDY="/usr/libexec/PlistBuddy"
NAME="Zscaler"

echo "${ZSCALER_PATH}/${ZSCALER_VERSION}"

[[ -d  "${ZSCALER_PATH}/${ZSCALER_VERSION}" ]] || mkdir -p "${ZSCALER_PATH}/${ZSCALER_VERSION}"
[[ -d  "${MUNKI_REPO}/pkgs/apps/Zscaler/" ]] || mkdir -p "${MUNKI_REPO}/pkgs/apps/Zscaler/"
[[ -d  "${MUNKI_REPO}/pkgsinfo/apps/Zscaler/" ]] || mkdir -p "${MUNKI_REPO}/pkgsinfo/apps/Zscaler/"

mv $(find . -name "Zscaler-osx[_-]*[_-]installer.app") "${ZSCALER_PATH}/${ZSCALER_VERSION}/ZSCALER-${ZSCALER_VERSION}.app"

cp ./postinstall.sh "${ZSCALER_PATH}"
cd "${ZSCALER_PATH}/${ZSCALER_VERSION}"

sudo hdiutil create -srcfolder "ZSCALER-${ZSCALER_VERSION}.app" "ZSCALER-${ZSCALER_VERSION}.dmg"

makepkginfo "${ZSCALER_PATH}/${ZSCALER_VERSION}/ZSCALER-${ZSCALER_VERSION}.dmg" \
  --name=${NAME} \
  --displayname=zScaler \
  --category="Collaboration & Connectivity" \
  --developer=zScaler \
  --catalog=testing \
  --owner=root \
  --group=admin \
  --mode=go-w \
  --item="ZSCALER-${ZSCALER_VERSION}.app" \
  --destinationpath="/tmp" \
  --unattended_install \
  --postinstall_script="${ZSCALER_PATH}/postinstall.sh" \
  --pkgvers=${ZSCALER_VERSION} \
  --iconname="Zscaler-osx.png" \
  > ZSCALER-${ZSCALER_VERSION}.plist


# Replace `installs` key with `receipts` key from pkg from S1 console
makepkginfo ZSCALER-${ZSCALER_VERSION}.app

# Modify `installer_item_location`
${PLISTBUDDY} -c "Set :installer_item_location 'apps/Zscaler/ZSCALER-${ZSCALER_VERSION}.dmg'" ./ZSCALER-${ZSCALER_VERSION}.plist

# Set uninstallable to False
${PLISTBUDDY} -c "Set :uninstallable bool false" ./ZSCALER-${ZSCALER_VERSION}.plist

# Remove `uninstall_method`
${PLISTBUDDY} -c "Delete :uninstall_method" ./ZSCALER-${ZSCALER_VERSION}.plist

# Remove current `installs` item
${PLISTBUDDY} -c "Delete :installs:0" ./ZSCALER-${ZSCALER_VERSION}.plist

# Remove `installs`
${PLISTBUDDY} -c "Delete :installs" ./ZSCALER-${ZSCALER_VERSION}.plist

# Add `installs`
${PLISTBUDDY} -c "Add :installs array" ./ZSCALER-${ZSCALER_VERSION}.plist

${PLISTBUDDY} -c "Add :installs:0:CFBundleIdentifier string 'com.zscaler.installer'" ./ZSCALER-${ZSCALER_VERSION}.plist
${PLISTBUDDY} -c "Add :installs:0:CFBundleName string 'Zscaler'" ./ZSCALER-${ZSCALER_VERSION}.plist
${PLISTBUDDY} -c "Add :installs:0:CFBundleShortVersionString string '${ZSCALER_VERSION}'" ./ZSCALER-${ZSCALER_VERSION}.plist
${PLISTBUDDY} -c "Add :installs:0:CFBundleVersion string '${ZSCALER_VERSION}'" ./ZSCALER-${ZSCALER_VERSION}.plist
${PLISTBUDDY} -c "Add :installs:0:path string '/Applications/Zscaler/Zscaler.app'" ./ZSCALER-${ZSCALER_VERSION}.plist
${PLISTBUDDY} -c "Add :installs:0:type string 'application'" ./ZSCALER-${ZSCALER_VERSION}.plist
${PLISTBUDDY} -c "Add :installs:0:version_comparison_key string 'CFBundleShortVersionString'" ./ZSCALER-${ZSCALER_VERSION}.plist

# Add empty blocking applications
${PLISTBUDDY} -c "Add :blocking_applications array" ./ZSCALER-${ZSCALER_VERSION}.plist

# Copy DMG and PLIST to Munki repo
cp ./ZSCALER-${ZSCALER_VERSION}.plist "${MUNKI_REPO}/pkgsinfo/apps/Zscaler/"
cp ./ZSCALER-${ZSCALER_VERSION}.dmg "${MUNKI_REPO}/pkgs/apps/Zscaler/"

# Run makecatalogs
makecatalogs ${MUNKI_REPO}