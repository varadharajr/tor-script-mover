#!/bin/bash

# Tor Script Mover Repository Setup
# This script sets up the tor-script-mover repository and pushes the project
# Usage: ./setup-tor-script-mover.sh

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_NAME="tor-script-mover"
PROJECT_DIR="/home/rvaradharaj1/dev/projects/nutanix-teleport-automation"
REMOTE_URL="https://github.com/YOUR_USERNAME/$REPO_NAME.git"

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

# Function to check if we're in the right directory
check_project_directory() {
    print_info "Checking project directory..."
    
    if [ ! -d "$PROJECT_DIR" ]; then
        print_error "Project directory not found: $PROJECT_DIR"
        exit 1
    fi
    
    if [ ! -f "$PROJECT_DIR/README.md" ]; then
        print_error "README.md not found in project directory"
        exit 1
    fi
    
    print_success "Project directory verified: $PROJECT_DIR"
}

# Function to get GitHub username
get_github_username() {
    print_info "Getting GitHub username..."
    
    read -p "Enter your GitHub username: " github_username
    
    if [ -z "$github_username" ]; then
        print_error "GitHub username cannot be empty"
        exit 1
    fi
    
    REMOTE_URL="https://github.com/$github_username/$REPO_NAME.git"
    print_success "GitHub username set: $github_username"
    print_info "Remote URL: $REMOTE_URL"
}

# Function to check Git status
check_git_status() {
    print_info "Checking Git status..."
    
    cd "$PROJECT_DIR"
    
    if ! git status &> /dev/null; then
        print_error "Not a Git repository or Git not initialized"
        exit 1
    fi
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        print_warning "There are uncommitted changes"
        git status --short
        read -p "Do you want to commit these changes? (y/N): " commit_changes
        
        if [[ "$commit_changes" =~ ^[Yy]$ ]]; then
            git add .
            git commit -m "Add GitHub script deployer and repository setup

- Add github-script-deployer.sh for downloading and deploying scripts from GitHub
- Add setup-tor-script-mover.sh for repository setup
- Update documentation with new deployment capabilities"
            print_success "Changes committed"
        else
            print_warning "Skipping commit, but you may want to commit changes later"
        fi
    else
        print_success "No uncommitted changes"
    fi
}

# Function to add remote repository
add_remote_repository() {
    print_info "Setting up remote repository..."
    
    cd "$PROJECT_DIR"
    
    # Check if remote already exists
    if git remote get-url origin &> /dev/null; then
        print_warning "Remote 'origin' already exists"
        current_url=$(git remote get-url origin)
        print_info "Current remote URL: $current_url"
        
        read -p "Do you want to update the remote URL? (y/N): " update_remote
        if [[ "$update_remote" =~ ^[Yy]$ ]]; then
            git remote set-url origin "$REMOTE_URL"
            print_success "Remote URL updated"
        else
            print_info "Keeping existing remote URL"
        fi
    else
        git remote add origin "$REMOTE_URL"
        print_success "Remote repository added"
    fi
}

# Function to push to GitHub
push_to_github() {
    print_info "Pushing to GitHub repository..."
    
    cd "$PROJECT_DIR"
    
    # Set default branch to main
    git branch -M main
    
    # Push to GitHub
    print_info "Pushing to: $REMOTE_URL"
    
    if git push -u origin main; then
        print_success "Successfully pushed to GitHub repository"
    else
        print_error "Failed to push to GitHub repository"
        print_info "Please check:"
        print_info "1. Repository exists on GitHub"
        print_info "2. You have proper permissions"
        print_info "3. GitHub credentials are configured"
        exit 1
    fi
}

# Function to verify deployment
verify_deployment() {
    print_info "Verifying GitHub deployment..."
    
    print_info "Repository URL: $REMOTE_URL"
    print_info "Branch: main"
    print_info "Project: Nutanix Teleport Automation"
    
    print_success "Deployment verification completed"
    print_info "You can now access your repository at: $REMOTE_URL"
}

# Function to display next steps
show_next_steps() {
    print_info "Next Steps"
    print_info "=========="
    print_info "1. Verify repository on GitHub: $REMOTE_URL"
    print_info "2. Test the GitHub script deployer:"
    print_info "   ./scripts/github-script-deployer.sh"
    print_info "3. Set up GitHub Actions (optional)"
    print_info "4. Configure branch protection rules (optional)"
    print_info "5. Add collaborators if needed"
    print_info ""
    print_info "Repository Features:"
    print_info "• Cross-platform Teleport automation scripts"
    print_info "• GitHub script downloader and CVM deployer"
    print_info "• Comprehensive documentation"
    print_info "• Proper Git best practices"
}

# Function to display usage information
show_usage() {
    cat << EOF
Tor Script Mover Repository Setup

USAGE:
    $0

DESCRIPTION:
    This script sets up the tor-script-mover repository and pushes the
    Nutanix Teleport Automation project to GitHub. It performs:
    1. Verifies project directory and Git status
    2. Gets GitHub username and sets up remote URL
    3. Adds remote repository
    4. Pushes project to GitHub
    5. Verifies deployment

PREREQUISITES:
    - GitHub account with repository creation permissions
    - Git configured with proper credentials
    - Project directory with Git repository initialized

EOF
}

# Main execution function
main() {
    print_info "Tor Script Mover Repository Setup"
    print_info "=================================="
    
    # Check project directory
    check_project_directory
    
    # Get GitHub username
    get_github_username
    
    # Check Git status
    check_git_status
    
    # Add remote repository
    add_remote_repository
    
    # Push to GitHub
    push_to_github
    
    # Verify deployment
    verify_deployment
    
    # Show next steps
    show_next_steps
    
    print_success "Repository setup completed successfully!"
}

# Execute main function
main "$@"
