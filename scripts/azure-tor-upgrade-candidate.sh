# Date : 20251017
# source filename : azure-tor-upgrade_20251014.sh
# production filename : azure-tor-upgrade_20251017-confluence.sh
# confluence filename : azure-tor-upgrade.sh
# Owner : andrew.nam@nutnaix.com
#- 20250709 : to add interactive prompt for acli host.enter_maintenance_mode_check x.x.x.x
#- rewritten cluster health check with an interactive prompt added
#- 20250522 : check_and_toggle_maintenance_mode added to single node 
#- 20250522 : new host_connected_state and cvm_status functions 
#- 20250523 : grep with -w added 
#- 20250915 : result with check tick or cross
#- 20250923 : function run_ping including prompt if packet missing
#- 20250925 : function new_multinode_MM to include a variable str_duplicates_ahv_ips and associatedAHV
#- 20250925 : function check_all_cvm_host_mm_check is added
#- 20251014 : fixed a variable associatedAHV which incorrectly detects multiple ahv ips
#- 20251015 : added for loop to remove old command output stored into .txt files such as ahvipSysName.txt  lldpctl_sysname.txt local_cvm_ip.txt
#- 20251017 : fixed check_and_toggle_maintenance_mode fn with -w
#- 20251017 : fixed new_genesis_stop_all fn with -w for a variable new_associatedAHV3


#!/bin/bash

# Color definitions
RED='\e[31m'
YELLOW='\e[33m'
NC='\e[0m' # No Color

# Print error messages
print_error() {
    echo -e "${RED}$1${NC}"
}

# Function to print section headers
print_section() {
    echo -e "\n${YELLOW}===== $1 =====${NC}"
}

#--------- Global variable : starts ---------#
# Check if CVM IP is provided as an argument
if [[ -z "$1" ]]; then
    print_error "Usage: $0 <CVM1_IP>"
    print_error "❌ Please provide the CVM1 IP as an argument."
    exit 1
fi

cvm1ip="$1"

# List of staled files to check and delete
files=(
  "/tmp/ahvipSysName.txt"
  "/tmp/lldpctl_sysname.txt"
  "/tmp/local_cvm_ip.txt"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    print_error "List of staled files to check and delete before starting the script"
    echo "✅ Deleting $file..."
    sudo /usr/bin/rm -f "$file"
    echo ""
  else
    echo "$file does not exist. Skipping."
  fi
done

associatedAHV=$(ncli host ls | awk -v ip="$cvm1ip" '$0 ~ "Controller VM Address" && $NF == ip {found=1} found && $0 ~ "Hypervisor Address" {print $NF; found=0}')
hostssh "lldpctl | awk '/SysName/ {print; exit}'" | grep SysName | awk '{print $2}' > /tmp/lldpctl_sysname.txt
entries=$(cat /tmp/lldpctl_sysname.txt)
# duplicates=$(echo "$entries" | sort | uniq -d)
duplicates=$(echo "$entries" | tr ' ' '\n' | sort | uniq -d)

hostssh "lldpctl | grep SysName" > /tmp/ahvipSysName.txt

# Find AHV IPs associated with duplicate SysName entries
associatedAHV_sysname=$(cat /tmp/ahvipSysName.txt | grep -w $associatedAHV -A1 | grep SysName | awk '{print $2}')
duplicates_ahv_ips=$(cat /tmp/ahvipSysName.txt | grep "$associatedAHV_sysname" -B1 | awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {print $2}')
str_duplicates_ahv_ips=$(echo "$duplicates_ahv_ips" | tr '\n' ' ') # Convert to a single string variable
associatedAHV2=$(echo "$str_duplicates_ahv_ips" | awk '{print $2}')  ###<<< wrong
#associatedAHV2=$(echo "$associatedAHV2" | tr '\n' ' ')

node_ip_in_switch=$(grep "$duplicates" /tmp/ahvipSysName.txt -B1 | awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {print $2}')
# filtered_AHV_ips is non associatedAHV in the same switch. It can be empty if single node
#filtered_AHV_ips=$(echo "$node_ip_in_switch" | tr ' ' '\n' | grep -v "$associatedAHV" | tr '\n' ' ')

# node ip list on the cluster - Extract IP addresses from /tmp/ahvipSysName.txt and store them in node_ip variable
node_ip=$(awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {print $2}' /tmp/ahvipSysName.txt | tr '\n' ' ')

# single node in same rack
singlenode_ip_in_switch=$(echo "$node_ip" | tr ' ' '\n' | grep -v -w "$associatedAHV" | tr '\n' ' ')
first_singlenode_ip=$(echo "$singlenode_ip_in_switch" | awk '{print $1}')

another_node_ip_in_switch=""
#--------- Global variable : ends ---------#


#--------- Phase 1 - starts ---------#
#--------- function : the host connection status : starts ---------#
check_host_connected_state_for_cvm_arg() {
    # Extracting connected state for the specific CVM IP
    #connected_state=$(acli host.list | grep "$cvm1ip=$1" | awk '{print $5}')
    connected_state=$(acli host.list | awk -v ip="$cvm1ip" '$9 == ip {print $5}')
    print_error "Checking a connection status for the host with the CVM IP $cvm1ip"
    if [[ "$connected_state" == "True" ]]; then    
        echo "+ ✅ Host for the CVM IP $cvm1ip is in connected state."
        echo ""
    else
        echo "+ ❌ Host for the CVM IP $cvm1ip is NOT in connected state."
        while true; do
            read -p "❌ Do you want to continue? (y/n): " user_choice
            case "$user_choice" in
                [Yy]* ) break ;;
                [Nn]* ) echo "❌ Stopping script as per user request."; exit 1 ;;
                * ) echo "Please answer y (yes) or n (no)." ;;
            esac
            echo ""
        done
    fi
}

check_all_host_connected_state() {
    acli_cvmips=$(acli host.list | awk 'NR>1 {print $9}' | tr '\n' ' ')
    print_error "Checking a connection status for all the hosts in the cluster"
    for ip in $acli_cvmips; do 
        state=$(acli host.list | awk -v ip="$cvm1ip" '$9 == ip {print $5}')
        if [[ "$state" == "True" ]]; then
            echo "+ ✅ Host for the CVM IP $ip is in connected state."
        else
            print_error "❌ Host for the CVM IP $ip is NOT in connected state."
            while true; do
                read -p "❌ Do you want to continue? (y/n): " user_choice
                case "$user_choice" in
                    [Yy]* ) break ;;
                    [Nn]* ) echo "❌ Stopping script as per user request."; exit 1 ;;
                    * ) echo "Please answer y (yes) or n (no)." ;;
                esac
            done
        fi
    done
}

