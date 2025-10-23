#!/bin/bash

# Teleport Login Script
# This script handles Teleport authentication using the tplogin alias
# Usage: ./teleport-login.sh

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

# Function to check if tplogin alias exists
check_tplogin() {
    print_info "Checking tplogin alias..."
    
    if ! command -v tplogin &> /dev/null; then
        print_error "tplogin alias not found"
        print_info "Please ensure tplogin alias is configured in your shell"
        print_info "Example configuration:"
        print_info "  alias tplogin='tsh login --proxy=your-teleport-proxy.com --user=your-username'"
        print_info "  Add this to your ~/.bashrc or ~/.zshrc file"
        exit 1
    fi
    
    print_success "tplogin alias found"
}

# Function to check if tsh is available
check_tsh() {
    print_info "Checking tsh command..."
    
    if ! command -v tsh &> /dev/null; then
        print_error "tsh command not found"
        print_info "Please install Teleport client (tsh)"
        print_info "Download from: https://goteleport.com/docs/installation/"
        exit 1
    fi
    
    print_success "tsh command found"
    print_info "Teleport version: $(tsh version 2>/dev/null || echo 'Unknown')"
}

# Function to check current Teleport status
check_teleport_status() {
    print_info "Checking current Teleport status..."
    
    if tsh status &> /dev/null; then
        print_info "Current Teleport status:"
        tsh status
        print_warning "Already logged in to Teleport"
        read -p "Do you want to re-authenticate? (y/N): " reauth
        if [[ ! "$reauth" =~ ^[Yy]$ ]]; then
            print_info "Using existing Teleport session"
            return 0
        fi
    else
        print_info "Not currently logged in to Teleport"
    fi
}

# Function to perform Teleport login
teleport_login() {
    print_info "Initiating Teleport login..."
    print_info "This will open a web browser for Okta Verify authentication"
    
    # Give user a moment to read the message
    sleep 2
    
    print_info "Running: tplogin"
    
    if tplogin; then
        print_success "Successfully logged into Teleport"
    else
        print_error "Failed to login to Teleport"
        print_info "Please check:"
        print_info "1. Your tplogin alias configuration"
        print_info "2. Teleport server connectivity"
        print_info "3. Okta Verify is properly configured"
        print_info "4. You have proper permissions"
        exit 1
    fi
}

# Function to verify login success
verify_login() {
    print_info "Verifying Teleport login..."
    
    if tsh status &> /dev/null; then
        print_success "Teleport login verified"
        print_info "Current session details:"
        tsh status
    else
        print_error "Login verification failed"
        print_info "Please try logging in again"
        exit 1
    fi
}

# Function to show available nodes
show_nodes() {
    print_info "Fetching available nodes..."
    
    if tsh ls &> /dev/null; then
        print_success "Available nodes:"
        tsh ls
    else
        print_warning "Could not list nodes (this might be normal if no nodes are accessible)"
    fi
}

# Function to find nodes by cluster name
find_nodes_by_cluster() {
    local cluster_name="$1"
    print_info "Searching for nodes in cluster: $cluster_name"
    
    # Use tsh ls with cluster_name filter for more accurate results
    local filtered_nodes
    if ! filtered_nodes=$(tsh ls "cluster_name=$cluster_name" 2>/dev/null); then
        print_error "Could not list nodes from Teleport for cluster: $cluster_name"
        print_info "Trying alternative method..."
        
        # Fallback to general tsh ls and filter
        local nodes_output
        if ! nodes_output=$(tsh ls 2>/dev/null); then
            print_error "Could not list nodes from Teleport"
            return 1
        fi
        
        if [ -z "$nodes_output" ]; then
            print_warning "No nodes found or unable to retrieve node list"
            return 1
        fi
        
        # Filter nodes by cluster name (case-insensitive)
        filtered_nodes=$(echo "$nodes_output" | grep -i "$cluster_name" || true)
        
        if [ -z "$filtered_nodes" ]; then
            print_warning "No nodes found matching cluster: $cluster_name"
            print_info "Available clusters (first 10):"
            echo "$nodes_output" | head -10
            return 1
        fi
    fi
    
    if [ -z "$filtered_nodes" ]; then
        print_warning "No nodes found matching cluster: $cluster_name"
        print_info "Trying to show available clusters..."
        local all_nodes
        if all_nodes=$(tsh ls 2>/dev/null); then
            print_info "Available clusters (first 10):"
            echo "$all_nodes" | head -10
        fi
        return 1
    fi
    
    print_success "Found nodes in cluster '$cluster_name':"
    echo "$filtered_nodes"
    
    # Count the number of matching nodes
    local node_count
    node_count=$(echo "$filtered_nodes" | wc -l)
    print_info "Total nodes found: $node_count"
}

# Function to display usage information
show_usage() {
    cat << EOF
Teleport Login Script

USAGE:
    $0 [OPTIONS]

DESCRIPTION:
    This script handles Teleport authentication using the configured tplogin alias.
    It performs the following steps:
    1. Checks for tplogin alias and tsh command
    2. Checks current Teleport status
    3. Performs Teleport login via tplogin
    4. Verifies login success
    5. Shows available nodes

OPTIONS:
    -h, --help     Show this help message
    -s, --status   Show current Teleport status only
    -n, --nodes    Show available nodes only

PREREQUISITES:
    - tplogin alias must be configured
    - tsh (Teleport client) must be installed
    - Okta Verify must be configured and accessible

EXAMPLES:
    $0                    # Full login process
    $0 --status          # Check current status
    $0 --nodes           # Show available nodes

EOF
}

# Function to show current status only
show_status_only() {
    print_info "Checking Teleport status..."
    
    if tsh status &> /dev/null; then
        print_success "Currently logged in to Teleport"
        tsh status
    else
        print_warning "Not logged in to Teleport"
    fi
}

# Function to show nodes only
show_nodes_only() {
    print_info "Fetching available nodes..."
    
    if tsh status &> /dev/null; then
        show_nodes
    else
        print_error "Not logged in to Teleport"
        print_info "Please run the login process first"
        exit 1
    fi
}

# Main execution function
main() {
    # Parse command line arguments
    case "${1:-}" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -s|--status)
            show_status_only
            exit 0
            ;;
        -n|--nodes)
            show_nodes_only
            exit 0
            ;;
        "")
            # No arguments, proceed with full login process
            ;;
        *)
            print_error "Unknown option: $1"
            print_info "Use -h or --help for usage information"
            exit 1
            ;;
    esac
    
    print_info "Starting Teleport Login Process"
    print_info "==============================="
    
    # Check dependencies
    check_tplogin
    check_tsh
    
    # Check current status
    check_teleport_status
    
    # Perform login
    teleport_login
    
    # Verify login
    verify_login
    
    # Ask for cluster name and find nodes
    print_info "Teleport login successful! Now let's find your cluster nodes."
    echo ""
    read -p "Enter cluster name to search for: " cluster_name
    
    if [ -n "$cluster_name" ]; then
        find_nodes_by_cluster "$cluster_name"
    else
        print_warning "No cluster name provided, showing all nodes:"
        show_nodes
    fi
    
    print_success "Teleport login process completed successfully!"
    print_info "You can now use 'tsh ssh' to connect to available nodes"
}

# Execute main function with all arguments
main "$@"
