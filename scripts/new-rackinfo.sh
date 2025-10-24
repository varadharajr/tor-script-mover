# date 20251014
# Goal : determienToR SW SysName using ToR SW name on spreadsheet
# Owner : andrew.nam@nutanix.com
# source : SysName_check_v1-1.sh is working rackinfo script and exported to new-rackinfo.sh
# production file name : new-rackinfo.sh

#!/bin/bash

# Color Definitions  
RED='\e[31m'
YELLOW='\e[33m'
NC='\e[0m' # No Color

# Helper Functions   
print_error() {
    echo -e "${RED}$1${NC}"
}

print_section() {
    echo -e "\n${YELLOW}===== $1 =====${NC}"
}

# Argument Check     
if [[ -z "$1" ]]; then
    print_error "Usage: $0 <tor-sw-name>"
    print_error "Please provide the ToR Switch Name from the spreadsheet as an argument."
    exit 1
fi

# Main Logic         
print_section "This script will determine CVM and its AHV IP attached to the same ToR Switch"
echo "+ Please use one of CVM IPs as azure-tor-upgrade.sh script's argument"
echo ""
tor_sw_name="$1"

# Extract rack_uuid
rack_uuid=$(zeus_config_printer | grep "$tor_sw_name" -C2 | grep rack_uuid | awk -F'"' '{print $2}')
if [[ -z "$rack_uuid" ]]; then
    print_error "rack_uuid not found for $tor_sw_name"
    exit 1
fi

# Extract rackable_unit_uuid
rackable_unit_uuid=$(zeus_config_printer | grep "$rack_uuid" -C5 | grep rackable_unit_uuid | awk -F'"' '{print $2}')
if [[ -z "$rackable_unit_uuid" ]]; then
    print_error "rackable_unit_uuid not found for rack_uuid: $rack_uuid"
    exit 1
fi

# Extract controller_vm_backplane_ip
controller_vm_backplane_ip=$(zeus_config_printer | grep "$rackable_unit_uuid" -A4 | grep controller_vm_backplane_ip | awk -F'"' '{print $2}')
if [[ -z "$controller_vm_backplane_ip" ]]; then
    print_error "controller_vm_backplane_ip not found for rackable_unit_uuid: $rackable_unit_uuid"
    exit 1
fi


# Extract AHV IP from ncli host ls
for i in $controller_vm_backplane_ip; do
    ahv_ip=$(ncli host ls | grep "$i" -A4 | grep "Hypervisor Address" | awk '{print $4}')
    echo "+ CVM IP is $i"
    echo "+ its AHV IP is $ahv_ip"
    SysName=$(ssh root@"$ahv_ip" "lldpctl | grep SysName" | awk -F'SysName: *' '{print $2}' | sort | uniq)
    echo ""
    if [[ -z "$SysName" ]]; then
        print_error "SysName not found via LLDP on AHV IP: $ahv_ip"
        exit 1
    fi
done

echo ""
echo "+ ToR Switch Name on Google Sheet : $tor_sw_name"
echo "+ SysName for the ToR Switch Name : $SysName"
echo ""