# Run checks
print_section "RESULT Phase 1 : host connection status"
check_host_connected_state_for_cvm_arg
check_all_host_connected_state
echo " "
# Print acli host.list 
acli host.list
echo " "
#--------- function : the host connection status : ends ---------#


#--------- function : cvm status : starts ---------#
check_cvm_arg_status() {
    # Extracting Up states for a specific CVM IP
    #cvm1ip_nodetool_states=($(nodetool -h 0 ring | grep "$cvm1ip" | awk '{print $2}'))
    cvm1ip_nodetool_states=($(nodetool -h 0 ring | grep -w "$cvm1ip" | awk '{print $2}'))
    print_error "Checking a argument CVM status $cvm1ip"
    if [[ "$cvm1ip_nodetool_states" == "Up" ]]; then    
        echo "+ ✅ The CVM IP $cvm1ip is in UP state."
        echo ""
    else
        echo "+ ❌ Host for the CVM IP $cvm1ip is DOWN state."
        echo " "
        ncli host ls | awk -v RS= -v ip="$cvm1ip" '$0 ~ ip'
        while true; do
            read -p "❌ Do you want to continue? (y/n): " user_choice
            case "$user_choice" in
                [Yy]* ) break ;;
                [Nn]* ) echo "❌ Stopping script as per user request."; exit 1 ;;
                * ) echo "Please answer y (yes) or n (no)." ;;
            esac
            echo ""
        done
    fi    
}


check_all_cvm_status() { 
    print_error "Checking all the CVM status in the cluster"
    nodetool_cvmips=$(acli host.list | awk 'NR>1 {print $9}' | tr '\n' ' ')
    # Loop to check cvmip_connected_states
    for node_cvm_ip in $nodetool_cvmips; do 
        host_connected_state=($(nodetool -h 0 ring | grep -w "$node_cvm_ip" | awk '{print $2}'))
        
        if [[ "$host_connected_state" == "Up" ]]; then
            echo "+ ✅ The CVM IP $node_cvm_ip status is Up."
        else
            echo "+ ❌ The CVM IP $node_cvm_ip status is Down."

            # Ask user whether to continue or stop
            while true; do
                read -p "❌ CVM IP $node_cvm_ip is Down. Do you want to continue? (y/n): " user_choice
                case "$user_choice" in
                    [Yy]* ) break ;;  # Continue loop
                    [Nn]* ) echo "❌ Stopping script as per user request."; exit 1 ;;
                    * ) echo "Please answer y (yes) or n (no)." ;;
                esac
            done
        fi
    done
}

# Print nodetool -h 0 ring 
print_section "RESULT Phase 1 : cvm status"
check_cvm_arg_status
check_all_cvm_status
echo " "
acli host.list
#--------- function : cvm status : ends ---------#

