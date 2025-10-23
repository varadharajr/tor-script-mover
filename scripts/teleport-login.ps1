# Teleport Login Script (PowerShell Version)
# This script handles Teleport authentication using the tplogin alias
# Usage: .\teleport-login.ps1 [OPTIONS]

param(
    [Parameter(HelpMessage="Show current Teleport status only")]
    [switch]$Status,
    
    [Parameter(HelpMessage="Show available nodes only")]
    [switch]$Nodes,
    
    [Parameter(HelpMessage="Show help information")]
    [switch]$Help
)

# Function to print colored output
function Write-Status {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Type) {
        "Error" { "Red" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Info" { "Cyan" }
        default { "White" }
    }
    
    Write-Host "[$timestamp] $($Type.ToUpper()): $Message" -ForegroundColor $color
}

function Write-Error-Status {
    param([string]$Message)
    Write-Status -Message $Message -Type "Error"
}

function Write-Success-Status {
    param([string]$Message)
    Write-Status -Message $Message -Type "Success"
}

function Write-Info-Status {
    param([string]$Message)
    Write-Status -Message $Message -Type "Info"
}

function Write-Warning-Status {
    param([string]$Message)
    Write-Status -Message $Message -Type "Warning"
}

# Function to check if tplogin alias/function exists
function Test-Tplogin {
    Write-Info-Status "Checking tplogin alias/function..."
    
    try {
        $null = Get-Command tplogin -ErrorAction Stop
        Write-Success-Status "tplogin alias/function found"
    }
    catch {
        Write-Error-Status "tplogin alias/function not found"
        Write-Info-Status "Please ensure tplogin is configured in your PowerShell profile"
        Write-Info-Status "Example configuration:"
        Write-Info-Status "  function tplogin { tsh login --proxy=your-teleport-proxy.com --user=your-username }"
        Write-Info-Status "  Add this to your PowerShell profile:"
        Write-Info-Status "  notepad $PROFILE"
        exit 1
    }
}

# Function to check if tsh is available
function Test-Tsh {
    Write-Info-Status "Checking tsh command..."
    
    try {
        $null = Get-Command tsh -ErrorAction Stop
        Write-Success-Status "tsh command found"
        
        try {
            $version = & tsh version 2>$null
            Write-Info-Status "Teleport version: $version"
        }
        catch {
            Write-Info-Status "Teleport version: Unknown"
        }
    }
    catch {
        Write-Error-Status "tsh command not found"
        Write-Info-Status "Please install Teleport client (tsh)"
        Write-Info-Status "Download from: https://goteleport.com/docs/installation/"
        exit 1
    }
}

# Function to check current Teleport status
function Test-TeleportStatus {
    Write-Info-Status "Checking current Teleport status..."
    
    try {
        $statusOutput = & tsh status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Info-Status "Current Teleport status:"
            $statusOutput | ForEach-Object { Write-Host $_ }
            Write-Warning-Status "Already logged in to Teleport"
            
            $reauth = Read-Host "Do you want to re-authenticate? (y/N)"
            if ($reauth -notmatch '^[Yy]$') {
                Write-Info-Status "Using existing Teleport session"
                return $true
            }
        }
        else {
            Write-Info-Status "Not currently logged in to Teleport"
        }
    }
    catch {
        Write-Info-Status "Not currently logged in to Teleport"
    }
    
    return $false
}

# Function to perform Teleport login
function Start-TeleportLogin {
    Write-Info-Status "Initiating Teleport login..."
    Write-Info-Status "This will open a web browser for Okta Verify authentication"
    
    # Give user a moment to read the message
    Start-Sleep -Seconds 2
    
    Write-Info-Status "Running: tplogin"
    
    try {
        & tplogin
        if ($LASTEXITCODE -eq 0) {
            Write-Success-Status "Successfully logged into Teleport"
        }
        else {
            throw "tplogin command failed with exit code $LASTEXITCODE"
        }
    }
    catch {
        Write-Error-Status "Failed to login to Teleport: $($_.Exception.Message)"
        Write-Info-Status "Please check:"
        Write-Info-Status "1. Your tplogin function configuration"
        Write-Info-Status "2. Teleport server connectivity"
        Write-Info-Status "3. Okta Verify is properly configured"
        Write-Info-Status "4. You have proper permissions"
        exit 1
    }
}

