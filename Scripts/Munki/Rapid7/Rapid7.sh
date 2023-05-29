#!/bin/sh

#  Author:  Tobias Almén
#  Version: 1.0
#  Created: 2023-05-29
#
#  Description: This script is used to package the Rapid7 installer into a DMG, create the PLIST and import to Munki.       
#  
#  File name: Rapid7.sh
#
#  Usage: 
#           - Change the `RAPID7_VERSION` var to the new version
#           - Change the `RAPID7_SHORT_VERSION` var to the new short version
#           - In installcheck.sh, change `CURRENT_VERSION` to the new version
#           - In postinstall.sh, add your token to the `--token` flag
#           - Change the ARCHITECTURE var to the new architecture
#           - Change the `MUNKI_REPO` var to the munki repo path locally
#           - Copy the new Rapid7 Zip file to a folder where you execute this script
#           - Run ./Rapid7.sh
#           - Commit and push changes to Git repo
#

RAPID7_VERSION=
RAPID7_SHORT_VERSION=
RAPID7_PATH="${HOME}/Apps-Dev/RAPID7/Rapid7/macOS"
MUNKI_REPO=""
PLISTBUDDY="/usr/libexec/PlistBuddy"
NAME="Rapid7"
ARCHITECTURE="ARM64" # Supported architectures: ARM64, x86-64

if [[ "${ARCHITECTURE}" == "x86-64" ]]; then
  SUPPORTED_ARCH="x86_64"
  AGENT_FOLDER="./Rapid7 v${RAPID7_SHORT_VERSION} - macOS${ARCHITECTURE}"
  AGENT_SCRIPT="agent_control_*_x64.sh"
else
  SUPPORTED_ARCH=$(echo "${ARCHITECTURE}" | tr '[:upper:]' '[:lower:]')
  AGENT_FOLDER="./Rapid7 v${RAPID7_SHORT_VERSION} - MacOS ${ARCHITECTURE}"
  AGENT_SCRIPT=$(echo "agent_control_*_${ARCHITECTURE}.sh" | tr '[:upper:]' '[:lower:]')
fi

echo "${RAPID7_PATH}/${RAPID7_VERSION}"

unzip -o "./Rapid7 Agent v${RAPID7_SHORT_VERSION}.zip"

[[ -d  "${RAPID7_PATH}/${RAPID7_VERSION}" ]] || mkdir -p "${RAPID7_PATH}/${RAPID7_VERSION}"
[[ -d  "${MUNKI_REPO}/pkgs/apps/RAPID7/" ]] || mkdir -p "${MUNKI_REPO}/pkgs/apps/RAPID7/"
[[ -d  "${MUNKI_REPO}/pkgsinfo/apps/RAPID7/" ]] || mkdir -p "${MUNKI_REPO}/pkgsinfo/apps/RAPID7/"

find "${AGENT_FOLDER}" -name "${AGENT_SCRIPT}" -exec mv {} "${RAPID7_PATH}/${RAPID7_VERSION}/RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.sh" \;
sudo chmod u+x "${RAPID7_PATH}/${RAPID7_VERSION}/RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.sh"

cp ./postinstall.sh "${RAPID7_PATH}"
cp ./installcheck.sh "${RAPID7_PATH}"

cd "${RAPID7_PATH}/${RAPID7_VERSION}"

sudo hdiutil create -srcfolder "RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.sh" "RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.dmg"

makepkginfo "${RAPID7_PATH}/${RAPID7_VERSION}/RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.dmg" \
  --name=${NAME}_${SUPPORTED_ARCH} \
  --displayname=${NAME} \
  --category="Computer Management" \
  --developer=Rapid7 \
  --catalog=testing \
  --owner=root \
  --group=admin \
  --mode=go-w \
  --item="RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.sh" \
  --destinationpath="/tmp" \
  --unattended_install \
  --postinstall_script="${RAPID7_PATH}/postinstall.sh" \
  --installcheck_script="${RAPID7_PATH}/installcheck.sh" \
  --supported_architecture="${SUPPORTED_ARCH}" \
  --pkgvers=${RAPID7_VERSION} \
  --iconname="RAPID7-osx.png" \
  > RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.plist


# Replace `installs` key with `receipts` key from pkg from S1 console
makepkginfo RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.sh

# Modify `installer_item_location`
${PLISTBUDDY} -c "Set :installer_item_location 'apps/RAPID7/RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.dmg'" ./RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.plist

# Set uninstallable to False
${PLISTBUDDY} -c "Set :uninstallable bool false" ./RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.plist

# Remove `uninstall_method`
${PLISTBUDDY} -c "Delete :uninstall_method" ./RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.plist

# Remove current `installs` item
${PLISTBUDDY} -c "Delete :installs:0" ./RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.plist

# Remove `installs`
${PLISTBUDDY} -c "Delete :installs" ./RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.plist

# Add empty blocking applications
${PLISTBUDDY} -c "Add :blocking_applications array" ./RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.plist

# Copy DMG and PLIST to Munki repo
cp ./RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.plist "${MUNKI_REPO}/pkgsinfo/apps/RAPID7/"
cp ./RAPID7-${RAPID7_VERSION}-${ARCHITECTURE}.dmg "${MUNKI_REPO}/pkgs/apps/RAPID7/"

# Run makecatalogs
makecatalogs ${MUNKI_REPO}