#--------- function : check_all_cvm_host_mm_check : starts ---------#
## To check if any CVM or node is in maintenance mode before proceeding with the ToR upgrade ##
check_all_cvm_host_mm_check() {
    # Run acli host.list and save output
    acli host.list > /tmp/acli_host_list.txt

    # Check for any line containing 'False'
    if grep -q 'False' /tmp/acli_host_list.txt; then
        echo "❌ RESULT : One or more nodes are in maintenance mode. Please investigate and resolve the issue!!!"
        # Ask user whether to continue or stop
        while true; do
            read -p "❌ Fault tolerance is 0. Do you want to continue? (y/n): " user_choice
            case "$user_choice" in
                [Yy]* ) break ;;
                [Nn]* ) echo "❌ Stopping script as per user request."; exit 1 ;;
                * ) echo "Please answer y (yes) or n (no)." ;;
            esac
        done
    else
        echo "✅ RESULT : All nodes are healthy. Proceeding..."
    fi
}

print_section "RESULT Phase 1 : cvm and or host MM status check"
check_all_cvm_host_mm_check
echo " "
#--------- function : check_all_cvm_host_mm_check : ends ---------#


#--------- function : ft status : starts ---------#
check_ft_status() {
  # Run the ft status command and store the output
  ft_status_output=$(ncli cluster get-domain-fault-tolerance-status type=rack | grep "Current Fault Tolerance")

  # Check if the output contains "Current Fault Tolerance   : 0"
  if [[ $ft_status_output == *"Current Fault Tolerance   : 0"* ]]; then
    echo "+ ❌ Fault tolerance is 0. Please review the ft status output and take necessary action!!!!"
    echo "$ft_status_output"

    # Ask user whether to continue or stop
    while true; do
      read -p "❌ Fault tolerance is 0. Do you want to continue? (y/n): " user_choice
      case "$user_choice" in
        [Yy]* ) break ;;
        [Nn]* ) echo "❌ Stopping script as per user request."; exit 1 ;;
        * ) echo "Please answer y (yes) or n (no)." ;;
      esac
    done
  else
    echo "+ ✅ Fault tolerance is not 0. No action needed."
    echo "$ft_status_output"
  fi
}

print_section "RESULT Phase 1 : ft status"
check_ft_status
echo " "
#--------- function : ft status : ends ---------#


#--------- Date 20250923 - new function : run ping and format output : starts ---------#
#- new feature : Andrew added prompt if any ping lost -#

run_ping() {
    local source_ip=$1
    local dest_ip=$2

    echo -e "\n${YELLOW}Pinging $dest_ip from $source_ip${NC}"

    if ! ssh "$source_ip" "ping -c 2 $dest_ip" | awk '
        /time=/ {printf "  %s\n", $0}
        /statistics/ {printf "\n%s\n", $0}
        /transmitted/ {printf "%s\n", $0}
        /rtt/ {printf "%s\n", $0}
        /packet loss/ {
            if ($6 != "0%") {
                printf "  %s\n", $0
                exit 1
            }
        }
    '; then
        print_error "❌ Ping failed from $source_ip to $dest_ip or packet loss detected!!!!"

        # Prompt user to continue or exit
        read -rp "Do you want to stop the script? (y/n): " user_choice
        case "$user_choice" in
            [Yy]* )
                print_error "Stopping script as per user request."
                exit 1
                ;;
            * )
                echo "Continuing script..."
                ;;
        esac
    fi
}
#--------- function : run ping and format output : ends ---------#


#--------- Phase 1 - call run_ping() : starts ---------#
print_section "RESULT Phase 1 : External IP from Multicluster State"
external_ip=$(ncli multicluster get-cluster-state | grep External | awk '{print $NF}')
echo "✅ External IP found: $external_ip"

print_section "PCVM IPs"
pcvm_ips=$(ncli multicluster get-cluster-state | grep 'Controller VM IP Addre' | grep -oP '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')
echo "✅ PCVM IPs found:"
echo "$pcvm_ips"

print_section "Pinging External IP: $external_ip"
for svm_ip in $(svmips); do
    run_ping "$svm_ip" "$external_ip"
done

print_section "Pinging PCVM IPs"
for svm_ip in $(svmips); do
    for pcvm_ip in $pcvm_ips; do
        echo -e "\n${YELLOW}Pinging PCVM IP: $pcvm_ip${NC}"
        run_ping "$svm_ip" "$pcvm_ip"
    done
done

print_section "External IPs from Cluster Info"
external_ips=$(ncli cluster info | grep -E 'External IP address|External Data Services' | awk '{print $NF}')
echo "✅ External IPs: $external_ips"

