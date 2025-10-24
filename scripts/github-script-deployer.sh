#!/bin/bash

# GitHub Script Downloader and CVM Deployer
# This script downloads scripts from GitHub, renames them with dates, and deploys to CVM
# Usage: ./github-script-deployer.sh

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
CVM_BIN_DIR="~/bin"
LOCAL_TMP_DIR="/tmp/github-scripts"
DATE_SUFFIX=$(date +%Y%m%d)

# GitHub URLs
AZURE_TOR_URL="https://raw.githubusercontent.com/anam-2019/Azure-ToR-Upgrade/08729a49981a1d6e6fb321a9c2ba0493c9a97b7d/azure-tor-upgrade-candidate.sh"
ROLLBACK_URL="https://raw.githubusercontent.com/anam-2019/Azure-ToR-Upgrade/e1287e43e5e195b9e22dafaa3fb54609622a87b6/rollback.sh"

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

# Function to check dependencies
check_dependencies() {
    print_info "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v scp &> /dev/null; then
        missing_deps+=("scp")
    fi
    
    if ! command -v ssh &> /dev/null; then
        missing_deps+=("ssh")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_info "Please install the missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                "curl")
                    print_info "  Install curl: sudo apt-get install curl"
                    ;;
                "scp")
                    print_info "  Install OpenSSH client: sudo apt-get install openssh-client"
                    ;;
                "ssh")
                    print_info "  Install OpenSSH client: sudo apt-get install openssh-client"
                    ;;
            esac
        done
        exit 1
    fi
    
    print_success "All dependencies found"
}

# Function to create temporary directory
create_temp_dir() {
    print_info "Creating temporary directory..."
    
    if [ -d "$LOCAL_TMP_DIR" ]; then
        print_warning "Temporary directory already exists, cleaning up..."
        rm -rf "$LOCAL_TMP_DIR"
    fi
    
    mkdir -p "$LOCAL_TMP_DIR"
    print_success "Temporary directory created: $LOCAL_TMP_DIR"
}

# Function to download script from GitHub
download_script() {
    local url="$1"
    local filename="$2"
    local local_path="$LOCAL_TMP_DIR/$filename"
    
    print_info "Downloading script from GitHub..."
    print_info "URL: $url"
    print_info "Local file: $local_path"
    
    if curl -sSL -o "$local_path" "$url"; then
        print_success "Script downloaded successfully: $filename"
        
        # Check if file has content
        if [ -s "$local_path" ]; then
            local file_size=$(wc -c < "$local_path")
            print_info "File size: $file_size bytes"
        else
            print_error "Downloaded file is empty"
            return 1
        fi
    else
        print_error "Failed to download script from: $url"
        return 1
    fi
}

# Function to rename file with date
rename_with_date() {
    local original_file="$1"
    local new_name="$2"
    local new_path="$LOCAL_TMP_DIR/$new_name"
    
    print_info "Renaming file with date suffix..."
    print_info "Original: $(basename "$original_file")"
    print_info "New name: $new_name"
    
    if mv "$original_file" "$new_path"; then
        print_success "File renamed successfully: $new_name"
    else
        print_error "Failed to rename file"
        return 1
    fi
}

# Function to test CVM connectivity
test_cvm_connectivity() {
    print_info "Testing CVM connectivity..."
    
    if ping -c 1 "$CVM_IP" &> /dev/null; then
        print_success "CVM is reachable at $CVM_IP"
    else
        print_warning "CVM may not be reachable at $CVM_IP"
        print_info "Continuing with SSH attempt..."
    fi
}

# Function to copy file to CVM
copy_to_cvm() {
    local local_file="$1"
    local filename=$(basename "$local_file")
    
    print_info "Copying file to CVM..."
    print_info "Local file: $local_file"
    print_info "CVM destination: $CVM_USER@$CVM_IP:$CVM_BIN_DIR/$filename"
    
    if scp "$local_file" "$CVM_USER@$CVM_IP:$CVM_BIN_DIR/$filename"; then
        print_success "File copied successfully to CVM: $filename"
    else
        print_error "Failed to copy file to CVM: $filename"
        print_info "Please check:"
        print_info "1. CVM is accessible at $CVM_IP"
        print_info "2. SSH keys are properly configured"
        print_info "3. You have proper permissions to access the CVM"
        return 1
    fi
}

