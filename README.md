# Teleport ToR Script Mover

A PowerShell automation tool for accessing Nutanix AHV hosts through Teleport and deploying ToR (Top of Rack) scripts to CVM (Controller Virtual Machine).

## Overview

This project provides a streamlined workflow for Windows users to log into Nutanix AHV hosts through Teleport with Okta Verify authentication, then deploy ToR upgrade and rollback scripts to the local CVM. The solution consists of two main components:

1. **teleport-login.sh** - PowerShell script for Teleport authentication and cluster discovery
2. **tor-script-mover.sh** - Bash script for downloading and deploying ToR scripts to CVM

## Project Structure

```
├── scripts/                           # Main deployment scripts
│   ├── teleport-login.sh             # PowerShell script for Teleport login
│   ├── tor-script-mover.sh           # Bash script for ToR script deployment
│   ├── azure-tor-upgrade-candidate.sh # ToR upgrade script
│   ├── rollback.sh                   # Rollback script
│   └── new-rackinfo.sh               # Additional utility script
├── config/                           # Configuration templates
│   └── config.env                    # Environment configuration template
├── docs/                             # Documentation
│   └── GITHUB_SETUP.md               # GitHub setup guide
├── examples/                          # Example scripts
│   ├── azure-tor-upgrade-candidate.sh # Example ToR upgrade script
│   ├── example-usage.sh              # Usage examples
│   └── rollback.sh                   # Example rollback script
└── .gitignore                        # Git ignore rules
```

## Features

- **Automated Teleport Authentication**: Handles Okta Verify authentication seamlessly
- **Cluster Discovery**: Finds and filters Nutanix clusters by name
- **ToR Script Deployment**: Downloads and deploys ToR upgrade and rollback scripts
- **Date-based File Management**: Automatically renames files with current date suffix
- **CVM Integration**: Copies files to Nutanix CVM with proper permissions
- **Comprehensive Logging**: Detailed logs with automatic size management
- **Error Handling**: Robust error handling with clear status messages

## Prerequisites

