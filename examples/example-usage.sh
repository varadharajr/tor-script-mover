#!/bin/bash

# Example Usage Script for Nutanix Teleport Automation
# This script demonstrates how to use the automation scripts

set -euo pipefail

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info "Nutanix Teleport Automation - Example Usage"
print_info "=========================================="
print_info ""

print_info "1. Basic Teleport Login (Linux/Unix):"
print_info "   ./scripts/teleport-login.sh rack-01 cluster-prod"
print_info ""

print_info "2. Basic Teleport Login (Windows PowerShell):"
print_info "   .\\scripts\\teleport-login-clean.ps1 -RackName \"rack-01\" -ClusterName \"cluster-prod\""
print_info ""

print_info "3. Check Teleport Status Only:"
print_info "   ./scripts/teleport-login.sh --status"
print_info "   .\\scripts\\teleport-login-clean.ps1 -Status"
print_info ""

print_info "4. Show Available Nodes:"
print_info "   ./scripts/teleport-login.sh --nodes"
print_info "   .\\scripts\\teleport-login-clean.ps1 -Nodes"
print_info ""

print_info "5. Manual CVM Workflow Testing:"
print_info "   ./scripts/manual-cvm-workflow.sh"
print_info ""

print_info "6. CVM Setup Script:"
print_info "   curl -sSL https://raw.githubusercontent.com/your-org/nutanix-scripts/main/setup-cvm.sh | bash"
print_info ""

print_success "Example usage completed!"
print_info "For more information, see the README.md file"

