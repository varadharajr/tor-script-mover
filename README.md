# Nutanix Teleport Automation

A streamlined PowerShell automation script for Nutanix infrastructure access through Teleport with Okta Verify authentication.

## 🎯 Overview

This project provides a PowerShell script for Windows users to log into Nutanix AHV hosts through Teleport. The script handles Teleport authentication, cluster discovery, and provides GitHub links for downloading additional deployment scripts to the CVM.

## 📁 Project Structure

```
nutanix-teleport-automation/
├── scripts/                    # GitHub deployment script
│   └── github-script-deployer.sh # Script to download and deploy GitHub scripts to CVM
├── config/                    # Configuration files
│   └── config.env             # Environment configuration template
├── docs/                      # Documentation
│   ├── README.md              # This file
│   └── GITHUB_SETUP.md        # GitHub setup guide
├── examples/                  # Example scripts and usage
│   └── example-usage.sh       # Usage examples
├── archived-scripts/          # Archived scripts (ignored by Git)
└── .gitignore                 # Git ignore rules
```

## 🚀 Features

- **GitHub script deployment**: Downloads and deploys scripts from GitHub to CVM
- **Automated file management**: Renames files with date suffixes
- **CVM integration**: Copies files to Nutanix CVM with proper permissions
- **Comprehensive error handling**: Detailed error messages and validation
- **Colored output**: Easy-to-read status messages

## 📋 Prerequisites

### Required Software
- **Teleport client** (`tsh`) - [Download here](https://goteleport.com/docs/installation/)
- **SSH client** - OpenSSH or compatible
- **Git** - For script repository access
- **Okta Verify** - For MFA authentication

### Required Configuration
- `tplogin` alias configured for Teleport authentication
- Access to Teleport server with proper permissions
- SSH access to target Nutanix nodes
- Git repository with scripts to deploy

## 🛠️ Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-org/nutanix-teleport-automation.git
   cd nutanix-teleport-automation
   ```

2. **Make scripts executable** (Linux/Unix):
   ```bash
   chmod +x scripts/*.sh
   ```

3. **Configure the environment**:
   ```bash
   cp config/config.env ~/.nutanix-ahv-config
   # Edit the configuration file with your settings
   nano ~/.nutanix-ahv-config
   ```

## 🎯 Usage

### GitHub Script Deployer

The main script downloads and deploys scripts from GitHub to the Nutanix CVM:

```bash
./scripts/github-script-deployer.sh
```

**What it does:**
1. Downloads `azure-tor-upgrade-candidate.sh` from GitHub
2. Downloads `rollback.sh` from GitHub  
3. Renames files with current date suffix (e.g., `azure-tor-upgrade-20251024.sh`)
4. Copies files to CVM at `192.168.5.2:~/bin/`
5. Sets file permissions to `755`
6. Verifies deployment

**Files deployed:**
- `azure-tor-upgrade-YYYYMMDD.sh`
- `rollback-YYYYMMDD.sh`

## ⚙️ Configuration

### Environment Variables

Create a configuration file `~/.nutanix-ahv-config` with the following variables:

```bash
# Git Repository Configuration
SCRIPT_REPO_URL="https://github.com/your-org/nutanix-scripts.git"

# Teleport Configuration
TELEPORT_PROXY="your-teleport-proxy.example.com"
TELEPORT_USER="your-username"

# Nutanix Configuration
CVM_IP="192.168.5.2"
CVM_USER="nutanix"
CVM_BIN_DIR="~/bin"

# Optional Settings
SSH_TIMEOUT="30"
SSH_RETRY_COUNT="3"
LOG_LEVEL="INFO"
LOG_FILE="~/nutanix-ahv-login.log"
```

### tplogin Alias Configuration

**Bash/Zsh**:
```bash
alias tplogin='tsh login --proxy=your-teleport-proxy.example.com --user=your-username'
```

**PowerShell**:
```powershell
function tplogin { tsh login --proxy=your-teleport-proxy.example.com --user=your-username }
```

## 🔄 Workflow

The GitHub script deployer performs the following steps:

1. **Dependency Check**: Ensures curl, scp, and ssh are available
2. **Download Scripts**: Downloads scripts from GitHub repositories
3. **File Renaming**: Adds current date suffix to filenames
4. **CVM Connectivity**: Tests connection to CVM at 192.168.5.2
5. **File Deployment**: Copies files to CVM using SCP
6. **Permission Setting**: Sets file permissions to 755
7. **Verification**: Confirms successful deployment
8. **Cleanup**: Removes temporary files

## 🧪 Testing

### GitHub Script Deployer Testing

Test the script deployment process:

```bash
./scripts/github-script-deployer.sh
```

This script demonstrates:
1. GitHub script downloading
2. File renaming with date suffixes
3. CVM deployment
4. Permission setting
5. Deployment verification

## 🐛 Troubleshooting

### Common Issues

1. **"tplogin: command not found"**
   - Ensure the `tplogin` alias is properly configured
   - Check your shell configuration files (`.bashrc`, `.zshrc`, etc.)

2. **"Failed to login to Teleport"**
   - Verify Teleport server connectivity
   - Check Okta Verify configuration
   - Ensure proper permissions

3. **"No nodes found matching rack/cluster"**
   - Verify rack and cluster names are correct
   - Check available nodes with `tsh ls`
   - Ensure you have access to the target nodes

4. **"Failed to SSH into AHV host"**
   - Verify node is online and accessible
   - Check Teleport permissions for the node
   - Ensure SSH keys are properly configured

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For issues and questions:

1. Check the troubleshooting section
2. Review error messages and logs
3. Verify configuration settings
4. Contact your Teleport/Nutanix administrator
5. Open an issue in the repository

## 📝 Changelog

### Version 1.0.0
- Initial release
- Cross-platform support (Bash and PowerShell)
- Automated Teleport authentication
- Node discovery and SSH automation
- Script deployment functionality
- Comprehensive error handling
- Manual workflow testing