print_section "Pinging External IPs from Cluster Info"
svm_ips=$(svmips)
for svm_ip in $svm_ips; do
    for external_ip in $external_ips; do
        run_ping "$svm_ip" "$external_ip"
    done
done
#--------- Phase 1 - call run_ping() : ends ---------#


echo " "
echo " "
echo " "
echo " "
echo "#--------- Phase 2 - starts ---------# "
echo " "


#--------- Phase 2 - starts ---------#

#--------- variable for node_ip_in_switch: starts ---------#
# 1. $node_ip : has entire node ips
# 2. condition to exclude $node_ip_in_switch from $node_ip

target_ahvip=$(echo "$node_ip" | tr ' ' '\n' | grep -v -E "$(echo $node_ip_in_switch | tr ' ' '|')" | tr '\n' ' ')

# Store the 1st element from target_ahvip into target_ahv1
target_ahv1=$(echo "$target_ahvip" | awk '{print $1}')
target_ahv2=$(echo "$target_ahvip" | awk '{print $2}')



# if multi nodes, Print target_ahvip and target_ahv1 variables
# print_section "RESULT : Target AHV IPs available for pcvm migration"
# echo "+ Target AHV IPs: $target_ahvip"
# echo "+ 1st Target AHV IP: $target_ahv1"
# echo " "
#--------- variable for node_ip_in_switch: ends ---------#



#--------- function - to clean up temporary files : starts ---------#
cleanup() {
    rm -f /tmp/local_cvm_ip.txt /tmp/"$cvm1ip"-mm-status-output.txt /tmp/ncli_host_ls_"$cvm1ip".txt /tmp/ahvipSysName.txt /tmp/lldpctl_sysname.txt  /tmp/"$cvm1ip"-mm-status-output.txt /tmp/ncli_host_ls_"$cvm1ip".txt
}
#--------- function - to clean up temporary files : ends ---------#



#--------- function - local cvm check : starts ---------#
check_cvm_ip() {
    ifconfig | grep "eth0: " -A1 > /tmp/local_cvm_ip.txt
    local_cvm_ip=$(awk 'sub(/inet/,""){print $1}' /tmp/local_cvm_ip.txt)
    
    if [ "$cvm1ip" == "$local_cvm_ip" ]; then
        echo "❌ RESULT : WARNING"
        echo "+ ❌ This is a local CVM $cvm1ip and we will not be able to run this Azure ToR upgrade script."  
        echo "+ ❌ Please log into other CVM in a different rack and run the script!!!!"
        echo " "
        exit 1
    else
        echo "✅ RESULT : You are connected on good CVM to execute the Azure ToR upgrade script"
        echo " "
    fi
}
#--------- function - local cvm check : ends ---------#



#--------- function : single nodes - pcvm migration decision: starts ---------#
#-- This function will be called single node single rack environment.
#-- The function will determine if pcvm exists and then check if target ahv is available for pcvm migration


##-- new function : singlenode_pcvm_migration_decision :ends --##
singlenode_pcvm_migration_decision() {
    echo "-- function : singlenode_pcvm_migration_decision --"

    pcvm_name_check=$(ssh root@$associatedAHV "virsh list --all --title" | grep -i PC | awk '{print $4}')
    
    if [ -n "$pcvm_name_check" ]; then
        echo "+ ✅ pcvm exists on this AHV Node $associatedAHV"

        if [ -n "$first_singlenode_ip" ]; then
            echo "+ ✅ RESULT: The target AHV for pcvm migration is found and PCVM $pcvm_name_check will be migrated to AHV $first_singlenode_ip"
            echo "+ ✅ Argument CVM IP : $cvm1ip"
            echo "+ ✅ $cvm1ip running on AHV IP : $associatedAHV"
            echo "+ Executing: acli vm.migrate \"$pcvm_name_check\" host=\"$first_singlenode_ip\""
            acli vm.migrate "$pcvm_name_check" host="$first_singlenode_ip"

            # Get target host UUID
            target_host_uuid=$(ncli host list | grep -B6 "$first_singlenode_ip" | grep -i "UUID" | awk '{print $3}')
            echo "+ ✅ Target host UUID: $target_host_uuid"

            echo "+ Waiting for migration to complete..."
            timeout=300  # 5 minutes
            interval=10  # check every 10 seconds
            elapsed=0

            while [ $elapsed -lt $timeout ]; do
                current_host_uuid=$(acli vm.get "$pcvm_name_check" | grep " host_uuid" | awk -F'"' '{print $2}')
                echo "+ ✅ Current host UUID: $current_host_uuid"

                if [ "$current_host_uuid" == "$target_host_uuid" ]; then
                    echo "+ ✅ Migration completed successfully to $first_singlenode_ip"
                    break
                fi

                sleep $interval
                elapsed=$((elapsed + interval))
                echo "+ Still waiting... ($elapsed seconds elapsed)"
            done

            if [ $elapsed -ge $timeout ]; then
                echo "❌  Migration did not complete within $timeout seconds."
                return 1
            fi
        else
            echo "+ ❌ WARNING: appropriate target AHV not available. Please investigate further!!!!"
        fi
    else
        print_section "function : single nodes - pcvm migration decision"
        echo "+ RESULT : pcvm does not exist on this AHV Node $associatedAHV"
        echo "+ ✅ No PCVM migration is required!!!"
    fi 
}
##-- new function : singlenode_pcvm_migration_decision :ends --##


