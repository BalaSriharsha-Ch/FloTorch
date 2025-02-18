# 🚀 Setup Guide: Install Essential Tools on Ubuntu, Mac, and Windows system

## **🔹 Ubuntu/Linux Setup**
### **Step-by-Step Manual Installation**
```bash
# Update package list
sudo apt-get update

# Install Docker
sudo apt-get install -y docker.io

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Python
sudo apt-get install -y python3 python3-pip



🔹 Easy Installation via Script:
Run the following script to automate the installation process.This script detects the OS and installs Docker, AWS CLI, and Python accordingly.
***********************************************************************************************************************************************
#!/bin/bash

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        echo "Cannot detect OS"
        exit 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Docker
install_docker() {
    # Check if Docker is already installed
    if command_exists docker; then
        echo "Docker is already installed"
        docker --version
        return 0
    fi

    echo "Installing Docker..."
    
    # OS-specific Docker installation
    if [[ "$OS" == "Ubuntu" ]]; then
        # Ubuntu Docker installation
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    elif [[ "$OS" == "Amazon Linux" ]]; then
        # Amazon Linux Docker installation
        sudo yum update -y
        sudo yum install -y docker

        # Attempt multiple methods to start Docker
        sudo service docker start || \
        sudo systemctl start docker || \

        # Ensure Docker starts on boot
        sudo systemctl enable docker || true
    fi

    # Ensure current user can run Docker without sudo
    sudo usermod -aG docker $USER

    # Set proper permissions on Docker socket
    sudo chmod 666 /var/run/docker.sock

    # Verify Docker installation
    if command_exists docker; then
        echo "Docker installed successfully"
        docker --version
    else
        echo "Docker installation failed"
        return 1
    fi
}

# Function to install AWS CLI
install_awscli() {
    if command_exists aws; then
        echo "AWS CLI is already installed"
        aws --version
    else
        echo "Installing AWS CLI..."
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        sudo apt install -y unzip || sudo yum install -y unzip
        unzip awscliv2.zip
        sudo ./aws/install
        rm -rf aws awscliv2.zip
    fi
}

# Function to install Python
install_python() {
    if command_exists python3; then
        echo "Python is already installed"
        python3 --version
    else
        echo "Installing Python..."
        if [[ "$OS" == "Ubuntu" ]]; then
            sudo apt-get update
            sudo apt-get install -y python3 python3-pip
        elif [[ "$OS" == "Amazon Linux" ]]; then
            sudo yum update -y
            sudo yum install -y python3 python3-pip
        fi
    fi
}

# Main installation process
main() {
    echo "Detecting OS..."
    detect_os
    echo "Detected OS: $OS"

    # Update package manager
    if [[ "$OS" == "Ubuntu" ]]; then
        sudo apt-get update
    elif [[ "$OS" == "Amazon Linux" ]]; then
        sudo yum update -y
    else
        echo "Unsupported OS"
        exit 1
    fi

    # Install components
    install_docker
    install_awscli
    install_python

    echo "All installations completed!"
    
    # Additional system configuration
    echo "Configuring user permissions..."
    
    # Ensure Docker can be run without sudo
    if command_exists docker; then
        echo "Adding $USER to docker group..."
        sudo usermod -aG docker $USER
        
        # Inform about group change
        echo "You may need to log out and log back in for group changes to take effect."
    fi
}

# Run main function
main
EOF


🔹 macOS Setup
Run these commands in the macOS terminal to install Docker, AWS CLI, and Python.
********************************************************************************
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Docker
brew install docker

# Install AWS CLI
brew install awscli

# Install Python
brew install python


🔹 Windows Setup
Run these commands in a PowerShell terminal with Administrator privileges.
*****************************************************************************
# Install Chocolatey (if not already installed)
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Docker Desktop
choco install docker-desktop

# Install AWS CLI
choco install awscli

# Install Python
choco install python
