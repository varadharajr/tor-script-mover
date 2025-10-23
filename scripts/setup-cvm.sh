#!/bin/bash

# Nutanix CVM Setup Script
# This script downloads and sets up Nutanix scripts on the CVM
# Usage: curl -sSL https://raw.githubusercontent.com/your-org/nutanix-scripts/main/setup-cvm.sh | bash

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
CVM_TMP_DIR="~/tmp"
SCRIPT_REPO_URL="https://github.com/your-org/nutanix-scripts.git"
SCRIPT_REPO_BRANCH="main"

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
    
    if ! command -v ssh &> /dev/null; then
        missing_deps+=("ssh")
    fi
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_info "Please install the missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                "ssh")
                    print_info "  Install OpenSSH client"
                    ;;
                "git")
                    print_info "  Install Git"
                    ;;
            esac
        done
        exit 1
    fi
    
    print_success "All dependencies found"
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

# Function to setup CVM
setup_cvm() {
    print_info "Setting up CVM with Nutanix scripts..."
    
    # Create a temporary script that will be executed on the CVM
    local temp_script
    temp_script=$(mktemp)
    
    cat > "$temp_script" << 'EOF'
#!/bin/bash
set -euo pipefail

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] ${message}\033[0m"
}

print_error() {
    print_status "\033[0;31m" "ERROR: $1"
}

print_success() {
    print_status "\033[0;32m" "SUCCESS: $1"
}

print_info() {
    print_status "\033[0;34m" "INFO: $1"
}

print_warning() {
    print_status "\033[1;33m" "WARNING: $1"
}

# Configuration
CVM_TMP_DIR="~/tmp"
SCRIPT_REPO_URL="https://github.com/your-org/nutanix-scripts.git"
SCRIPT_REPO_BRANCH="main"

print_info "Connected to CVM. Setting up Nutanix scripts..."

# Create tmp directory if it doesn't exist
mkdir -p ~/tmp

# Clone or update the repository
if [ -d "~/tmp/nutanix-scripts" ]; then
    print_info "Updating existing repository..."
    cd ~/tmp/nutanix-scripts
    git pull origin "$SCRIPT_REPO_BRANCH"
else
    print_info "Cloning repository..."
    cd ~/tmp
    git clone "$SCRIPT_REPO_URL" nutanix-scripts
    cd nutanix-scripts
    git checkout "$SCRIPT_REPO_BRANCH"
fi

# Make scripts executable
chmod +x ~/tmp/nutanix-scripts/*.sh 2>/dev/null || true

print_success "Scripts successfully downloaded to ~/tmp/nutanix-scripts/"
print_info "Available scripts:"
ls -la ~/tmp/nutanix-scripts/

print_info "Setup completed successfully!"
print_info "You can now use the scripts in ~/tmp/nutanix-scripts/"

EOF

    # Execute the temporary script on the CVM
    print_info "Executing setup script on CVM..."
    
    if ssh "$CVM_USER@$CVM_IP" "bash -s" < "$temp_script"; then
        print_success "CVM setup completed successfully"
    else
        print_error "Failed to setup CVM"
        print_info "Please check:"
        print_info "1. CVM is accessible at $CVM_IP"
        print_info "2. SSH keys are properly configured"
        print_info "3. You have proper permissions to access the CVM"
        print_info "4. Git repository is accessible"
        rm -f "$temp_script"
        exit 1
    fi
    
    # Clean up
    rm -f "$temp_script"
    
    print_success "CVM setup process completed successfully!"
}

# Function to display usage information
show_usage() {
    cat << EOF
Nutanix CVM Setup Script

USAGE:
    curl -sSL https://raw.githubusercontent.com/your-org/nutanix-scripts/main/setup-cvm.sh | bash
    OR
    wget https://raw.githubusercontent.com/your-org/nutanix-scripts/main/setup-cvm.sh
    chmod +x setup-cvm.sh
    ./setup-cvm.sh

DESCRIPTION:
    This script sets up Nutanix scripts on the CVM by:
    1. Testing CVM connectivity
    2. SSH into the CVM
    3. Cloning/updating the Nutanix scripts repository
    4. Making scripts executable
    5. Setting up the environment

PREREQUISITES:
    - SSH access to CVM at 192.168.5.2
    - Git repository access
    - Proper SSH keys configured

EOF
}

# Main execution function
main() {
    print_info "Starting Nutanix CVM Setup Process"
    print_info "=================================="
    
    # Check dependencies
    check_dependencies
    
    # Test CVM connectivity
    test_cvm_connectivity
    
    # Setup CVM
    setup_cvm
    
    print_success "All operations completed successfully!"
    print_info "Nutanix scripts are now available on the CVM at ~/tmp/nutanix-scripts/"
}

# Execute main function
main "$@"