#--------- function : single nodes mm decision: starts ---------#
singlenode_MM() {
    echo "-- function : single nodes mm decision --"
    if [ -n "$associatedAHV" ]; then
        echo "+ The 1st Candidate AHV IP for MM : $associatedAHV"
        acli host.enter_maintenance_mode_check $associatedAHV > /tmp/enter_maintenance_mode_check_output_$associatedAHV.txt
        if grep -q 'Ok' /tmp/enter_maintenance_mode_check_output_$associatedAHV.txt; then
            echo "+ ✅ RESULT : enter_maintenance_mode_check passed."
            echo "+ ✅ we will enter the node $associatedAHV into maintenance mode!!!!"
            echo "+ ✅ The command : acli host.enter_maintenance_mode $associatedAHV"
            acli host.enter_maintenance_mode $associatedAHV
            echo " "
            acli host.list > /tmp/host_list_$associatedAHV.txt
            echo "+ ✅ The command : acli host.list for the node $associatedAHV to see its MM status :"
            cat /tmp/host_list_$associatedAHV.txt
            echo " "
            #echo ".....consider to add timer !!!!!"
        else
            echo "+ ❌ The 1st Candidate AHV IP for MM : $associatedAHV enter_maintenance_mode_check failed" 
            echo "+ ❌ please log into cluster and investigate the cause!!!! "
            exit 1
        fi
    else
        echo "[RESULT Task2.1 No associatedAHV variable found!!!!!!!" 
    fi
}
#--------- function : single node mm decision: ends ---------#


#--------- date 20250925 : multi nodes mm decision: starts ---------#
#- new feature : andrew added guardrail to check a variable str_duplicates_ahv_ips -#

new_multinode_MM() {
    echo "-- function : multi nodes mm decision --" 
    ip_count=$(echo "$str_duplicates_ahv_ips" | wc -w)
    if [ "$ip_count" -eq 2 ]; then
        if [[ " $str_duplicates_ahv_ips " =~ " $associatedAHV " ]]; then
            echo "Two AHV nodes to be entered into MM : $str_duplicates_ahv_ips" 
            for ip in $str_duplicates_ahv_ips; do 
                acli host.enter_maintenance_mode_check $ip > /tmp/enter_maintenance_mode_check_output_"$ip".txt
                if grep -q 'Ok' /tmp/enter_maintenance_mode_check_output_"$ip".txt; then
                    echo "[✅ RESULT Task2.1 acli host enter_maintenance_mode_check test - passed !!!!]" 
                    echo "[ACTION] Entering node $ip into maintenance mode..."
                    acli host.enter_maintenance_mode $ip     
                    acli host.list > /tmp/host_list_filtered_"$ip".txt
                    echo "+ ✅ The command : acli host.list for the node $ip to see its MM status :"
                    cat /tmp/host_list_filtered_"$ip".txt
                    echo " "
                else
                    echo "[❌ RESULT Task2.1 acli host enter_maintenance_mode_check test - failed !!!!]" 
                    echo "[ACTION REQUIRED] Please log into the cluster and investigate the issue."
                    exit 1   
                fi
            done         
        else
            echo "[❌] Expected exactly 2 duplicate AHV IPs, but found $ip_count." 
            echo "[GUIDANCE] Please verify if this is a two-node same-rack condition in the Google Sheet."
            exit 1
        fi    
    fi
}
#--------- new function : multi nodes mm decision: ends ---------#


#--------- function pcvm1_name_check : starts ---------#
pcvm1_name_check() {
    echo "-- function : pcvm1_name_check --"
    echo "+ To check pcvm name we are connecting to AHV host $associatedAHV"
    #pcvm1_name_check=$(ssh root@$associatedAHV "virsh list --all --title" | grep pc_vm | awk '{print $4}')
    pcvm1_name_check=$(ssh root@$associatedAHV "virsh list --all --title" | grep -i PC | awk '{print $4}')
    if [ -n "$pcvm1_name_check" ]; then
        echo " "
        echo "+ ✅ pcvm exists on this AHV Node $associatedAHV"
        echo "+ ✅ pcvm1 name : $pcvm1_name_check"
        return 0  # True (pcvm exists)
    else
        echo "✅ RESULT : pcvm does not exist on this AHV Node $associatedAHV"
        return 1  # False (pcvm does not exist)
    fi    
}
#--------- function pcvm1_name_check : ends ---------#

