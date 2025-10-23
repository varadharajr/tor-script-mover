#!/bin/bash

# Nutanix Teleport Automation Setup Script
# This script helps set up the environment for the Nutanix Teleport automation

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install dependencies
install_dependencies() {
    print_info "Checking and installing dependencies..."
    
    local missing_deps=()
    
    # Check for required commands
    if ! command_exists tsh; then
        missing_deps+=("teleport")
    fi
    
    if ! command_exists ssh; then
        missing_deps+=("openssh-client")
    fi
    
    if ! command_exists git; then
        missing_deps+=("git")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_warning "Missing dependencies: ${missing_deps[*]}"
        print_info "Please install the missing dependencies:"
        
        for dep in "${missing_deps[@]}"; do
            case $dep in
                "teleport")
                    print_info "Install Teleport client:"
                    print_info "  Ubuntu/Debian: wget https://get.gravitational.com/teleport/6.2.4/teleport-v6.2.4-linux-amd64-bin.tar.gz"
                    print_info "  Or visit: https://goteleport.com/docs/installation/"
                    ;;
                "openssh-client")
                    print_info "Install OpenSSH client:"
                    print_info "  Ubuntu/Debian: sudo apt-get install openssh-client"
                    print_info "  CentOS/RHEL: sudo yum install openssh-clients"
                    ;;
                "git")
                    print_info "Install Git:"
                    print_info "  Ubuntu/Debian: sudo apt-get install git"
                    print_info "  CentOS/RHEL: sudo yum install git"
                    ;;
            esac
        done
        
        read -p "Press Enter to continue after installing dependencies..."
    else
        print_success "All dependencies are installed"
    fi
}

# Function to configure tplogin alias
configure_tplogin() {
    print_info "Configuring tplogin alias..."
    
    local shell_rc=""
    local tplogin_config=""
    
    # Detect shell
    if [ -n "${ZSH_VERSION:-}" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "${BASH_VERSION:-}" ]; then
        shell_rc="$HOME/.bashrc"
    else
        shell_rc="$HOME/.profile"
    fi
    
    print_info "Detected shell configuration file: $shell_rc"
    
    # Get Teleport configuration from user
    read -p "Enter your Teleport proxy server (e.g., teleport.example.com): " teleport_proxy
    read -p "Enter your Teleport username: " teleport_user
    
    tplogin_config="alias tplogin='tsh login --proxy=$teleport_proxy --user=$teleport_user'"
    
    # Check if tplogin alias already exists
    if grep -q "alias tplogin" "$shell_rc" 2>/dev/null; then
        print_warning "tplogin alias already exists in $shell_rc"
        read -p "Do you want to update it? (y/N): " update_alias
        if [[ "$update_alias" =~ ^[Yy]$ ]]; then
            # Remove existing alias
            sed -i '/alias tplogin/d' "$shell_rc"
            echo "$tplogin_config" >> "$shell_rc"
            print_success "Updated tplogin alias"
        fi
    else
        echo "$tplogin_config" >> "$shell_rc"
        print_success "Added tplogin alias to $shell_rc"
    fi
    
    print_info "Please run 'source $shell_rc' or restart your terminal to use the tplogin alias"
}

# Function to create configuration file
create_config() {
    print_info "Creating configuration file..."
    
    local config_file="$HOME/.nutanix-ahv-config"
    
    if [ -f "$config_file" ]; then
        print_warning "Configuration file already exists: $config_file"
        read -p "Do you want to overwrite it? (y/N): " overwrite_config
        if [[ ! "$overwrite_config" =~ ^[Yy]$ ]]; then
            print_info "Skipping configuration file creation"
            return
        fi
    fi
    
    # Get configuration from user
    read -p "Enter Git repository URL for scripts: " script_repo_url
    read -p "Enter CVM IP (default: 192.168.5.2): " cvm_ip
    cvm_ip=${cvm_ip:-"192.168.5.2"}
    
    read -p "Enter CVM username (default: nutanix): " cvm_user
    cvm_user=${cvm_user:-"nutanix"}
    
    # Create configuration file
    cat > "$config_file" << EOF
# Nutanix AHV Login Script Configuration
# Generated on $(date)

# Git Repository Configuration
SCRIPT_REPO_URL="$script_repo_url"

# Nutanix Configuration
CVM_IP="$cvm_ip"
CVM_USER="$cvm_user"
CVM_BIN_DIR="~/bin"

# Optional Settings
SSH_TIMEOUT="30"
SSH_RETRY_COUNT="3"
LOG_LEVEL="INFO"
LOG_FILE="~/nutanix-ahv-login.log"
EOF
    
    print_success "Configuration file created: $config_file"
}

# Function to make scripts executable
make_executable() {
    print_info "Making scripts executable..."
    
    local script_dir="$(dirname "$0")"
    
    if [ -f "$script_dir/teleport-login.sh" ]; then
        chmod +x "$script_dir/teleport-login.sh"
        print_success "Made teleport-login.sh executable"
    fi
    
    if [ -f "$script_dir/manual-cvm-workflow.sh" ]; then
        chmod +x "$script_dir/manual-cvm-workflow.sh"
        print_success "Made manual-cvm-workflow.sh executable"
    fi
    
    if [ -f "$script_dir/setup-cvm.sh" ]; then
        chmod +x "$script_dir/setup-cvm.sh"
        print_success "Made setup-cvm.sh executable"
    fi
}

# Function to test configuration
test_configuration() {
    print_info "Testing configuration..."
    
    # Test tplogin alias
    if command_exists tplogin; then
        print_success "tplogin alias is available"
    else
        print_warning "tplogin alias not found - you may need to restart your terminal"
    fi
    
    # Test tsh command
    if command_exists tsh; then
        print_success "tsh command is available"
        print_info "Teleport version: $(tsh version 2>/dev/null || echo 'Unknown')"
    else
        print_error "tsh command not found"
    fi
    
    # Test configuration file
    if [ -f "$HOME/.nutanix-ahv-config" ]; then
        print_success "Configuration file exists"
        print_info "Configuration file location: $HOME/.nutanix-ahv-config"
    else
        print_warning "Configuration file not found"
    fi
}

# Function to display next steps
show_next_steps() {
    print_info "Setup completed! Next steps:"
    print_info "=========================="
    print_info "1. Restart your terminal or run: source ~/.bashrc (or ~/.zshrc)"
    print_info "2. Test the tplogin alias: tplogin"
    print_info "3. Run the main script: ./scripts/teleport-login.sh <rack_name> <cluster_name>"
    print_info "4. Test manual workflow: ./scripts/manual-cvm-workflow.sh"
    print_info ""
    print_info "For more information, see the README.md file"
}

# Main execution
main() {
    print_info "Nutanix Teleport Automation Setup"
    print_info "================================="
    
    install_dependencies
    configure_tplogin
    create_config
    make_executable
    test_configuration
    show_next_steps
    
    print_success "Setup completed successfully!"
}

# Execute main function
main "$@"