# Function to set file permissions on CVM
set_cvm_permissions() {
    local filename="$1"
    
    print_info "Setting file permissions on CVM..."
    print_info "File: $filename"
    print_info "Permissions: 755"
    
    if ssh "$CVM_USER@$CVM_IP" "chmod 755 $CVM_BIN_DIR/$filename"; then
        print_success "File permissions set successfully: $filename"
    else
        print_error "Failed to set file permissions: $filename"
        return 1
    fi
}

# Function to verify file on CVM
verify_cvm_file() {
    local filename="$1"
    
    print_info "Verifying file on CVM..."
    
    if ssh "$CVM_USER@$CVM_IP" "ls -la $CVM_BIN_DIR/$filename"; then
        print_success "File verified on CVM: $filename"
    else
        print_error "File verification failed: $filename"
        return 1
    fi
}

# Function to deploy single script
deploy_script() {
    local url="$1"
    local original_name="$2"
    local new_name="$3"
    
    print_info "Starting deployment for: $original_name"
    print_info "=========================================="
    
    # Download script
    download_script "$url" "$original_name"
    
    # Rename with date
    rename_with_date "$LOCAL_TMP_DIR/$original_name" "$new_name"
    
    # Copy to CVM
    copy_to_cvm "$LOCAL_TMP_DIR/$new_name"
    
    # Set permissions
    set_cvm_permissions "$new_name"
    
    # Verify file
    verify_cvm_file "$new_name"
    
    print_success "Deployment completed for: $new_name"
    print_info "=========================================="
}

# Function to clean up temporary files
cleanup() {
    print_info "Cleaning up temporary files..."
    
    if [ -d "$LOCAL_TMP_DIR" ]; then
        rm -rf "$LOCAL_TMP_DIR"
        print_success "Temporary files cleaned up"
    fi
}

# Function to display summary
display_summary() {
    print_info "Deployment Summary"
    print_info "=================="
    print_success "✅ Azure ToR Upgrade script deployed: azure-tor-upgrade-$DATE_SUFFIX.sh"
    print_success "✅ Rollback script deployed: rollback-$DATE_SUFFIX.sh"
    print_info ""
    print_info "📁 Files deployed to CVM:"
    print_info "   • Location: $CVM_USER@$CVM_IP:$CVM_BIN_DIR/"
    print_info "   • Permissions: 755"
    print_info "   • Date suffix: $DATE_SUFFIX"
    print_info ""
    print_info "🔧 Next Steps:"
    print_info "   1. SSH to CVM: ssh $CVM_USER@$CVM_IP"
    print_info "   2. Navigate to bin: cd ~/bin"
    print_info "   3. List files: ls -la"
    print_info "   4. Run scripts as needed"
}

# Function to display usage information
show_usage() {
    cat << EOF
GitHub Script Downloader and CVM Deployer

USAGE:
    $0

DESCRIPTION:
    This script downloads scripts from GitHub repositories, renames them with dates,
    and deploys them to the Nutanix CVM. It performs the following steps:
    1. Downloads azure-tor-upgrade-candidate.sh from GitHub
    2. Downloads rollback.sh from GitHub
    3. Renames files with current date suffix
    4. Copies files to CVM at 192.168.5.2:~/bin/
    5. Sets file permissions to 755
    6. Verifies deployment

FILES DEPLOYED:
    - azure-tor-upgrade-$DATE_SUFFIX.sh
    - rollback-$DATE_SUFFIX.sh

PREREQUISITES:
    - SSH access to CVM at 192.168.5.2
    - Proper SSH keys configured
    - curl command available
    - scp and ssh commands available

EOF
}

# Main execution function
main() {
    print_info "GitHub Script Downloader and CVM Deployer"
    print_info "========================================="
    
    # Check dependencies
    check_dependencies
    
    # Create temporary directory
    create_temp_dir
    
    # Test CVM connectivity
    test_cvm_connectivity
    
    # Deploy Azure ToR Upgrade script
    deploy_script "$AZURE_TOR_URL" "azure-tor-upgrade-candidate.sh" "azure-tor-upgrade-$DATE_SUFFIX.sh"
    
    # Deploy Rollback script
    deploy_script "$ROLLBACK_URL" "rollback.sh" "rollback-$DATE_SUFFIX.sh"
    
    # Display summary
    display_summary
    
    # Clean up
    cleanup
    
    print_success "All deployments completed successfully!"
}

# Execute main function
main "$@"
