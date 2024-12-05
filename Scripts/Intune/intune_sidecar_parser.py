#!/usr/bin/python3

#
# Copyright 2024-Present Tobias Almén.
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Credits:
# Iris Yuning Ye

import re
import json
import os
import argparse

from glob import glob

parser = argparse.ArgumentParser(description="Process Intune log files.")
parser.add_argument("--output_file", "-o", type=str, help="The output JSON file path")
args = parser.parse_args()

# Define the input directory and output file paths
input_dir = "/Library/Logs/Microsoft/Intune/"
output_file = args.output_file

# Define the regex pattern for a date
date_pattern = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}:\d{3}")

# Dictionary to store the latest entry for each AppName
latest_entries = {}

# Get all log files in the input directory
log_files = glob(os.path.join(input_dir, "IntuneMDMDaemon*.log"))

# Iterate over all log files
for log_file in log_files:
    print(f"Processing file: {log_file}")
    # Read each log file
    with open(log_file, "r") as file:
        for line in file:
            # Split the line by the '|' delimiter
            fields = [field.strip() for field in line.split("|")]

            # Check if the first field matches the date pattern
            if fields and date_pattern.match(fields[0]):
                # Parse the entry
                entry = {
                    "Date": fields[0],
                    "Service": fields[1] if len(fields) > 1 else "",
                    "Type": fields[2] if len(fields) > 2 else "",
                    "ID": fields[3] if len(fields) > 3 else "",
                    "ServiceType": fields[4] if len(fields) > 4 else "",
                    "Info": fields[5].split(",") if len(fields) > 5 else "",
                }
                # Convert the list of info items to a dictionary
                info_dict = {}
                if entry["Info"]:  # Ensure Info field exists and is not empty
                    for i in entry["Info"]:
                        key_value = i.split(
                            ":", 1
                        )  # Split key-value pair on the first colon
                        if len(key_value) > 1:
                            key = key_value[0].strip()
                            value = key_value[1].strip()

                            # If the key contains a period and no "Message" key exists yet
                            if "." in key and "Message" not in info_dict:
                                parts = key.split(
                                    ".", 1
                                )  # Split the key at the first period
                                info_dict["Message"] = parts[
                                    0
                                ].strip()  # Extract the part before the first period as the message

                                # Modify the key to exclude the "Message" portion and retain its value
                                new_key = parts[
                                    1
                                ].strip()  # Keep the part after the first period as the key
                                info_dict[new_key] = value
                            else:
                                info_dict[key] = value  # Add the rest of the keys as-is

                entry["Info"] = info_dict

                # Ensure only AppDetector entries are processed
                if entry["ServiceType"] == "AppDetector":
                    app_name = info_dict.get("AppName", "")
                    # Update to the latest entry for each AppName
                    if app_name and (
                        app_name not in latest_entries
                        or entry["Date"] > latest_entries[app_name]["Date"]
                    ):
                        latest_entries[app_name] = entry

# Convert the dictionary of latest entries to a list
output_data = list(latest_entries.values())

# Write the deduplicated and filtered data to the output JSON file
with open(output_file, "w") as json_file:
    json.dump(output_data, json_file, indent=4)

print(f"Found {len(output_data)} apps in the logs.")

print(f"Data has been successfully converted to JSON and saved to {output_file}")