# Function to verify login success
function Test-LoginSuccess {
    Write-Info-Status "Verifying Teleport login..."
    
    try {
        $statusOutput = & tsh status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success-Status "Teleport login verified"
            Write-Info-Status "Current session details:"
            $statusOutput | ForEach-Object { Write-Host $_ }
        }
        else {
            throw "Login verification failed"
        }
    }
    catch {
        Write-Error-Status "Login verification failed"
        Write-Info-Status "Please try logging in again"
        exit 1
    }
}

# Function to show available nodes
function Show-Nodes {
    Write-Info-Status "Fetching available nodes..."
    
    try {
        $nodesOutput = & tsh ls 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success-Status "Available nodes:"
            $nodesOutput | ForEach-Object { Write-Host $_ }
        }
        else {
            Write-Warning-Status "Could not list nodes (this might be normal if no nodes are accessible)"
        }
    }
    catch {
        Write-Warning-Status "Could not list nodes (this might be normal if no nodes are accessible)"
    }
}

# Function to find nodes by cluster name
function Find-NodesByCluster {
    param([string]$ClusterName)
    
    Write-Info-Status "Searching for nodes in cluster: $ClusterName"
    
    try {
        # Use tsh ls with cluster_name filter for more accurate results
        $filteredNodes = & tsh ls "cluster_name=$ClusterName" 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error-Status "Could not list nodes from Teleport for cluster: $ClusterName"
            Write-Info-Status "Trying alternative method..."
            
            # Fallback to general tsh ls and filter
            $nodesOutput = & tsh ls 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Error-Status "Could not list nodes from Teleport"
                return $false
            }
            
            if (-not $nodesOutput) {
                Write-Warning-Status "No nodes found or unable to retrieve node list"
                return $false
            }
            
            # Filter nodes by cluster name (case-insensitive)
            $filteredNodes = $nodesOutput | Where-Object { $_ -match $ClusterName }
            
            if (-not $filteredNodes) {
                Write-Warning-Status "No nodes found matching cluster: $ClusterName"
                Write-Info-Status "Available clusters (first 10):"
                $nodesOutput | Select-Object -First 10 | ForEach-Object { Write-Host $_ }
                return $false
            }
        }
        
        if (-not $filteredNodes) {
            Write-Warning-Status "No nodes found matching cluster: $ClusterName"
            Write-Info-Status "Trying to show available clusters..."
            $allNodes = & tsh ls 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Info-Status "Available clusters (first 10):"
                $allNodes | Select-Object -First 10 | ForEach-Object { Write-Host $_ }
            }
            return $false
        }
        
        Write-Success-Status "Found nodes in cluster '$ClusterName':"
        $filteredNodes | ForEach-Object { Write-Host $_ }
        
        # Count the number of matching nodes
        $nodeCount = ($filteredNodes | Measure-Object).Count
        Write-Info-Status "Total nodes found: $nodeCount"
        
        return $true
    }
    catch {
        Write-Error-Status "Error searching for nodes: $($_.Exception.Message)"
        return $false
    }
}

# Function to show current status only
function Show-StatusOnly {
    Write-Info-Status "Checking Teleport status..."
    
    try {
        $statusOutput = & tsh status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success-Status "Currently logged in to Teleport"
            $statusOutput | ForEach-Object { Write-Host $_ }
        }
        else {
            Write-Warning-Status "Not logged in to Teleport"
        }
    }
    catch {
        Write-Warning-Status "Not logged in to Teleport"
    }
}

