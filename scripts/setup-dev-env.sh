#!/bin/bash

# Complete Development Environment Setup
# Sets up everything needed for Mortgage Guardian development

set -e

echo "🔧 Mortgage Guardian - Development Environment Setup"
echo "===================================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Detect OS
OS="Unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="Linux"
else
    echo -e "${RED}Unsupported OS: $OSTYPE${NC}"
    exit 1
fi

echo -e "${BLUE}Detected OS: $OS${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install tool
install_tool() {
    local tool=$1
    local install_cmd=$2

    if command_exists "$tool"; then
        echo -e "${GREEN}✓ $tool already installed${NC}"
    else
        echo -e "${YELLOW}Installing $tool...${NC}"
        eval "$install_cmd"
        if command_exists "$tool"; then
            echo -e "${GREEN}✓ $tool installed successfully${NC}"
        else
            echo -e "${RED}✗ Failed to install $tool${NC}"
            return 1
        fi
    fi
}

# ==================== Package Managers ====================

echo -e "\n${BLUE}=== Installing Package Managers ===${NC}"

if [[ "$OS" == "macOS" ]]; then
    # Install Homebrew
    if ! command_exists brew; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo -e "${GREEN}✓ Homebrew already installed${NC}"
        brew update
    fi
fi

# ==================== Core Development Tools ====================

echo -e "\n${BLUE}=== Installing Core Development Tools ===${NC}"

# Git
install_tool "git" "brew install git || sudo apt-get install -y git"

# Node.js and npm
if ! command_exists node; then
    echo "Installing Node.js..."
    if [[ "$OS" == "macOS" ]]; then
        brew install node@18
    else
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
else
    echo -e "${GREEN}✓ Node.js $(node --version) installed${NC}"
fi

# Python
install_tool "python3" "brew install python3 || sudo apt-get install -y python3 python3-pip"

# Docker
if ! command_exists docker; then
    echo "Installing Docker..."
    if [[ "$OS" == "macOS" ]]; then
        brew install --cask docker
        echo -e "${YELLOW}Please start Docker Desktop manually${NC}"
    else
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
    fi
else
    echo -e "${GREEN}✓ Docker already installed${NC}"
fi

# ==================== iOS Development (macOS only) ====================

if [[ "$OS" == "macOS" ]]; then
    echo -e "\n${BLUE}=== Setting up iOS Development ===${NC}"

    # Check for Xcode
    if ! xcode-select -p &>/dev/null; then
        echo -e "${YELLOW}Xcode Command Line Tools not installed${NC}"
        xcode-select --install
        echo "Please complete the installation and run this script again"
        exit 1
    else
        echo -e "${GREEN}✓ Xcode Command Line Tools installed${NC}"
    fi

    # CocoaPods
    if ! command_exists pod; then
        echo "Installing CocoaPods..."
        sudo gem install cocoapods
    else
        echo -e "${GREEN}✓ CocoaPods installed${NC}"
    fi

    # Fastlane
    if ! command_exists fastlane; then
        echo "Installing Fastlane..."
        brew install fastlane
    else
        echo -e "${GREEN}✓ Fastlane installed${NC}"
    fi
fi

# ==================== Backend Dependencies ====================

echo -e "\n${BLUE}=== Installing Backend Dependencies ===${NC}"

cd backend-express

# Install Node.js dependencies
echo "Installing Node.js packages..."
npm ci

# Install global tools
echo "Installing global Node.js tools..."
npm install -g nodemon pm2 typescript eslint

cd ..

# ==================== Frontend Dependencies ====================

echo -e "\n${BLUE}=== Installing Frontend Dependencies ===${NC}"

if [ -d "frontend" ]; then
    cd frontend
    npm ci
    cd ..
fi

# ==================== Database Setup ====================

echo -e "\n${BLUE}=== Setting up Databases ===${NC}"

# PostgreSQL
if ! command_exists psql; then
    echo "Installing PostgreSQL..."
    if [[ "$OS" == "macOS" ]]; then
        brew install postgresql@15
        brew services start postgresql@15
    else
        sudo apt-get install -y postgresql postgresql-contrib
        sudo systemctl start postgresql
    fi
else
    echo -e "${GREEN}✓ PostgreSQL installed${NC}"
fi

# Redis
if ! command_exists redis-cli; then
    echo "Installing Redis..."
    if [[ "$OS" == "macOS" ]]; then
        brew install redis
        brew services start redis
    else
        sudo apt-get install -y redis-server
        sudo systemctl start redis-server
    fi
else
    echo -e "${GREEN}✓ Redis installed${NC}"
fi

# ==================== Security Tools ====================

echo -e "\n${BLUE}=== Installing Security Tools ===${NC}"

# GPG
install_tool "gpg" "brew install gnupg || sudo apt-get install -y gnupg"

# OpenSSL
install_tool "openssl" "brew install openssl || sudo apt-get install -y openssl"

# Vault (HashiCorp)
if ! command_exists vault; then
    echo "Installing HashiCorp Vault..."
    if [[ "$OS" == "macOS" ]]; then
        brew tap hashicorp/tap
        brew install hashicorp/tap/vault
    else
        wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update && sudo apt install vault
    fi
else
    echo -e "${GREEN}✓ Vault installed${NC}"
fi

# ==================== Environment Configuration ====================

echo -e "\n${BLUE}=== Setting up Environment Configuration ===${NC}"

# Create .env.local if it doesn't exist
if [ ! -f .env.local ]; then
    echo "Creating .env.local file..."
    cat > .env.local << 'EOF'
# Development Environment Configuration
# =====================================

# Server Configuration
NODE_ENV=development
PORT=3000
HOST=localhost

