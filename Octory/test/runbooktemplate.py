#!/usr/bin/env python3

import os
import sys
import json
import automationassets

from automationassets import AutomationAssetNotFound
from munki_manifest_generator import main as mmg

webhook = False
# If executed from webhook, load json data and set webhook to True
if len(sys.argv) > 1 :
    data = sys.argv[1].split(",")
    w_data = data[1].replace("RequestBody:","")
    webhook_data = json.loads(w_data)
    webhook = True
    serial = webhook_data['serial']

# get  variables
os.environ['CLIENT_ID'] = automationassets.get_automation_variable("CLIENT_ID")
os.environ['CLIENT_SECRET'] = automationassets.get_automation_variable("CLIENT_SECRET")
os.environ['CONTAINER_NAME'] = automationassets.get_automation_variable("CONTAINER_NAME")
os.environ['AZURE_STORAGE_CONNECTION_STRING'] = automationassets.get_automation_variable("AZURE_STORAGE_CONNECTION_STRING")
os.environ['TENANT_NAME'] = automationassets.get_automation_variable("TENANT_NAME")

groups = [
    {
        "id": "id_of_aad_group_1",
        "name": "name_of_manifest_1",
        "catalog": "catalog_name_1",
        "type": "type_of_group_1"
    },
        {
        "id": "id_of_aad_group_2",
        "name": "name_of_manifest_2",
        "catalog": "catalog_name_2",
        "type": "type_of_group_2"
    }
]

if webhook is True:
	mmg.main(group_list=groups, serial_number=serial)
else:
	mmg.main(group_list=groups)
