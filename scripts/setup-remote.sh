#!/bin/bash

# Remote Repository Setup Script
# Supports GitHub, GitLab, Bitbucket, and self-hosted Git

set -e

echo "🚀 Mortgage Guardian - Remote Repository Setup"
echo "=============================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check if remote exists
check_remote() {
    if git remote get-url origin &>/dev/null; then
        echo -e "${YELLOW}⚠️  Remote 'origin' already exists${NC}"
        git remote get-url origin
        read -p "Do you want to replace it? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git remote remove origin
        else
            echo "Keeping existing remote"
            exit 0
        fi
    fi
}

# Main menu
echo -e "${BLUE}Select your Git hosting provider:${NC}"
echo "1) GitHub"
echo "2) GitLab"
echo "3) Bitbucket"
echo "4) Self-hosted Git"
echo "5) Azure DevOps"
echo "6) AWS CodeCommit"
echo ""

read -p "Enter choice [1-6]: " choice

case $choice in
    1)
        # GitHub setup
        echo -e "\n${GREEN}Setting up GitHub repository${NC}"
        read -p "Enter your GitHub username: " username
        read -p "Enter repository name (default: Mortgage-Guardian-2.0): " repo_name
        repo_name=${repo_name:-Mortgage-Guardian-2.0}

        echo -e "\n${YELLOW}Choose connection method:${NC}"
        echo "1) HTTPS (easier)"
        echo "2) SSH (more secure - recommended)"
        read -p "Enter choice [1-2]: " connection

        check_remote

        if [ "$connection" = "2" ]; then
            git remote add origin "git@github.com:${username}/${repo_name}.git"
            echo -e "${GREEN}✅ SSH remote added${NC}"
            echo -e "${YELLOW}Make sure you have SSH keys configured:${NC}"
            echo "  ssh-keygen -t ed25519 -C \"your_email@example.com\""
            echo "  cat ~/.ssh/id_ed25519.pub"
            echo "  Add the key to GitHub: Settings → SSH and GPG keys"
        else
            git remote add origin "https://github.com/${username}/${repo_name}.git"
            echo -e "${GREEN}✅ HTTPS remote added${NC}"
        fi

        echo -e "\n${BLUE}To create the repository on GitHub:${NC}"
        echo "1. Go to https://github.com/new"
        echo "2. Name: ${repo_name}"
        echo "3. Set to PRIVATE"
        echo "4. Don't initialize with README"
        echo "5. Run: git push -u origin main"
        ;;

    2)
        # GitLab setup
        echo -e "\n${GREEN}Setting up GitLab repository${NC}"
        read -p "GitLab instance (default: gitlab.com): " instance
        instance=${instance:-gitlab.com}
        read -p "Enter your GitLab username: " username
        read -p "Enter repository name: " repo_name

        echo -e "\n${YELLOW}Choose connection method:${NC}"
        echo "1) HTTPS"
        echo "2) SSH (recommended)"
        read -p "Enter choice [1-2]: " connection

        check_remote

        if [ "$connection" = "2" ]; then
            git remote add origin "git@${instance}:${username}/${repo_name}.git"
        else
            git remote add origin "https://${instance}/${username}/${repo_name}.git"
        fi

        echo -e "${GREEN}✅ GitLab remote added${NC}"
        ;;

    3)
        # Bitbucket setup
        echo -e "\n${GREEN}Setting up Bitbucket repository${NC}"
        read -p "Enter your Bitbucket username: " username
        read -p "Enter repository name: " repo_name

        echo -e "\n${YELLOW}Choose connection method:${NC}"
        echo "1) HTTPS"
        echo "2) SSH (recommended)"
        read -p "Enter choice [1-2]: " connection

        check_remote

        if [ "$connection" = "2" ]; then
            git remote add origin "git@bitbucket.org:${username}/${repo_name}.git"
        else
            git remote add origin "https://bitbucket.org/${username}/${repo_name}.git"
        fi

        echo -e "${GREEN}✅ Bitbucket remote added${NC}"
        ;;

    4)
        # Self-hosted setup
        echo -e "\n${GREEN}Setting up self-hosted Git repository${NC}"
        read -p "Enter Git server address: " server
        read -p "Enter repository path: " repo_path

        check_remote

        git remote add origin "${server}:${repo_path}"

        echo -e "${GREEN}✅ Self-hosted remote added${NC}"
        ;;

    5)
        # Azure DevOps setup
        echo -e "\n${GREEN}Setting up Azure DevOps repository${NC}"
        read -p "Enter organization name: " org
        read -p "Enter project name: " project
        read -p "Enter repository name: " repo_name

        check_remote

        git remote add origin "https://dev.azure.com/${org}/${project}/_git/${repo_name}"

        echo -e "${GREEN}✅ Azure DevOps remote added${NC}"
        echo -e "${YELLOW}Note: You'll need to set up credentials:${NC}"
        echo "  git config --global credential.helper manager-core"
        ;;

    6)
        # AWS CodeCommit setup
        echo -e "\n${GREEN}Setting up AWS CodeCommit repository${NC}"
        read -p "Enter AWS region: " region
        read -p "Enter repository name: " repo_name

        check_remote

        git remote add origin "https://git-codecommit.${region}.amazonaws.com/v1/repos/${repo_name}"

        echo -e "${GREEN}✅ AWS CodeCommit remote added${NC}"
        echo -e "${YELLOW}Note: Configure AWS CLI credentials:${NC}"
        echo "  aws configure"
        echo "  git config --global credential.helper '!aws codecommit credential-helper $@'"
        ;;

    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}Remote configuration complete!${NC}"
echo -e "\n${BLUE}Current remotes:${NC}"
git remote -v

echo -e "\n${BLUE}Next steps:${NC}"
echo "1. Create the repository on your chosen platform"
echo "2. Push your code: git push -u origin main"
echo "3. Set up branch protection rules"
echo "4. Enable 2FA on your account"
echo "5. Add collaborators if needed"

# Offer to set up signed commits
echo -e "\n${YELLOW}Set up signed commits for extra security?${NC}"
read -p "(Recommended for financial applications) [y/n]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n${BLUE}Setting up GPG signing...${NC}"

    # Check if GPG key exists
    if ! gpg --list-secret-keys --keyid-format LONG | grep sec &>/dev/null; then
        echo "No GPG key found. Creating one..."
        gpg --full-generate-key
    fi

    # Get the GPG key ID
    key_id=$(gpg --list-secret-keys --keyid-format LONG | grep sec | head -1 | awk '{print $2}' | cut -d'/' -f2)

    # Configure Git to use GPG
    git config --global user.signingkey "$key_id"
    git config --global commit.gpgsign true

    echo -e "${GREEN}✅ GPG signing configured${NC}"
    echo -e "${YELLOW}Export your public key and add it to your Git provider:${NC}"
    echo "  gpg --armor --export $key_id"
fi

echo -e "\n${GREEN}✨ Setup complete!${NC}"