#--------- function pcvm2_name_check : starts ---------#
pcvm2_name_check() {
    echo "-- function : pcvm2_name_check --"
    associatedAHV2=$(for ip in $str_duplicates_ahv_ips; do
        if [ "$ip" != "$associatedAHV" ]; then
            echo "$ip"
            break
        fi
    done)
    if [ -n $associatedAHV2 ]; then
        echo "+ To check pcvm name we are connecting to AHV host $associatedAHV2"
        #pcvm2_name_check=$(ssh root@$associatedAHV2 "virsh list --all --title" | grep pc_vm | awk '{print $4}')
        pcvm2_name_check=$(ssh root@$associatedAHV2 "virsh list --all --title" | grep -i PC | awk '{print $4}')
        if [ -n "$pcvm2_name_check" ]; then
            # Use awk to get the second element from the filtered list
            associatedAHV2=$(echo "$str_duplicates_ahv_ips" | awk 'NR==2 {print $0}')
            echo "+ ✅ pcvm exists on this AHV Node $associatedAHV2"
            echo "+ ✅ pcvm2 name : $pcvm2_name_check"
            return 0  # True (pcvm exists)
        else
            echo "✅ RESULT : pcvm2 does not exist on this AHV Node"
            return 1  # False (pcvm does not exist)
        fi
    else
        echo "+ AHV host is not found!!!"
    fi    
}
#--------- function pcvm2_name_check : ends ---------#


#-- This function will be called multi nodes single rack environment.
#-- The function will determine if pcvm exists and then check if target ahv is available for pcvm migration


#--------- new function : pcvm1_migration decision : starts ---------#
pcvm1_migration_decision() {
    echo "-- function : pcvm1_migration_decision --"
# Check the variable : pcvm1_existence
# Call the function and store the return value in a variable
    pcvm1_name_check
    pcvm1_existence=$?
    echo "+ ✅ pcvm1 name check function done and result is "$pcvm1_existence""
    if [ $pcvm1_existence -eq 0 ]; then
        echo "✅ Action : pcvm exists so the pcvm migration will be performed!!!!"        
        if [ -n "$target_ahv1" ]; then
            echo "+ ✅ PCVM $pcvm_ip will be migrated to host $target_ahv1"
            echo "+ The command : acli vm.migrate \"$pcvm1_name_check\" host=\"$target_ahv1\" "
            acli vm.migrate $pcvm1_name_check host=$target_ahv1
            # Get target host UUID
            target_host_uuid=$(ncli host list | grep -B6 "$target_ahv1" | grep -i "UUID" | awk '{print $3}')
            echo "+ ✅ Target host UUID: $target_host_uuid"
            echo "+ Waiting for migration to complete..."
            timeout=10  # 10 seconds
            interval=5  # check every 5 seconds
            elapsed=0
            while [ $elapsed -lt $timeout ]; do
                current_host_uuid=$(acli vm.get "$pcvm1_name_check" | grep -E "\s+host_uuid" | awk -F'"' '{print $2}')
                echo "+ ✅ Current host UUID: $current_host_uuid"
                if [ "$current_host_uuid" == "$target_host_uuid" ]; then
                    echo "+ ✅ Migration completed successfully to $target_ahv1"
                    break
                fi
                sleep $interval
                elapsed=$((elapsed + interval))
                echo "+ Still waiting... ($elapsed seconds elapsed)"
            done
            if [ $elapsed -ge $timeout ]; then
                echo "❌  Migration did not complete within $timeout seconds."
                return 1
            fi            
        else
            echo "❌ WARNING : appropriate target ahv not found and not able to proceed pcvm1 migration"
        fi        
    else
        echo "+ ✅ No actions required as pcvm does not exist"
    fi
}
#--------- function : pcvm1_migration decision : ends ---------#

