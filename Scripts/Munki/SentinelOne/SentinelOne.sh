#!/bin/sh

#  Author:  Tobias Almén
#  Version: 1.0
#  Created: 2023-05-29
#
#  Description: This script is used to package the Sentinel One installer into a DMG, create the PLIST and import to Munki.  
#  
#  File name: SentinelOne.sh
#
#  Usage: 
#           - Change the `SENTINELONE_VERSION` var to the new version
#           - Change the `MUNKI_REPO` var to the munki repo path locally
#           - Copy the new Sentinel One installer to a folder where you execute this script
#           - Run ./SentinelOne.sh
#           - Commit and push changes to Git repo
#
#  NOTE! If Sentinel One decideds to change their installed `receipt` on a new release, line 79 MUST be updated with the new packageid.

SENTINELONE_VERSION=${latest_version:=}
SENTINELONE_PATH="${HOME}/Apps-Dev/SentinelOne/Sentinel Agent/macOS"
MUNKI_REPO=""
PLISTBUDDY="/usr/libexec/PlistBuddy"
NAME="SentinelAgent_macos"

echo "${SENTINELONE_PATH}/${SENTINELONE_VERSION}"

[[ -d  "${SENTINELONE_PATH}/${SENTINELONE_VERSION}" ]] || mkdir -p "${SENTINELONE_PATH}/${SENTINELONE_VERSION}"
[[ -d  "${MUNKI_REPO}/pkgs/apps/SentinelOne/" ]] || mkdir -p "${MUNKI_REPO}/pkgs/apps/SentinelOne/"
[[ -d  "${MUNKI_REPO}/pkgsinfo/apps/SentinelOne/" ]] || mkdir -p "${MUNKI_REPO}/pkgsinfo/apps/SentinelOne/"

mv $(find . -name "Sentinel[_-]Release[_-]*.pkg") "${SENTINELONE_PATH}/${SENTINELONE_VERSION}/SentinelOne-${SENTINELONE_VERSION}.pkg"

cp ./postinstall.sh "${SENTINELONE_PATH}"
cd "${SENTINELONE_PATH}/${SENTINELONE_VERSION}"

sudo hdiutil create -srcfolder "SentinelOne-${SENTINELONE_VERSION}.pkg" "SentinelOne-${SENTINELONE_VERSION}.dmg"

makepkginfo "${SENTINELONE_PATH}/${SENTINELONE_VERSION}/SentinelOne-${SENTINELONE_VERSION}.dmg" \
  --name=${NAME} \
  --displayname=SentinelOne \
  --category=Security \
  --developer=SentinelOne \
  --catalog=testing \
  --owner=root \
  --group=admin \
  --mode=go-w \
  --item="SentinelOne-${SENTINELONE_VERSION}.pkg" \
  --destinationpath="/tmp" \
  --unattended_install \
  --postinstall_script="${SENTINELONE_PATH}/postinstall.sh" \
  --pkgvers=${SENTINELONE_VERSION} \
  > SentinelOne-${SENTINELONE_VERSION}.plist


# Replace `installs` key with `receipts` key from pkg from S1 console
makepkginfo SentinelOne-${SENTINELONE_VERSION}.pkg

# Modify `installer_item_location`
${PLISTBUDDY} -c "Set :installer_item_location 'apps/SentinelOne/SentinelOne-${SENTINELONE_VERSION}.dmg'" ./SentinelOne-${SENTINELONE_VERSION}.plist

# Set uninstallable to False
${PLISTBUDDY} -c "Set :uninstallable bool false" ./SentinelOne-${SENTINELONE_VERSION}.plist

# Remove `uninstall_method`
${PLISTBUDDY} -c "Delete :uninstall_method" ./SentinelOne-${SENTINELONE_VERSION}.plist

# Remove current `installs` item
${PLISTBUDDY} -c "Delete :installs:0" ./SentinelOne-${SENTINELONE_VERSION}.plist

# Remove `installs`
${PLISTBUDDY} -c "Delete :installs" ./SentinelOne-${SENTINELONE_VERSION}.plist

# Add `reciepts`
${PLISTBUDDY} -c "Add :receipts array" ./SentinelOne-${SENTINELONE_VERSION}.plist

# Set `receipts` array configurations
${PLISTBUDDY} -c "Add :receipts:0:optional bool false" ./SentinelOne-${SENTINELONE_VERSION}.plist
${PLISTBUDDY} -c "Add :receipts:0:packageid string 'com.sentinelone.pkg.sentinel-agent'" ./SentinelOne-${SENTINELONE_VERSION}.plist
${PLISTBUDDY} -c "Add :receipts:0:version string '${SENTINELONE_VERSION}'" ./SentinelOne-${SENTINELONE_VERSION}.plist

# Copy DMG and PLIST to Munki repo
cp ./SentinelOne-${SENTINELONE_VERSION}.plist "${MUNKI_REPO}/pkgsinfo/apps/SentinelOne/"
cp ./SentinelOne-${SENTINELONE_VERSION}.dmg "${MUNKI_REPO}/pkgs/apps/SentinelOne/"

# Run makecatalogs
makecatalogs ${MUNKI_REPO}
