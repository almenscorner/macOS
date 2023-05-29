#!/bin/bash

INSTALLED_VERSION=$(sudo grep "Agent Info" /opt/rapid7/ir_agent/components/insight_agent/common/agent.log | tail -n1 | grep -o "Version: [0-9.]\+" | awk '{print $NF}')
CURRENT_VERSION=

if [[ "${INSTALLED_VERSION}" == "${CURRENT_VERSION}" ]]; then
    echo "Rapid7 is up to date"
    exit 1
elif [[ -z "${INSTALLED_VERSION}" ]]; then
    echo "Rapid7 is not installed, installing"
    exit 0
else
    echo "Rapid7 is not up to date, updating"
    exit 0
fi