# Database Configuration
DATABASE_URL=postgresql://localhost:5432/mortgage_guardian_dev
REDIS_URL=redis://localhost:6379

# Security Configuration
JWT_SECRET=dev-jwt-secret-change-in-production
ENCRYPTION_KEY=dev-encryption-key-32-bytes-long!!
SESSION_SECRET=dev-session-secret-change-this!!!

# Plaid Configuration (Sandbox)
PLAID_CLIENT_ID=your-plaid-client-id
PLAID_SECRET=your-plaid-secret
PLAID_ENV=sandbox

# AI Services
ANTHROPIC_API_KEY=your-anthropic-key
OPENAI_API_KEY=your-openai-key

# Feature Flags
ENABLE_DEBUG=true
ENABLE_LOGGING=true
ENABLE_PLAID=true
ENABLE_AI=true

# Monitoring
LOG_LEVEL=debug
EOF
    echo -e "${GREEN}✓ .env.local created${NC}"
    echo -e "${YELLOW}⚠️  Please update .env.local with your actual API keys${NC}"
else
    echo -e "${GREEN}✓ .env.local already exists${NC}"
fi

# Create necessary directories
echo "Creating project directories..."
mkdir -p logs
mkdir -p secrets
mkdir -p vault
mkdir -p .keys
mkdir -p data/backups

# Set proper permissions
chmod 700 secrets vault .keys
chmod 755 logs data

# ==================== Database Initialization ====================

echo -e "\n${BLUE}=== Initializing Databases ===${NC}"

# Create PostgreSQL database
if command_exists psql; then
    echo "Creating PostgreSQL database..."
    createdb mortgage_guardian_dev 2>/dev/null || echo "Database already exists"
    createdb mortgage_guardian_test 2>/dev/null || echo "Test database already exists"
fi

# ==================== Git Hooks ====================

echo -e "\n${BLUE}=== Setting up Git Hooks ===${NC}"

# Pre-commit hook for security checks
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

# Security pre-commit hook

echo "Running security checks..."

# Check for secrets
if git diff --cached --name-only | xargs grep -E "(password|secret|key|token|api_key).*=.*['\"]" 2>/dev/null; then
    echo "❌ Potential secrets detected in commit!"
    echo "Please review your changes and use environment variables instead"
    exit 1
fi

# Check for private keys
if git diff --cached --name-only | grep -E "\.(pem|key|p12|pfx)$"; then
    echo "❌ Private key files detected!"
    echo "Never commit private keys to the repository"
    exit 1
fi

# Run linting
if command -v eslint >/dev/null 2>&1; then
    echo "Running ESLint..."
    git diff --cached --name-only --diff-filter=ACM | grep "\.js$" | xargs eslint
fi

echo "✅ Security checks passed"
EOF

chmod +x .git/hooks/pre-commit

echo -e "${GREEN}✓ Git hooks configured${NC}"

# ==================== VS Code Configuration ====================

echo -e "\n${BLUE}=== Setting up VS Code ===${NC}"

mkdir -p .vscode

# VS Code settings
cat > .vscode/settings.json << 'EOF'
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  "files.exclude": {
    "**/node_modules": true,
    "**/.git": true,
    "**/build": true,
    "**/dist": true,
    "**/.next": true
  },
  "search.exclude": {
    "**/node_modules": true,
    "**/bower_components": true,
    "**/coverage": true,
    "**/dist": true,
    "**/build": true,
    "**/.build": true,
    "**/.gh-pages": true
  },
  "typescript.tsdk": "node_modules/typescript/lib",
  "eslint.validate": [
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact"
  ],
  "files.associations": {
    "*.js": "javascript",
    "*.jsx": "javascriptreact",
    "*.ts": "typescript",
    "*.tsx": "typescriptreact"
  }
}
EOF

# VS Code extensions
cat > .vscode/extensions.json << 'EOF'
{
  "recommendations": [
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "ms-vscode.vscode-typescript-tslint-plugin",
    "christian-kohler.path-intellisense",
    "formulahendry.auto-rename-tag",
    "streetsidesoftware.code-spell-checker",
    "wayou.vscode-todo-highlight",
    "gruntfuggly.todo-tree",
    "ms-azuretools.vscode-docker",
    "hashicorp.terraform",
    "ms-vscode-remote.remote-containers",
    "github.copilot",
    "eamodio.gitlens"
  ]
}
EOF

echo -e "${GREEN}✓ VS Code configured${NC}"

# ==================== Testing Setup ====================

echo -e "\n${BLUE}=== Setting up Testing Framework ===${NC}"

# Install testing dependencies
cd backend-express
npm install --save-dev jest supertest @types/jest @types/supertest
cd ..

# ==================== Final Steps ====================

echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}✨ Development Environment Setup Complete!${NC}"
echo -e "${GREEN}============================================${NC}"

echo -e "\n${BLUE}Next steps:${NC}"
echo "1. Update .env.local with your API keys"
echo "2. Start the development servers:"
echo "   - Backend: cd backend-express && npm run dev"
echo "   - Frontend: cd frontend && npm run dev"
echo "3. Access the application at http://localhost:3000"

echo -e "\n${BLUE}Useful commands:${NC}"
echo "  npm run dev        - Start development server"
echo "  npm test           - Run tests"
echo "  npm run build      - Build for production"
echo "  docker-compose up  - Start with Docker"

echo -e "\n${YELLOW}Security reminders:${NC}"
echo "  - Never commit .env.local or secrets"
echo "  - Keep dependencies updated: npm audit fix"
echo "  - Use strong passwords for databases"
echo "  - Enable 2FA on all accounts"

echo -e "\n${GREEN}Happy coding! 🚀${NC}"