# Function to show nodes only
function Show-NodesOnly {
    Write-Info-Status "Fetching available nodes..."
    
    try {
        $statusOutput = & tsh status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Show-Nodes
        }
        else {
            Write-Error-Status "Not logged in to Teleport"
            Write-Info-Status "Please run the login process first"
            exit 1
        }
    }
    catch {
        Write-Error-Status "Not logged in to Teleport"
        Write-Info-Status "Please run the login process first"
        exit 1
    }
}

# Function to display usage information
function Show-Usage {
    Write-Host @"
Teleport Login Script (PowerShell Version)

USAGE:
    .\teleport-login.ps1 [OPTIONS]

DESCRIPTION:
    This script handles Teleport authentication using the configured tplogin function.
    It performs the following steps:
    1. Checks for tplogin function and tsh command
    2. Checks current Teleport status
    3. Performs Teleport login via tplogin
    4. Verifies login success
    5. Shows available nodes

PARAMETERS:
    -Status        Show current Teleport status only
    -Nodes         Show available nodes only
    -Help          Show this help message

PREREQUISITES:
    - tplogin function must be configured in PowerShell profile
    - tsh (Teleport client) must be installed
    - Okta Verify must be configured and accessible

EXAMPLES:
    .\teleport-login.ps1                    # Full login process
    .\teleport-login.ps1 -Status           # Check current status
    .\teleport-login.ps1 -Nodes            # Show available nodes
    .\teleport-login.ps1 -Help             # Show help

POWERSHELL PROFILE CONFIGURATION:
    To configure tplogin function, add this to your PowerShell profile:
    
    function tplogin {
        tsh login --proxy=your-teleport-proxy.com --user=your-username
    }
    
    To edit your profile:
    notepad `$PROFILE

"@
}

# Function to check PowerShell profile
function Test-PowerShellProfile {
    Write-Info-Status "Checking PowerShell profile configuration..."
    
    if (Test-Path $PROFILE) {
        Write-Info-Status "PowerShell profile found: $PROFILE"
        
        $profileContent = Get-Content $PROFILE -Raw
        if ($profileContent -match "function tplogin") {
            Write-Success-Status "tplogin function found in PowerShell profile"
        }
        else {
            Write-Warning-Status "tplogin function not found in PowerShell profile"
            Write-Info-Status "To configure tplogin, add this to your profile:"
            Write-Info-Status "function tplogin { tsh login --proxy=your-proxy.com --user=your-username }"
            Write-Info-Status "Edit profile with: notepad `$PROFILE"
        }
    }
    else {
        Write-Warning-Status "PowerShell profile not found: $PROFILE"
        Write-Info-Status "To create a profile, run: New-Item -Path `$PROFILE -Type File -Force"
        Write-Info-Status "Then add tplogin function to the profile"
    }
}

# Main execution function
function Main {
    # Handle help parameter
    if ($Help) {
        Show-Usage
        exit 0
    }
    
    # Handle status-only parameter
    if ($Status) {
        Show-StatusOnly
        exit 0
    }
    
    # Handle nodes-only parameter
    if ($Nodes) {
        Show-NodesOnly
        exit 0
    }
    
    Write-Info-Status "Starting Teleport Login Process"
    Write-Info-Status "==============================="
    
    # Check PowerShell profile
    Test-PowerShellProfile
    
    # Check dependencies
    Test-Tplogin
    Test-Tsh
    
    # Check current status
    $alreadyLoggedIn = Test-TeleportStatus
    
    # Perform login if not already logged in
    if (-not $alreadyLoggedIn) {
        Start-TeleportLogin
    }
    
    # Verify login
    Test-LoginSuccess
    
    # Ask for cluster name and find nodes
    Write-Info-Status "Teleport login successful! Now let's find your cluster nodes."
    Write-Host ""
    $clusterName = Read-Host "Enter cluster name to search for"
    
    if ($clusterName) {
        Find-NodesByCluster -ClusterName $clusterName
    }
    else {
        Write-Warning-Status "No cluster name provided, showing all nodes:"
        Show-Nodes
    }
    
    Write-Success-Status "Teleport login process completed successfully!"
    Write-Info-Status "You can now use 'tsh ssh' to connect to available nodes"
}

# Execute main function
Main