#--------- new function : pcvm2 migration decision: starts ---------#
pcvm2_migration_decision() {
    echo "-- function : pcvm2_migration_decision --"
# Check the variable : pcvm2_existence
# Call the function and store the return value in a variable
    pcvm2_name_check
    pcvm2_existence=$?
    echo "+ ✅ pcvm2 name check function done and result is "$pcvm2_existence""
    if [ $pcvm2_existence -eq 0 ]; then
        echo "✅ Action : pcvm exists so the pcvm migration will be performed!!!!"
        if [ -n "$target_ahv2" ]; then
            echo "+ ✅ PCVM2 will be migrated to host $target_ahv2"
            echo "+ ✅ The command : acli vm.migrate \"$pcvm2_name_check\" host=\"$target_ahv2\" "
            acli vm.migrate $pcvm2_name_check host=$target_ahv2
            # Get target host UUID
            target_host_uuid=$(ncli host list | grep -B6 "$target_ahv2" | grep -i "UUID" | awk '{print $3}')
            echo "+ ✅ Target host UUID: $target_host_uuid"
            echo "+ Waiting for migration to complete..."
            timeout=10  # 10 seconds
            interval=5  # check every 5 seconds
            elapsed=0
            while [ $elapsed -lt $timeout ]; do
                current_host_uuid=$(acli vm.get "$pcvm2_name_check" | grep -E "\s+host_uuid" | awk -F'"' '{print $2}')
                echo "+ Current host UUID: $current_host_uuid"
                if [ "$current_host_uuid" == "$target_host_uuid" ]; then
                    echo "+ ✅ Migration completed successfully to $target_ahv2"
                    break
                fi
                sleep $interval
                elapsed=$((elapsed + interval))
                echo "+ Still waiting... ($elapsed seconds elapsed)"
            done
            if [ $elapsed -ge $timeout ]; then
                echo "❌ Migration did not complete within $timeout seconds."
                return 1
            fi             
        else
            echo "+ ✅ target_ahv2 is not available!"
            echo "+ ✅ Instead, PCVM $pcvm2_ip will be migrated to host $target_ahv1"
            echo "+ The command : acli vm.migrate \"$pcvm2_name_check\" host=\"$target_ahv1\" "
            acli vm.migrate $pcvm2_name_check host=$target_ahv1
            # Get target host UUID
            target_host_uuid=$(ncli host list | grep -B6 "$target_ahv1" | grep -i "UUID" | awk '{print $3}')
            echo "+ Target host UUID: $target_host_uuid"
            echo "+ Waiting for migration to complete..."
            timeout=10  # 10 seconds
            interval=5  # check every 5 seconds
            elapsed=0
            while [ $elapsed -lt $timeout ]; do
                current_host_uuid=$(acli vm.get "$pcvm2_name_check" | grep -E "\s+host_uuid" | awk -F'"' '{print $2}')
                echo "+ Current host UUID: $current_host_uuid"
                if [ "$current_host_uuid" == "$target_host_uuid" ]; then
                    echo "+ ✅ Migration completed successfully to $target_ahv1"
                    break
                fi
                sleep $interval
                elapsed=$((elapsed + interval))
                echo "+ Still waiting... ($elapsed seconds elapsed)"
            done
            if [ $elapsed -ge $timeout ]; then
                echo "❌ Migration did not complete within $timeout seconds."
                return 1
            fi     
            echo " "    
        fi
    else
        echo "+ ✅ No actions required as pcvm does not exist"  
    fi
}
#--------- new function : pcvm2 migration decision: ends ---------#

#--------- new function : virsh pcvm location: starts ---------#
virsh_pcvm_location(){
    ahv_ip_list=$(ncli host ls | grep "Hypervisor Address" | awk '{print $4}')
    echo "-- function : virsh pcvm location --"
    for ip in $ahv_ip_list
    do
      echo "+ Connecting to AHV $ip"
      ssh root@$ip "/usr/bin/virsh list --all --title"
    done
    echo " "
}
#--------- new function : virsh pcvm location: starts ---------#


#--------- new function : cvm mm decision: starts ---------#
check_and_toggle_maintenance_mode() {
    #local cvm1ip="$1"
    local maintenance_mode
    local candidate_cvm_id

    maintenance_mode=$(ncli host ls | grep -w "$cvm1ip" -A7 | grep Maintenance | awk '{print $5}')
    candidate_cvm_id=$(ncli host ls | grep -w "$cvm1ip" -B4 | grep Id | awk -F'::' '{print $2}')

    print_section "[RESULT Task4. cvm MM validation and action]"

    if [[ "$maintenance_mode" == "true" ]]; then
        echo "+ ✅ CVM $cvm1ip is currently under Maintenance Mode!!!!"
        ncli host ls | grep "$cvm1ip" -B4 -A11 > /tmp/ncli_host_ls_"$cvm1ip".txt
        cat /tmp/ncli_host_ls_"$cvm1ip".txt
        rm /tmp/ncli_host_ls_"$cvm1ip".txt
    else
        echo "+ ✅ CVM $cvm1ip is currently NOT under Maintenance Mode."
        echo "+ ✅ Candidate CVM IP for MM : $cvm1ip will be entered maintenance mode now!!!!"
        echo " The command : ncli host edit id=$candidate_cvm_id enable-maintenance-mode=true"
        # Uncomment the line below to actually enable maintenance mode
        ncli host edit id=$candidate_cvm_id enable-maintenance-mode=true
        echo " "
        echo "...processing..."
        #echo "...consider to add timer !!!!!"
        echo " "
        echo "+ ✅ CVM $cvm1ip is Under Maintenance Mode in the output of ncli host ls"
        echo " "
        # Optionally capture output again
        ncli host ls | grep -w "$cvm1ip" -B4 -A11 > /tmp/ncli_host_ls_"$cvm1ip".txt
        echo " "
    fi
}
#--------- new function : cvm mm decision: ends ---------#
   

