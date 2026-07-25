#!/usr/bin/env bash
set -euo pipefail

###############################################################
# Jenkins Installation Script - Ubuntu 22.04 / 24.04
#
# Features
#  - Safe to run multiple times (Idempotent)
#  - Verifies each installation step
#  - Repairs Jenkins repository if required
#  - Uses Jenkins 2026 Repository Key
#  - Automatically prints Jenkins URL
#  - Automatically prints Initial Admin Password
#
# Prerequisites
#  - Ubuntu 22.04 / 24.04
#  - Run as root or sudo
#  - Allow TCP Port 8080 in Security Group
###############################################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

skip() {
    echo -e "${YELLOW}[SKIPPED]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

fail() {
    echo -e "${RED}[FAILED]${NC} $1"
    exit 1
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Please run using sudo."
        exit 1
    fi
}

require_root

echo "=============================================================="
echo "        Jenkins Installation Automation - Ubuntu"
echo "=============================================================="

###############################################################
# Update Ubuntu Repository
###############################################################

info "Updating Ubuntu Package Repository..."

apt update -y

success "APT repository updated."

###############################################################
# Install Required Utilities
###############################################################

PACKAGES=(
wget
curl
tree
gnupg
fontconfig
software-properties-common
)

for pkg in "${PACKAGES[@]}"
do
    if dpkg -s "$pkg" >/dev/null 2>&1
    then
        skip "$pkg already installed."
    else
        info "Installing $pkg..."
        apt install -y "$pkg"

        if dpkg -s "$pkg" >/dev/null 2>&1
        then
            success "$pkg installed."
        else
            fail "$pkg installation failed."
        fi
    fi
done

###############################################################
# Install Java
###############################################################

echo
info "Checking Java..."

if dpkg -s openjdk-21-jre >/dev/null 2>&1
then
    skip "OpenJDK 21 JRE already installed."
else
    info "Installing OpenJDK 21 JRE..."

    apt install -y openjdk-21-jre

    if dpkg -s openjdk-21-jre >/dev/null 2>&1
    then
        success "OpenJDK 21 JRE installed."
    else
        fail "Java installation failed."
    fi
fi

echo
java -version

###############################################################
# Configure Jenkins Repository
###############################################################

echo
info "Configuring Jenkins Repository..."

mkdir -p /etc/apt/keyrings

wget -q -O /etc/apt/keyrings/jenkins-keyring.asc \
https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

chmod 644 /etc/apt/keyrings/jenkins-keyring.asc

cat >/etc/apt/sources.list.d/jenkins.list <<EOF
deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/
EOF

success "Jenkins Repository Configured."

###############################################################
# Update Repository
###############################################################

echo
info "Updating Repository..."

apt update -y

success "Repository Updated."

###############################################################
# Install Jenkins
###############################################################

echo
info "Checking Jenkins..."

if dpkg -s jenkins >/dev/null 2>&1
then
    skip "Jenkins already installed."
else

    info "Installing Jenkins..."

    apt install -y jenkins

    if dpkg -s jenkins >/dev/null 2>&1
    then
        success "Jenkins installed successfully."
    else
        fail "Jenkins installation failed."
    fi

fi

###############################################################
# Enable Jenkins
###############################################################

echo
info "Enabling Jenkins Service..."

if systemctl is-enabled jenkins >/dev/null 2>&1
then
    skip "Jenkins service already enabled."
else
    systemctl enable jenkins
    success "Jenkins service enabled."
fi

###############################################################
# Start Jenkins
###############################################################

echo
info "Starting Jenkins..."

if systemctl is-active --quiet jenkins
then
    skip "Jenkins service already running."
else
    systemctl start jenkins
fi

sleep 10

if systemctl is-active --quiet jenkins
then
    success "Jenkins service is running."
else
    fail "Jenkins service failed to start."
fi

###############################################################
# Verify Port
###############################################################

echo
info "Checking Jenkins Port..."

if ss -tln | grep -q ":8080"
then
    success "Jenkins listening on port 8080."
else
    fail "Jenkins is not listening on port 8080."
fi

###############################################################
# Public IP
###############################################################

echo
info "Fetching Public IP..."

PUBLIC_IP=$(curl -s ipinfo.io/ip)

###############################################################
# Admin Password
###############################################################

if [[ -f /var/lib/jenkins/secrets/initialAdminPassword ]]
then
    PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
else
    PASSWORD="Jenkins is still initializing. Check after 30-60 seconds."
fi

###############################################################
# Jenkins Version
###############################################################

JENKINS_VERSION=$(dpkg-query -W -f='${Version}' jenkins 2>/dev/null || echo "Not Available")

###############################################################
# Summary
###############################################################

echo
echo "=============================================================="
echo "                 INSTALLATION SUMMARY"
echo "=============================================================="

echo "Operating System : $(lsb_release -ds)"
echo "Hostname         : $(hostname)"
echo "Public IP        : ${PUBLIC_IP}"
echo "Java Version     : $(java -version 2>&1 | head -1)"
echo "Jenkins Version  : ${JENKINS_VERSION}"
echo

echo "Jenkins URL"
echo "--------------------------------------------------------------"
echo "http://${PUBLIC_IP}:8080"

echo
echo "Initial Admin Password"
echo "--------------------------------------------------------------"
echo "${PASSWORD}"

echo
echo "Useful Commands"
echo "--------------------------------------------------------------"
echo "systemctl status jenkins"
echo "systemctl restart jenkins"
echo "systemctl stop jenkins"
echo "journalctl -u jenkins -f"

echo
echo "Open Browser"
echo "--------------------------------------------------------------"
echo "http://${PUBLIC_IP}:8080"

echo
echo "Next Steps"
echo "--------------------------------------------------------------"
echo "1. Open Jenkins URL"
echo "2. Paste Initial Admin Password"
echo "3. Click 'Install Suggested Plugins'"
echo "4. Create First Admin User"
echo "5. Save and Continue"
echo "6. Save and Finish"
echo "7. Start using Jenkins"

echo
echo "=============================================================="
success "Jenkins Installation Completed Successfully."
echo "=============================================================="
