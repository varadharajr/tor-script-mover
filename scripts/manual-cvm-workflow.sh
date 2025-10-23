#!/bin/bash

# Manual CVM Workflow Script
# This script demonstrates the manual workflow from AHV host to CVM
# Usage: ./manual-cvm-workflow.sh

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CVM_IP="192.168.5.2"
CVM_USER="nutanix"
CVM_TMP_DIR="/home/nutanix/tmp"
TEST_FILE="test-$(date +%Y%m%d).txt"

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] ${message}${NC}"
}

print_error() {
    print_status "$RED" "ERROR: $1"
}

print_success() {
    print_status "$GREEN" "SUCCESS: $1"
}

print_info() {
    print_status "$BLUE" "INFO: $1"
}

print_warning() {
    print_status "$YELLOW" "WARNING: $1"
}

# Function to create test file
create_test_file() {
    print_info "Creating test file: $TEST_FILE"
    
    cat > "/tmp/$TEST_FILE" << EOF
# Test File Created on $(date)
# This file was created to test the manual CVM workflow
# File: $TEST_FILE
# Created by: $(whoami)
# Host: $(hostname)
# Date: $(date)

This is a test file to demonstrate the manual workflow from AHV host to CVM.
The workflow includes:
1. Creating a test file
2. SCP to CVM
3. SSH to CVM
4. Verify file transfer

Workflow completed successfully!
EOF

    print_success "Test file created: /tmp/$TEST_FILE"
}

# Function to copy file to CVM
copy_file_to_cvm() {
    print_info "Copying file to CVM..."
    print_info "Command: scp /tmp/$TEST_FILE $CVM_USER@$CVM_IP:$CVM_TMP_DIR/"
    
    if scp "/tmp/$TEST_FILE" "$CVM_USER@$CVM_IP:$CVM_TMP_DIR/"; then
        print_success "File copied successfully to CVM"
    else
        print_error "Failed to copy file to CVM"
        print_info "Please check:"
        print_info "1. CVM is accessible at $CVM_IP"
        print_info "2. SSH keys are properly configured"
        print_info "3. You have proper permissions to access the CVM"
        exit 1
    fi
}

# Function to SSH to CVM and verify file
ssh_to_cvm_and_verify() {
    print_info "SSH to CVM and verify file transfer..."
    print_info "Command: ssh $CVM_USER@$CVM_IP"
    
    # Create a temporary script to run on CVM
    local temp_script
    temp_script=$(mktemp)
    
    cat > "$temp_script" << EOF
#!/bin/bash
set -euo pipefail

# Function to print colored output
print_status() {
    local color=\$1
    local message=\$2
    echo -e "\${color}[\$(date '+%Y-%m-%d %H:%M:%S')] \${message}\033[0m"
}

print_success() {
    print_status "\033[0;32m" "SUCCESS: \$1"
}

print_info() {
    print_status "\033[0;34m" "INFO: \$1"
}

print_info "Connected to CVM. Verifying file transfer..."

# Change to tmp directory
cd $CVM_TMP_DIR

print_info "Current directory: \$(pwd)"
print_info "Listing files in $CVM_TMP_DIR:"
ls -al

# Check if our test file exists
if [ -f "$TEST_FILE" ]; then
    print_success "Test file found: $TEST_FILE"
    print_info "File details:"
    ls -al "$TEST_FILE"
    print_info "File contents:"
    cat "$TEST_FILE"
else
    print_error "Test file not found: $TEST_FILE"
    exit 1
fi

print_success "File verification completed successfully!"
print_info "Manual workflow demonstration completed!"

EOF

    # Execute the script on CVM
    if ssh "$CVM_USER@$CVM_IP" "bash -s" < "$temp_script"; then
        print_success "CVM verification completed successfully"
    else
        print_error "Failed to verify file on CVM"
        rm -f "$temp_script"
        exit 1
    fi
    
    # Clean up
    rm -f "$temp_script"
}

# Function to SSH to CVM and stay in session
ssh_to_cvm_and_stay() {
    print_info "SSH to CVM and stay in session..."
    print_info "Command: ssh $CVM_USER@$CVM_IP"
    print_info ""
    print_info "=========================================="
    print_success "WORKFLOW COMPLETED SUCCESSFULLY!"
    print_info "=========================================="
    print_success "✅ Test file created: $TEST_FILE"
    print_success "✅ File copied to CVM: $CVM_USER@$CVM_IP:$CVM_TMP_DIR/"
    print_success "✅ File verified on CVM: $CVM_TMP_DIR/$TEST_FILE"
    print_success "✅ CVM connection established"
    print_info ""
    print_info "📁 File Details:"
    print_info "   • File name: $TEST_FILE"
    print_info "   • Location: $CVM_TMP_DIR/$TEST_FILE"
    print_info "   • CVM IP: $CVM_IP"
    print_info "   • CVM User: $CVM_USER"
    print_info ""
    print_info "🔧 Next Steps:"
    print_info "   1. You are now connected to the CVM"
    print_info "   2. Change to tmp directory: cd $CVM_TMP_DIR"
    print_info "   3. List files: ls -al"
    print_info "   4. View file details: ls -al $TEST_FILE"
    print_info "   5. View file contents: cat $TEST_FILE"
    print_info ""
    print_info "🚀 Ready to work with files on CVM!"
    print_info "=========================================="
    
    # SSH into CVM and stay in the session
    ssh "$CVM_USER@$CVM_IP"
    
    print_info "CVM session ended"
}

# Function to clean up test file
cleanup() {
    print_info "Cleaning up test file..."
    if [ -f "/tmp/$TEST_FILE" ]; then
        rm -f "/tmp/$TEST_FILE"
        print_success "Test file cleaned up"
    fi
}

# Function to display usage information
show_usage() {
    cat << EOF
Manual CVM Workflow Script

USAGE:
    ./manual-cvm-workflow.sh

DESCRIPTION:
    This script demonstrates the manual workflow from AHV host to CVM:
    1. Creates a test file in /tmp/
    2. Copies the file to CVM using SCP
    3. SSH into the CVM
    4. Changes to /home/nutanix/tmp directory
    5. Lists files to verify the transfer
    6. Shows file contents
    7. Cleans up the test file

PREREQUISITES:
    - SSH access to CVM at 192.168.5.2
    - Proper SSH keys configured
    - SCP command available

EOF
}

# Main execution function
main() {
    print_info "Starting Manual CVM Workflow Demonstration"
    print_info "=========================================="
    
    # Create test file
    create_test_file
    
    # Copy file to CVM
    copy_file_to_cvm
    
    # SSH to CVM and verify
    ssh_to_cvm_and_verify
    
    # SSH to CVM and stay in session
    ssh_to_cvm_and_stay
    
    print_success "Manual workflow demonstration completed successfully!"
    print_info "All steps executed:"
    print_info "1. ✅ Created test file: $TEST_FILE"
    print_info "2. ✅ Copied file to CVM using SCP"
    print_info "3. ✅ SSH to CVM and verified file transfer"
    print_info "4. ✅ SSH to CVM and showed files to user"
    print_info "5. ✅ Test file preserved on CVM for user to work with"
}

# Execute main function
main "$@"