#--------- new function genesis stop all : starts ---------#
new_genesis_stop_all(){
    print_section "[RESULT Task4 : genesis stop all]"
    echo "-- function : genesis stop all --"
    new_associatedAHV3=$(for ip in $str_duplicates_ahv_ips; do
        if [ "$ip" != "$associatedAHV" ]; then
            echo "$ip"
            break
        fi
    done)
    genesis_candidate_cvmip=$(ncli host ls | grep -w "$new_associatedAHV3" -B3 | grep "Controller VM Address" | awk '{print $5}')
    echo "+ ✅ variable check duplicates_ahv_ips $str_duplicates_ahv_ips + associatedAHV2 : $new_associatedAHV3 + genesis_candidate_cvmip : $genesis_candidate_cvmip"

    if [ -n "$new_associatedAHV3" ]; then
        echo "+ ✅ ssh to target_cvm2 for genesis stop all on $associatedAHV3"
        echo "+ The command : ssh $genesis_candidate_cvmip 'genesis stop all'"
        echo "+ ✅ Genesis service is stopping at CVM IP: $genesis_candidate_cvmip"
        ssh $genesis_candidate_cvmip '/usr/local/nutanix/cluster/bin/genesis stop all'
    else
        echo "+ ✅ AHV host 2 is not found!!! Hence genesis stop all will not be needed!!!"
    fi 
    echo " "
    echo " "
}
#--------- new function genesis stop all : ends ---------#

# if $associatedAHV_sysname is found in $duplicates
if echo "$duplicates" | grep -q "$associatedAHV_sysname"; then
    echo "++++WARNing : This is multi node++++"
    print_section "Pre-requsite check"
    echo "+ Call function to check if the cvm is local cvm."
    check_cvm_ip
    print_section "[✅ RESULT Task1 : Multi nodes are in the same rack]"
    echo "+ ✅ we confirmed Multi nodes are presents in the same rack environment"
    echo "+ ✅ associatedAHV_sysname is $associatedAHV_sysname"
    echo "+ ✅ The associatedAHV_sysname matches with SysName $duplicates which implies multi-nodes are connected to the same MS switch."
    echo "+ ✅ the connected AHV IPs are :"
    echo "$node_ip_in_switch"
    echo " "
    virsh_pcvm_location
    # Call the function for pcvm migration decision
    print_section "[RESULT Task2.1 : PCVM1 existence on 1st AHV node]"
    pcvm1_migration_decision    # 1st pcvm existence check on 1st ahv
    print_section "[RESULT Task2.2 : PCVM2 existence on 2nd AHV node]"  
    pcvm2_migration_decision    # 2nd pcvm existence check on 2nd ahv
    echo " "
    virsh_pcvm_location
    echo " "
    # Call the function for multi node MM
    print_section "[RESULT Task3 : Multi nodes MM]"
    echo "+ call the function multinode_MM to perform node mm decision"
    new_multinode_MM
    # Ensure maintenance mode is toggled before stopping all genesis services
    check_and_toggle_maintenance_mode
    echo " "
    new_genesis_stop_all 
else
    print_section "Pre-requsite check"
    echo "+ Call function to check if the cvm is local cvm."
    check_cvm_ip
    print_section "[RESULT Task1 : Single node in the rack]"
    echo "+ ✅ we confirmed this is a single node single rack environment"
    echo "++ ✅ associatedAHV_sysname is $associatedAHV_sysname"
    print_section "[RESULT Task2 : PCVM existence on a single AHV]"
    singlenode_pcvm_migration_decision
    print_section "[RESULT Task3 : Single nodes MM]"
    echo "+ call the function singlenode_MM to perform node mm decision"
    singlenode_MM
    check_and_toggle_maintenance_mode  
fi

#--- new task1. duplicates_ahv_ips contains associatedAHV : starts ---#


print_section "The script execution completed"
echo " "
#--- new task1. duplicates_ahv_ips contains associatedAHV : ends ---#

#--------- Phase 2 - ends ---------#