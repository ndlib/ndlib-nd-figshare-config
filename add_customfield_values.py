#!/usr/bin/env python3

import json
import os
import pyjq
import glob
import sys
import requests

# return API endpoint for specified environment (production or staging)

def api_base_url( env):
    match env:
        case "production":
            return "https://api.figshare.com/v2/account/institution/"
        case "staging":
            return "https://api.figsh.com/v2/account/institution/"

    print("valid environments are production, staging")
    sys.exit(1)

def parse_id(resp, name):
    record = json.loads(resp.content)
    try:
        jq_string = '.[] | select(.name == "{}").id'.format(name)
        id = pyjq.first(jq_string, record , None)
    except:
        id = None
    return id

# Main Starts Here

#Look for FIGSH_API_TOKEN  token in environment. Exit if absent

TOKEN = os.getenv('FIGSH_API_TOKEN')

if TOKEN == None:
    print("Error: FIGSH_API_TOKEN not set.")
    sys.exit(1)

# check arg count
if len(sys.argv) < 5:
    print("Usage: add_customfield_values.py <env> <group name> <custom field name> <filename>")
    sys.exit(1)

# check that controlled value list file exists

if os.path.isfile(sys.argv[4]) != True:
    print("Error: file ", sys.argv[4], "does not exist")
    sys.exit(1)

# What we need - environment, group namne, custom filed name, and file of custom field values

env = sys.argv[1]
group = sys.argv[2]
field = sys.argv[3]
file = sys.argv[4]

# Construct header for subsequent API calls

headers = {"Authorization": "token " + TOKEN}

# Get group List

resp = requests.get(api_base_url(env) + "groups", headers=headers)
resp.raise_for_status()


#see if we can find the greoup given on the command line- exit if not

group_id = parse_id(resp, group)

if group_id == None:
    print("Error: Group {} not found".format(group))
    sys.exit(1)

print("The Group Id for Group {} is: {}\n".format(group, group_id))

resp = requests.get(api_base_url(env) + "custom_fields?group_id=" + str(group_id), headers=headers)
resp.raise_for_status()

field_id = parse_id(resp, field)

if field_id == None:
    print("Error: Group {} not found".format(field))
    sys.exit(1)

print("The Custom Field Id for Field {} is: {}\n".format(field, field_id))
     
with open(file, 'rb') as fin:
    files = {'external_file': (file, fin)}
    resp = requests.post(api_base_url(env) + "custom_fields/{}/items/upload".format(field_id), files=files, headers=headers)
    resp.raise_for_status()




