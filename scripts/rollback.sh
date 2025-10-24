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

# Global array to store CVM IDs that had stopped or maintenance mode set to true
cvm_ids=()
cvm_ips=()
host_ips=()

echo "Getting host information..."
# This can be timed out when Prism is completely DOWN. Need to add timer and give a warning.
ncli_host_list=$(ncli host list)
echo "Getting PCVM information..."
pcvm_ips=$(ncli multicluster get-cluster-state | grep 'Controller VM IP Addre' | grep -oP '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')
pcvm_password=""

get_pcvm_password() {
    local default_password="nutanix/4u"
    local input

    read -s -p "Enter SSH password for PCVMs (default: $default_password): " input
    echo

    if [[ -n "$input" ]]; then
        pcvm_password="$input"
    else
        pcvm_password="$default_password"
    fi
}

run_ping() {
    local source_ip=$1
    local dest_ip=$2

  echo -e "\n${YELLOW}Pinging $dest_ip from $source_ip${NC}"
  ping_output=$(ssh -q "$source_ip" "ping -c 2 $dest_ip")
  packet_loss=$(echo "$ping_output" | awk '/packet loss/ {print $6}')

  if [ "$packet_loss" != "0%" ]; then
      print_error "❌ Ping failed from $source_ip to $dest_ip or packet loss detected: $packet_loss"
  else
      echo "✅ Ping successful from $source_ip to $dest_ip"
  fi
}

test_ping() {
  external_ip=$(ncli multicluster get-cluster-state | grep External | awk '{print $NF}')
  echo "External IP found: $external_ip"

  print_section "PCVM IPs"
  
  echo "PCVM IPs found:"
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
  echo "External IPs: $external_ips"

  print_section "Pinging External IPs from Cluster Info"
  svm_ips=$(svmips)
  for svm_ip in $svm_ips; do
      for external_ip in $external_ips; do
          run_ping "$svm_ip" "$external_ip"
      done
  done
}

start_genesis() {
    echo "Starting Genesis if there are any CVMs with stopped genesis.."
    # Get the list of CVMs that are down
    down_cvm_ips=$(cluster status 2>/dev/null | grep -iE 'CVM: .* Down' | awk '{print $2}')

    # Loop through each IP and run the genesis start command
    for ip in $down_cvm_ips; do
        echo "✅ Starting genesis on $ip..."
        ssh "$ip" '/usr/local/nutanix/cluster/bin/genesis start'
        local host_info
        cvm_id=$(echo "$ncli_host_list" | grep -B4  -w "$ip" | awk -F'::' '/Id[[:space:]]+:/ {print $2}')
        # host_ip=$(echo "$ncli_host_list" | grep -A3 "10.209.101.137" | awk '/Hypervisor Address/ {print $4}')

        # Add the MM info to the global array
        cvm_ids+=("$cvm_id")
        cvm_ips+=("$ip")
        host_ips+=("$host_ip")
    done
}

