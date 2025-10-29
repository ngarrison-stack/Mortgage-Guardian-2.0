#!/bin/bash

# GitHub Push Setup Script
# Automatically configures and pushes to GitHub

set -e

echo "🚀 Mortgage Guardian - GitHub Setup & Push"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Check if remote exists
if git remote get-url origin &>/dev/null; then
    echo -e "${YELLOW}Remote 'origin' already exists:${NC}"
    git remote get-url origin
    echo ""
    read -p "Do you want to push to this remote? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SKIP_REMOTE_SETUP=true
    else
        echo "Removing existing remote..."
        git remote remove origin
        SKIP_REMOTE_SETUP=false
    fi
else
    SKIP_REMOTE_SETUP=false
fi

if [ "$SKIP_REMOTE_SETUP" = false ]; then
    # Get GitHub username
    echo -e "${BLUE}Enter your GitHub username:${NC}"
    read github_username

    # Repository name
    echo -e "${BLUE}Enter repository name (press Enter for 'Mortgage-Guardian-2.0'):${NC}"
    read repo_name
    repo_name=${repo_name:-Mortgage-Guardian-2.0}

    # Choose connection method
    echo -e "\n${BLUE}Choose connection method:${NC}"
    echo "1) HTTPS (easier, works everywhere)"
    echo "2) SSH (more secure, recommended for regular use)"
    read -p "Enter choice [1-2]: " connection

    if [ "$connection" = "2" ]; then
        # SSH setup
        git remote add origin "git@github.com:${github_username}/${repo_name}.git"
        echo -e "${GREEN}✅ SSH remote added${NC}"

        # Check for SSH key
        if [ ! -f ~/.ssh/id_ed25519 ] && [ ! -f ~/.ssh/id_rsa ]; then
            echo -e "${YELLOW}⚠️  No SSH key found. Creating one...${NC}"
            ssh-keygen -t ed25519 -C "your_email@example.com" -f ~/.ssh/id_ed25519 -N ""
            echo -e "${GREEN}✅ SSH key created${NC}"
            echo -e "${YELLOW}Add this key to GitHub:${NC}"
            cat ~/.ssh/id_ed25519.pub
            echo -e "\n${BLUE}Steps:${NC}"
            echo "1. Copy the key above"
            echo "2. Go to https://github.com/settings/keys"
            echo "3. Click 'New SSH key'"
            echo "4. Paste the key and save"
            echo ""
            read -p "Press Enter after adding the key to GitHub..."
        fi
    else
        # HTTPS setup
        git remote add origin "https://github.com/${github_username}/${repo_name}.git"
        echo -e "${GREEN}✅ HTTPS remote added${NC}"
    fi

    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}IMPORTANT: Create the repository on GitHub first!${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}1. Open this link in your browser:${NC}"
    echo -e "   ${GREEN}https://github.com/new${NC}"
    echo ""
    echo -e "${BLUE}2. Create repository with these settings:${NC}"
    echo -e "   Repository name: ${GREEN}${repo_name}${NC}"
    echo -e "   Description: ${GREEN}Financial-grade mortgage protection platform${NC}"
    echo -e "   ${RED}⚠️  IMPORTANT: Set to PRIVATE${NC}"
    echo -e "   ${RED}⚠️  Do NOT initialize with README${NC}"
    echo -e "   ${RED}⚠️  Do NOT add .gitignore${NC}"
    echo -e "   ${RED}⚠️  Do NOT add license${NC}"
    echo ""
    read -p "Press Enter after creating the repository on GitHub..."
fi

# Show what will be pushed
echo -e "\n${BLUE}📦 Repository Summary:${NC}"
echo "========================"
git log --oneline -10
echo ""
echo -e "${BLUE}Files: $(git ls-files | wc -l)${NC}"
echo -e "${BLUE}Size: $(du -sh . | cut -f1)${NC}"
echo -e "${BLUE}Commits: $(git rev-list --count HEAD)${NC}"

# Confirm push
echo -e "\n${YELLOW}Ready to push to GitHub!${NC}"
echo -e "This will push ${GREEN}$(git rev-list --count HEAD) commits${NC} to ${GREEN}$(git remote get-url origin)${NC}"
read -p "Continue? (y/n): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Push cancelled${NC}"
    exit 1
fi

# Push to GitHub
echo -e "\n${BLUE}Pushing to GitHub...${NC}"
echo "========================"

# Try to push
if git push -u origin main 2>&1 | tee /tmp/push_output.txt; then
    echo -e "\n${GREEN}✅ Successfully pushed to GitHub!${NC}"
    echo ""
    echo -e "${GREEN}🎉 Your repository is now live at:${NC}"

    # Extract URL from remote
    remote_url=$(git remote get-url origin)
    if [[ $remote_url == git@github.com:* ]]; then
        # Convert SSH to HTTPS URL
        repo_path=${remote_url#git@github.com:}
        repo_path=${repo_path%.git}
        echo -e "${BLUE}https://github.com/${repo_path}${NC}"
    elif [[ $remote_url == https://github.com/* ]]; then
        # Clean HTTPS URL
        echo -e "${BLUE}${remote_url%.git}${NC}"
    else
        echo -e "${BLUE}${remote_url}${NC}"
    fi

    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "1. ⚙️  Go to Settings → Secrets and add:"
    echo "   - ANTHROPIC_API_KEY"
    echo "   - PLAID_CLIENT_ID and PLAID_SECRET"
    echo "   - Any other API keys"
    echo ""
    echo "2. 🔒 Set up branch protection:"
    echo "   - Settings → Branches → Add rule"
    echo "   - Require pull request reviews"
    echo "   - Require status checks"
    echo ""
    echo "3. 👥 Add collaborators if working with a team:"
    echo "   - Settings → Manage access → Invite"
    echo ""
    echo "4. 🚀 Enable GitHub Actions:"
    echo "   - Actions tab → Enable workflows"
    echo ""
    echo -e "${GREEN}🏆 Congratulations! Your financial-grade platform is now on GitHub!${NC}"
else
    # Check for common errors
    if grep -q "repository not found" /tmp/push_output.txt 2>/dev/null; then
        echo -e "\n${RED}❌ Error: Repository not found${NC}"
        echo "Please make sure you created the repository on GitHub first!"
        echo "Go to: https://github.com/new"
    elif grep -q "Permission denied" /tmp/push_output.txt 2>/dev/null; then
        echo -e "\n${RED}❌ Error: Permission denied${NC}"
        echo "Please check your GitHub credentials or SSH keys"
    elif grep -q "rejected" /tmp/push_output.txt 2>/dev/null; then
        echo -e "\n${RED}❌ Error: Push rejected${NC}"
        echo "The repository might already have content. Try:"
        echo "  git pull origin main --allow-unrelated-histories"
        echo "  git push origin main"
    else
        echo -e "\n${RED}❌ Push failed. Check the error above.${NC}"
    fi
    exit 1
fi

# Clean up
rm -f /tmp/push_output.txt

echo -e "\n${GREEN}✨ All done!${NC}"