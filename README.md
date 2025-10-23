# Nutanix Teleport Automation

A comprehensive automation suite for Nutanix infrastructure access through Teleport with Okta Verify authentication.

## 🎯 Overview

This project provides automated scripts for logging into Nutanix AHV hosts through Teleport, with support for both Windows (PowerShell) and Linux/Unix (Bash) environments. The scripts handle the complete workflow from Teleport authentication to CVM access and script deployment.

## 📁 Project Structure

```
nutanix-teleport-automation/
├── scripts/                    # Main automation scripts
│   ├── teleport-login.sh      # Bash script for Linux/Unix
│   ├── teleport-login.ps1     # PowerShell script for Windows
│   ├── teleport-login-clean.ps1 # Clean PowerShell version
│   ├── manual-cvm-workflow.sh # Manual CVM workflow demo
│   └── setup-cvm.sh           # CVM setup script
├── config/                    # Configuration files
│   └── config.env             # Environment configuration
├── docs/                      # Documentation
│   └── README.md              # This file
├── examples/                  # Example scripts and usage
└── .gitignore                 # Git ignore rules
```

## 🚀 Features

- **Cross-platform support**: Bash script for Linux/Unix and PowerShell script for Windows
- **Automated Teleport authentication**: Uses `tplogin` alias for seamless login
- **Node discovery**: Automatically finds nodes based on rack and cluster names
- **SSH automation**: Connects to AHV hosts and CVMs automatically
- **Script deployment**: Copies scripts from git repository to CVM
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

### Linux/Unix (Bash)

```bash
./scripts/teleport-login.sh <rack_name> <cluster_name>
```

**Examples**:
```bash
./scripts/teleport-login.sh rack-01 cluster-prod
./scripts/teleport-login.sh rack-02 cluster-dev
```

### Windows (PowerShell)

```powershell
.\scripts\teleport-login-clean.ps1 -RackName <rack_name> -ClusterName <cluster_name>
```

**Examples**:
```powershell
.\scripts\teleport-login-clean.ps1 -RackName "rack-01" -ClusterName "cluster-prod"
.\scripts\teleport-login-clean.ps1 -RackName "rack-02" -ClusterName "cluster-dev"
```

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

The scripts perform the following steps:

1. **Input Validation**: Validates rack name and cluster name parameters
2. **Dependency Check**: Ensures all required tools are available
3. **Teleport Login**: Uses `tplogin` to authenticate with Teleport
4. **Node Discovery**: Uses `tsh ls` to find nodes matching the rack/cluster
5. **AHV Connection**: Connects to the AHV host using `tsh ssh`
6. **CVM Connection**: SSH into the local CVM at `192.168.5.2`
7. **Script Deployment**: Clones/updates scripts from git repository to `~/bin/`

## 🧪 Testing

### Manual Workflow Testing

Use the manual workflow script to test the process:

```bash
./scripts/manual-cvm-workflow.sh
```

This script demonstrates:
1. Creating a test file
2. SCP to CVM
3. SSH to CVM and verify
4. Interactive CVM session

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
