#!/bin/bash

REGISTRATION_TOKEN=""

echo "${REGISTRATION_TOKEN}" > /private/tmp/com.sentinelone.registration-token

INSTALL_PKG=$(find /private/tmp -name "SentinelOne-*.pkg" | tail -1)

if [[ -e /usr/local/bin/sentinelctl ]]; then
  /usr/local/bin/sentinelctl upgrade-pkg "${INSTALL_PKG}"
else
  installer -pkg "${INSTALL_PKG}" -target /
fi