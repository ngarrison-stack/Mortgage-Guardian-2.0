#!/bin/bash

echo "🚀 GitHub Repository Setup"
echo "========================"
echo ""

# Get GitHub username
read -p "Enter your GitHub username: " github_username

# Repository name
read -p "Enter repository name (default: Mortgage-Guardian-2.0): " repo_name
repo_name=${repo_name:-Mortgage-Guardian-2.0}

# Set up remote
echo -e "\nSetting up remote..."
git remote add origin "https://github.com/${github_username}/${repo_name}.git"

echo -e "\n✅ Remote configured!"
echo -e "\n📋 Next steps:"
echo "1. Create a new PRIVATE repository on GitHub:"
echo "   https://github.com/new"
echo ""
echo "   Repository name: ${repo_name}"
echo "   Description: Financial-grade mortgage protection platform"
echo "   ⚠️  Set to PRIVATE"
echo "   ⚠️  Do NOT initialize with README, .gitignore, or license"
echo ""
echo "2. After creating the repository, run:"
echo "   git push -u origin main"
echo ""
echo "3. Optional: Set up SSH for more secure access:"
echo "   git remote set-url origin git@github.com:${github_username}/${repo_name}.git"

git remote -v