disable_maintenance_mode() {
    # echo "Checking CVMs for maintenance mode..."

    local host_info
    host_info=$(echo "$ncli_host_list" | grep "Id                        :\\|Under Maintenance Mode")

    echo "$host_info" | paste - - | while IFS=$'\t' read -r id_line maint_line; do
        # Extract the CVM ID (number after '::')
        local cvm_id
        # echo $id_line
        # echo $maint_line
        cvm_id=$(echo "$id_line" | awk -F'::' '{print $2}')
        # Extract the first word after the colon (true/false/null)
        local maint_status
        maint_status=$(echo "$maint_line" | awk -F': ' '{print $2}' | awk '{print $1}')
        if [[ "$maint_status" == "true" ]]; then
            echo "✅ Host with CVM ID $cvm_id is under maintenance. Disabling..."
            ncli host edit id=$cvm_id enable-maintenance-mode=false
            mm_host_info=$(ncli host list id=$cvm_id)
            cvm_ip=$(echo "mm_host_info" | awk '/Controller VM Address/ {print $5}')
            host_ip=$(echo "mm_host_info" | awk '/Hypervisor Address/ {print $4}')
            # Add the MM info to the global array
            cvm_ids+=("$cvm_id")
            cvm_ips+=("$ip")
            host_ips+=("$host_ip")
        fi
    done
}
check_and_enable_metadata_store() {
    local cvm_ids=()
    local metadata_status=()
    local index=0
    while IFS= read -r line; do
        if [[ "$line" == *"Id                        :"* ]]; then
            id=$(echo "$line" | awk -F "::" '{print $2}')
            cvm_ids[$index]=$id
        elif [[ "$line" == *"Metadata store status"* ]]; then
            metadata_status[$index]="$line"
            ((index++))
        fi
    done < <(ncli host list | grep "Id                        :\|Metadata store status")
    for i in "${!metadata_status[@]}"; do
        if [[ "${metadata_status[$i]}" == *"Node is removed from metadata store"* || "${metadata_status[$i]}" == *"Node ready to be added to metadata store"* ]]; then
            echo "✅ Re-enabling metadata store on node ${cvm_ids[$i]}..."
            ncli host enable-metadata-store id="${cvm_ids[$i]}"
        fi
    done
}
check_health_and_enable_metadata_store() {
    local timeout=300  # 5 minutes in seconds
    local interval=30  # check every 30 seconds
    local elapsed=0
    echo "Checking cluster health before enabling metadata store on CVM ID $cvm_id..."
    while true; do
        # Get non-UP components
        unhealthy=$(cluster status 2>/dev/null | grep -i -v up | grep -Eiw 'DOWN|Maintenance')
        if [[ -z "$unhealthy" ]]; then
            check_and_enable_metadata_store
            break
        else
            if (( elapsed >= timeout )); then
                echo "WARNING: Cluster has unhealthy components for more than 5 minutes:"
                echo "$unhealthy"
                echo "❌ Aborting metadata store enable operation."
                read -s -p "Do you want to proceed? (yes/no) " user_input
                if [ "$user_input" != "yes" ]; then
                  print_error "Stopping the script."
                  exit 1
                fi
            fi
            echo "Cluster not healthy yet. Waiting 30 seconds... (Elapsed: $elapsed seconds)"
            sleep $interval
            ((elapsed+=interval))
        fi
    done
}
check_nodetool_ring_health() {
    echo "Starting nodetool ring health check for up to 5 minutes (every 30 seconds)..."
    local duration=300  # total time in seconds
    local interval=30   # interval between checks
    local elapsed=0
    while (( elapsed < duration )); do
        svm_ips=($(svmips))
        ring_output=$(nodetool -h0 ring)
        local all_healthy=true
        for ip in "${svm_ips[@]}"; do
            if ! echo "$ring_output" | grep -qw "$ip"; then
                echo "❌ WARNING: SVM IP $ip is missing from nodetool ring output!"
                all_healthy=false
            else
                node_status=$(echo "$ring_output" | grep -w "$ip" | awk '{print $2}')
                if [[ "$node_status" == "Down" ]]; then
                    echo "❌ WARNING: SVM IP $ip is in Down or Maintenance state!"
                    all_healthy=false
                fi
            fi
        done
        if $all_healthy; then
            echo "✅ All SVM IPs are present and healthy in the ring."
            break
        fi
        sleep $interval
        ((elapsed+=interval))
    done
    #### elapsed time check and give failure message and ask to procceed...
    if ! $all_healthy; then
      print_error "\n❌ Metadata ring health check failed. Please check this out further manually.\nWhen more than 1 CVMs with Metadata disabled, they are enabled one by one so it takes much longer. In that case, you can proceed."
      echo "$ring_output"
      read -p "Do you want to proceed? (yes/no) " user_input
      if [ "$user_input" != "yes" ]; then
        print_error "Stopping the script."
        exit 1
      fi
    fi
}
exit_hosts_in_maintenance_mode() {
    # Get the list of hosts
    local host_list
    local interval=20   # waiting internal between hosts
    host_list=$(acli host.list)
    # Extract lines with "EnteredMaintenanceMode"
    echo "$host_list" | grep "EnteredMaintenanceMode" | while read -r line; do
        # Extract the Hypervisor IP (first column)
        local hypervisor_ip
        hypervisor_ip=$(echo "$line" | awk '{print $1}')
        # Run the command to exit maintenance mode
        echo "✅ Exiting maintenance mode for host: $hypervisor_ip"
        acli host.exit_maintenance_mode "$hypervisor_ip"
        echo "Waiting for 20 sec before bringing up the next AHV host."
        sleep $interval
    done
}
migrate_extra_pcvm() {
    echo "Gathering all host IPs..."
    all_hosts=($(hostips))
    local interval=120   # waiting internal between PCVM
    echo "Collecting PCVM names and their host IPs..."
    mapfile -t pcvm_info < <(acli vm.get \* | grep " name:\|host_name\|NutanixPrismCentral" | grep -v Intel | grep -A2 NutanixPrismCentral | grep " name:\|host_name")
    declare -A host_to_pcvm
    declare -A pcvm_to_host
    declare -A used_dest_hosts
    echo "Parsing VM and host information..."
    for ((i=0; i<${#pcvm_info[@]}; i+=2)); do
        vm_name=$(echo "${pcvm_info[i]}" | awk -F'"' '{print $2}')
        host_ip=$(echo "${pcvm_info[i+1]}" | awk -F'"' '{print $2}')
        if [[ $host_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            pcvm_to_host["$vm_name"]=$host_ip
            host_to_pcvm["$host_ip"]+="$vm_name "
            used_dest_hosts["$host_ip"]=1
        fi
    done
    echo "Checking for hosts with multiple PCVMs..."
    for host in "${!host_to_pcvm[@]}"; do
        pcvms=(${host_to_pcvm[$host]})
        if [ ${#pcvms[@]} -gt 1 ]; then
            echo "⚠️  Host $host has ${#pcvms[@]} PCVMs: ${pcvms[*]}"
            for ((j=1; j<${#pcvms[@]}; j++)); do
                vm=${pcvms[j]}
                for dest_host in "${all_hosts[@]}"; do
                    if [[ -z "${used_dest_hosts[$dest_host]}" ]]; then
                        echo "Migrating $vm from $host to $dest_host..."
                        acli vm.migrate "$vm" host="$dest_host"
                        pcvm_to_host["$vm"]=$dest_host
                        used_dest_hosts["$dest_host"]=1
                        if [ ${#pcvms[@]} -gt $((j+1)) ]; then
                          echo "Waiting for 2 min before the next PCVM migration"
                          sleep $interval
                        fi
                        break
                    fi
                done
            done
        else
            echo "Host $host has 1 or fewer PCVM running."
        fi
    done
    echo "✅ PCVM Distribution process completed."
}
check_fault_tolerance() {
    local max_attempts=10
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt: Checking fault tolerance status..."
        # Run the command and capture output
        local output
        output=$(ncli cluster get-domain-fault-tolerance-status type=rack)
        # Parse and report
        echo "$output" | awk '
        /Component Type/ {component=$NF}
        /Current Fault Tolerance/ {
            if ($NF == 0) {
                print "Component Type with FT = 0: " component
                found_issue=1
            }
        }
        END {
            if (found_issue != 1) {
                print "All components have FT >= 1"
            }
        }'
        # Check if any FT = 0
        if echo "$output" | grep -q "Current Fault Tolerance   : 0"; then
            echo "FT = 0 detected. Waiting 30 seconds before retrying..."
            sleep 30
            ((attempt++))
        else
            echo "✅ All Fault Tolerance is verified as normal."
            break
        fi
    done
    if [ $attempt -gt $max_attempts ]; then
        print_error "❌ FT = 0 persisted after 5 minutes. Please investigate further."
        echo "$output"
    fi
}
# Function to check health of PCVMs
check_pcvm_msp_health() {
    local TIMEOUT=300
    local START_TIME=$(date +%s)
    echo "Checking out the MSP health status"
    while true; do
        local ALL_HEALTHY=true
        for pcvm_ip in ${pcvm_ips}; do
            echo "==========  $pcvm_ip  =========="
            OUTPUT=$(sshpass -p "$pcvm_password" ssh -o StrictHostKeyChecking=no "$pcvm_ip" "/usr/local/nutanix/cluster/bin/mspctl cls health")
            echo "$OUTPUT"
            if echo "$OUTPUT" | grep -q "false"; then
                echo "⚠️ Warning: Some components on $pcvm_ip are not healthy or password is wrong."
                ALL_HEALTHY=false
                break
            fi
        done
        if $ALL_HEALTHY; then
            echo "✅ All components are healthy."
            break
        fi
        local CURRENT_TIME=$(date +%s)
        local ELAPSED=$((CURRENT_TIME - START_TIME))
        if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
            print_error "⏱️ Timeout reached (5 minutes). Exiting."
            break
        fi
        echo "⏳ Waiting 20 seconds before retrying..."
        sleep 20
    done
}
# Function to run kubectl command and check response time
check_kubectl_responses() {
    local success_count=0
    echo "Checking out the Kubernetes health status"
    for pcvm_ip in ${pcvm_ips}; do
        echo "Checking $pcvm_ip..."
        pc_response=$(timeout 10 sshpass -p "$pcvm_password" ssh -o StrictHostKeyChecking=no $pcvm_ip "sudo /usr/bin/kubectl get pods -A")
        # echo $pc_response
	if [[ ${#pc_response} -gt 100 ]] ; then
          ((success_count++))
        fi
    done
    # Wait for all background jobs to finish and count successes
    echo "✅ $success_count PCVM(s) responded with more than 100 letters within 10 seconds."
    if [ "$success_count" -ge 2 ]; then
        echo "🟢 Requirement met: At least 2 PCVMs responded in time."
    else
        print_error "🔴 Requirement NOT met: Fewer than 2 PCVMs responded in time or PCVM password is wrong."
    fi
}
# Receive PCVM SSH password
print_section "🔹 Phase 0 : Gather the PCVM SSH password. Please press enter if you do not have."
get_pcvm_password
# Start with ping test
print_section "🔹 Phase 1 : Ping Test between CVMs, External IP, PCVM IPs and PC External IP"
test_ping
# Start genesis when there is any CVM with Down in "cluster status"
print_section "🔹 Phase 2 : Start genesis when there is any CVM with Down in 'cluster status'"
start_genesis
# Call the function to disable maintenance mode
print_section "🔹 Phase 3 : Disable CVM maintenance mode"
disable_maintenance_mode
# Iterate over each CVM ID in the global array and call the function to enable metadata store
print_section "🔹 Phase 4 : Check Cluster Health and enable Metadata when any CVM is not part of Metadata ring"
check_health_and_enable_metadata_store
# Check out the metadata ring
print_section "🔹 Phase 4.1 : Check out nodetool and confirm all CVMs are in Metadata ring(5 min timeout)"
check_nodetool_ring_health
# Exit host maintenance mode
print_section "🔹 Phase 5 : Disable AHV host maintenance mode. Each host will wait for 20 sec before going to the next to minimize the impact of PCVM migration."
exit_hosts_in_maintenance_mode
# FT check
print_section "🔹 Phase 6 : Check out Fault Tolerance status. If any component is 0, then this will run for 5 min until fails."
check_fault_tolerance
# We don't need to migrate PCVM manually as there is a Anti Affinity rule setup for all PCVMs already. 
# When a host is released from MM, PCVM will be migrated following the affinity rule.
# To avoid multiple PCVMs get migrated at the same time, we give 2 min of interval between host maintenance release.
print_section "🔹 Phase 7 : Distribute PCVMs when there are hosts with more than 1 PCVMs(Interval: 2min)"
migrate_extra_pcvm
# Check PCVM connectivity
print_section "🔹 Phase 7.1 : Ping Test between CVMs, External IP, PCVM IPs and PC External IP again"
test_ping
# Check PCVM health including MSP
print_section "🔹 Phase 8 : SSH to PCVMs and check out MSP health and kubectl responses"
check_pcvm_msp_health
check_kubectl_responses
# Run NCC health checks for PE cluster
print_section "🔹 Phase 9 : Run NCC health checks and if there is any Fail then it gives Warning and exit"
ncc health_checks run_all
# Ask to run ncc health_checks run_all in PC
print_section "🔹 Phase 10 : Script is completed. NCC health_checks cannot be run through SSH session."
print_error "Please run '${YELLOW}ncc health_checks run_all${RED}' from PCVM."
print_error "$pcvm_ips"
