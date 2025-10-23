# GitHub Repository Setup Guide

This guide helps you set up the Nutanix Teleport Automation project on GitHub and sync it with a remote repository.

## 🚀 Initial GitHub Setup

### 1. Create a GitHub Repository

1. Go to [GitHub](https://github.com) and sign in
2. Click the "+" icon in the top right corner
3. Select "New repository"
4. Fill in the repository details:
   - **Repository name**: `nutanix-teleport-automation`
   - **Description**: `Automation suite for Nutanix infrastructure access through Teleport`
   - **Visibility**: Choose Public or Private
   - **Initialize**: Don't initialize with README (we already have one)
5. Click "Create repository"

### 2. Connect Local Repository to GitHub

```bash
# Navigate to your project directory
cd /path/to/nutanix-teleport-automation

# Add the remote origin (replace with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/nutanix-teleport-automation.git

# Set the default branch to main
git branch -M main

# Push the initial commit
git push -u origin main
```

### 3. Verify the Setup

```bash
# Check remote configuration
git remote -v

# Check branch status
git branch -a

# Check commit history
git log --oneline
```

## 🔄 Daily Workflow

### Making Changes

```bash
# 1. Check current status
git status

# 2. Add changes
git add .

# 3. Commit changes with descriptive message
git commit -m "Add new feature: describe what you added"

# 4. Push to GitHub
git push origin main
```

### Pulling Updates

```bash
# Pull latest changes from GitHub
git pull origin main
```

## 🌿 Branch Management

### Creating Feature Branches

```bash
# Create and switch to new branch
git checkout -b feature/new-script

# Make your changes
# ... edit files ...

# Commit changes
git add .
git commit -m "Add new script functionality"

# Push branch to GitHub
git push origin feature/new-script
```

### Merging Branches

```bash
# Switch to main branch
git checkout main

# Pull latest changes
git pull origin main

# Merge feature branch
git merge feature/new-script

# Push merged changes
git push origin main

# Delete feature branch (optional)
git branch -d feature/new-script
git push origin --delete feature/new-script
```

## 📋 Best Practices

### Commit Messages

Use clear, descriptive commit messages:

```bash
# Good examples
git commit -m "Add PowerShell script for Windows users"
git commit -m "Fix SSH connection timeout issue"
git commit -m "Update documentation with new examples"

# Avoid
git commit -m "fix"
git commit -m "update"
git commit -m "changes"
```

### File Organization

- Keep scripts in `scripts/` directory
- Keep documentation in `docs/` directory
- Keep configuration in `config/` directory
- Keep examples in `examples/` directory

### .gitignore

The project includes a comprehensive `.gitignore` file that excludes:
- OS generated files
- IDE files
- Log files
- Temporary files
- Sensitive configuration files

## 🔐 Security Considerations

### Sensitive Information

Never commit:
- SSH private keys
- API keys
- Passwords
- Personal configuration with real credentials

### Configuration Files

Use template files for configuration:
- `config/config.env` - Template with placeholder values
- `config/local.env` - Local configuration (in .gitignore)
- `config/production.env` - Production configuration (in .gitignore)

## 📚 Documentation

### README.md

The main README.md should include:
- Project overview
- Installation instructions
- Usage examples
- Configuration guide
- Troubleshooting

### Additional Documentation

Create additional docs in the `docs/` directory:
- `GITHUB_SETUP.md` - This file
- `API.md` - API documentation if applicable
- `TROUBLESHOOTING.md` - Common issues and solutions

## 🚀 Deployment

### Release Management

```bash
# Create a tag for releases
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

### GitHub Releases

1. Go to your repository on GitHub
2. Click "Releases" in the right sidebar
3. Click "Create a new release"
4. Fill in the release details
5. Attach any release files
6. Click "Publish release"

## 🤝 Collaboration

### Fork and Pull Request Workflow

1. Fork the repository
2. Clone your fork
3. Create a feature branch
4. Make changes
5. Push to your fork
6. Create a pull request

### Code Review

- Review all pull requests
- Test changes before merging
- Ensure documentation is updated
- Check for security issues

## 📞 Support

For issues with the repository setup:
1. Check this documentation
2. Review GitHub's official documentation
3. Open an issue in the repository
4. Contact the project maintainers