### Required Software
- **Teleport client** (`tsh`) - [Download here](https://goteleport.com/docs/installation/)
- **SSH client** - OpenSSH or compatible
- **PowerShell** - For Windows execution
- **Okta Verify** - For MFA authentication

### Required Configuration
- `tplogin` alias configured for Teleport authentication
- Access to Teleport server with proper permissions
- SSH access to target Nutanix AHV hosts
- SSH access to CVM at 192.168.5.2

## Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/varadharajr/tor-script-mover.git
   cd teleport-tor-script-mover
   ```

2. **Make scripts executable** (Linux/Unix):
   ```bash
   chmod +x scripts/*.sh
   ```

## Usage

### Step 1: Teleport Login and Cluster Discovery

Run the PowerShell script to authenticate with Teleport and find your cluster:

```powershell
.\scripts\teleport-login.sh
```

**What it does:**
1. Checks if already logged into Teleport (uses existing session if available)
2. Prompts for cluster name to search for
3. Displays cluster information in a formatted layout
4. Provides commands to connect to AHV host and deploy scripts

**Example output:**
```
[2025-10-24 15:10:18] INFO: Using existing Teleport session
[2025-10-24 15:10:19] SUCCESS: Found 1 node(s) in cluster 'ZGWC_P_NTX_POD06-XEND_CLUSTER2'

#################################
# ZGWC_P_NTX_POD06-XEND_CLUSTER2 #
#################################

Customer name:     statestreet.com
Cluster UUID:      00061756-7197-3ac9-a2a3-2ff66cbe321b
AHV host:          Nutanix-Cluster-Node-69E84569848F
Access expires:    2025-10-23 19:07:22 UTC
```

### Step 2: Connect to AHV Host

Use the provided SSH command to connect to the AHV host:

```bash
tsh ssh root@Nutanix-Cluster-Node-69E84569848F
```

### Step 3: Deploy ToR Scripts

Once connected to the AHV host, run the ToR script mover:

```bash
curl -sSL https://raw.githubusercontent.com/varadharajr/tor-script-mover/main/scripts/tor-script-mover.sh | bash
```

**What it does:**
1. Downloads `azure-tor-upgrade-candidate.sh` from GitHub
2. Downloads `rollback.sh` from GitHub
3. Renames files with current date suffix (e.g., `azure-tor-upgrade-20251024.sh`)
4. Copies files to CVM at `192.168.5.2:~/bin/`
5. Sets file permissions to executable (755)
6. Verifies deployment
7. Automatically connects to CVM via SSH

**Example output:**
```
[2025-10-24 15:10:18] SUCCESS: ToR Script Mover executed successfully
[2025-10-24 15:10:19] SUCCESS: azure-tor-upgrade-20251024.sh downloaded successfully
[2025-10-24 15:10:20] SUCCESS: rollback-20251024.sh downloaded successfully
[2025-10-24 15:10:21] SUCCESS: Both azure-tor-upgrade and rollback scripts are copied to local CVM at ~/bin, and permissions are set to executable
[2025-10-24 15:10:22] SUCCESS: Connecting to CVM...
```

**Files deployed:**
- `azure-tor-upgrade-YYYYMMDD.sh`
- `rollback-YYYYMMDD.sh`

## Configuration

### tplogin Alias Configuration

**Bash/Zsh**:
```bash
alias tplogin='tsh login --proxy=your-teleport-proxy.example.com --user=your-username'
```

**PowerShell**:
```powershell
function tplogin { tsh login --proxy=your-teleport-proxy.example.com --user=your-username }
```

### CVM Configuration

The scripts are configured to deploy to:
- **CVM IP**: 192.168.5.2
- **CVM User**: nutanix
- **Destination Directory**: ~/bin/
- **File Permissions**: 755 (executable)

## Workflow

The complete workflow consists of these steps:

1. **Teleport Authentication**: PowerShell script handles login and cluster discovery
2. **AHV Connection**: Manual SSH connection to AHV host using provided command
3. **Script Deployment**: Bash script downloads and deploys ToR scripts to CVM
4. **CVM Access**: Automatic SSH connection to CVM for immediate script execution

## Logging

The ToR script mover creates detailed logs at `/tmp/github-script-deployer.log` with:
- Maximum file size of 1MB (automatically trimmed)
- All operations logged with timestamps
- User sees only success/failure messages
- Detailed debugging information available in log file

## Troubleshooting

### Common Issues

1. **"Already logged in to Teleport"**
   - The script automatically uses existing Teleport sessions
   - No re-authentication prompt required

2. **"No nodes found matching cluster"**
   - Verify cluster name spelling and case sensitivity
   - Check available clusters with `tsh ls`
   - Ensure you have access to the target cluster

3. **"Failed to download script from GitHub"**
   - Check internet connectivity from AHV host
   - Verify GitHub repository accessibility
   - Ensure scripts exist in the repository

4. **"Failed to copy file to CVM"**
   - Verify CVM is accessible at 192.168.5.2
   - Check SSH key configuration
   - Ensure proper permissions for CVM access

5. **"Permission denied" errors**
   - Verify SSH keys are properly configured
   - Check user permissions on CVM
   - Ensure ~/bin directory exists and is writable

## Repository Information

- **GitHub Repository**: https://github.com/varadharajr/tor-script-mover
- **Main Script**: https://raw.githubusercontent.com/varadharajr/tor-script-mover/main/scripts/tor-script-mover.sh
- **ToR Scripts**: Available in `/scripts/` directory

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:

1. Check the troubleshooting section above
2. Review error messages and log files
3. Verify configuration settings
4. Contact your Teleport/Nutanix administrator
5. Open an issue in the repository

## Changelog

### Version 1.0.0
- Initial release with PowerShell and Bash components
- Automated Teleport authentication with Okta Verify
- Cluster discovery and filtering
- ToR script deployment to CVM
- Comprehensive logging and error handling
- Date-based file management
- Automatic CVM connection after deployment