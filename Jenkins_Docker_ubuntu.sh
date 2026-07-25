#!/bin/bash
################################################################################
# Name        : Jenkins + Docker Installation Script (EC2 User Data)
# Description : Installs Java, Jenkins and Docker on Ubuntu 22.04/24.04
# Author      : Newton
#
# Features
#   ✓ Safe to run multiple times
#   ✓ Creates installation log
#   ✓ Installs Docker
#   ✓ Installs Jenkins
#   ✓ Enables & Starts Services
#   ✓ Displays Jenkins URL
#   ✓ Displays Initial Admin Password
#
# Logs
#   /var/log/user-data.log
#   /home/ubuntu/user-data.log
################################################################################

exec > >(tee -a /var/log/user-data.log /home/ubuntu/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

set -e

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
NC="\e[0m"

success(){
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

skip(){
    echo -e "${YELLOW}[SKIPPED]${NC} $1"
}

info(){
    echo -e "${BLUE}[INFO]${NC} $1"
}

fail(){
    echo -e "${RED}[FAILED]${NC} $1"
    exit 1
}

echo "====================================================================="
echo "        EC2 USER DATA - JENKINS + DOCKER INSTALLATION"
echo "====================================================================="

################################################################################
# Update Packages
################################################################################

info "Updating Ubuntu..."

apt-get update -y
apt-get upgrade -y

success "Ubuntu Updated"

################################################################################
# Install Required Packages
################################################################################

PACKAGES=(
wget
curl
tree
gnupg
fontconfig
software-properties-common
ca-certificates
)

for pkg in "${PACKAGES[@]}"
do
    if dpkg -s "$pkg" >/dev/null 2>&1
    then
        skip "$pkg already installed."
    else
        info "Installing $pkg"

        apt-get install -y "$pkg"

        success "$pkg installed."
    fi
done

################################################################################
# Install Java
################################################################################

if dpkg -s openjdk-21-jre >/dev/null 2>&1
then
    skip "Java Already Installed"
else

    info "Installing Java 21"

    apt-get install -y openjdk-21-jre

    success "Java Installed"

fi

java -version

################################################################################
# Configure Jenkins Repository
################################################################################

info "Configuring Jenkins Repository"

mkdir -p /etc/apt/keyrings

wget -q -O /etc/apt/keyrings/jenkins-keyring.asc \
https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

cat <<EOF >/etc/apt/sources.list.d/jenkins.list
deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/
EOF

chmod 644 /etc/apt/keyrings/jenkins-keyring.asc

apt-get update -y

success "Jenkins Repository Configured"

################################################################################
# Install Jenkins
################################################################################

if dpkg -s jenkins >/dev/null 2>&1
then
    skip "Jenkins Already Installed"
else

    info "Installing Jenkins"

    apt-get install -y jenkins

    success "Jenkins Installed"

fi

################################################################################
# Enable Jenkins
################################################################################

systemctl daemon-reload
systemctl enable jenkins
systemctl restart jenkins

sleep 15

if systemctl is-active --quiet jenkins
then
    success "Jenkins Service Running"
else
    fail "Jenkins Failed To Start"
fi

################################################################################
# Install Docker
################################################################################

if command -v docker >/dev/null 2>&1
then
    skip "Docker Already Installed"
else

    info "Installing Docker"

    apt-get install -y docker.io

    success "Docker Installed"

fi

################################################################################
# Enable Docker
################################################################################

systemctl enable docker
systemctl restart docker

if systemctl is-active --quiet docker
then
    success "Docker Service Running"
else
    fail "Docker Service Failed"
fi

################################################################################
# Docker Permissions
################################################################################

usermod -aG docker ubuntu

################################################################################
# Versions
################################################################################

JAVA_VERSION=$(java -version 2>&1 | head -1)
DOCKER_VERSION=$(docker --version)
JENKINS_VERSION=$(dpkg-query -W -f='${Version}' jenkins)

################################################################################
# Public IP
################################################################################

PUBLIC_IP=$(curl -s ipinfo.io/ip)

################################################################################
# Wait for Jenkins
################################################################################

echo "Waiting for Jenkins Initialization..."

COUNT=0

while [ ! -f /var/lib/jenkins/secrets/initialAdminPassword ]
do
    sleep 5
    COUNT=$((COUNT+1))

    if [ $COUNT -gt 24 ]
    then
        break
    fi
done

################################################################################
# Jenkins Password
################################################################################

if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]
then
    PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
else
    PASSWORD="Not Available Yet"
fi

################################################################################
# Ownership
################################################################################

chown ubuntu:ubuntu /home/ubuntu/user-data.log

################################################################################
# Summary
################################################################################

echo
echo "====================================================================="
echo "                    INSTALLATION SUMMARY"
echo "====================================================================="

echo "Hostname            : $(hostname)"
echo "Operating System    : $(lsb_release -ds)"
echo "Public IP           : ${PUBLIC_IP}"
echo
echo "Java Version        : ${JAVA_VERSION}"
echo "Docker Version      : ${DOCKER_VERSION}"
echo "Jenkins Version     : ${JENKINS_VERSION}"
echo
echo "Docker Service      : $(systemctl is-active docker)"
echo "Jenkins Service     : $(systemctl is-active jenkins)"
echo

echo "====================================================================="
echo "JENKINS URL"
echo "====================================================================="

echo "http://${PUBLIC_IP}:8080"

echo
echo "====================================================================="
echo "INITIAL ADMIN PASSWORD"
echo "====================================================================="

echo "${PASSWORD}"

echo
echo "====================================================================="
echo "USEFUL COMMANDS"
echo "====================================================================="

echo "systemctl status docker"
echo "systemctl status jenkins"
echo "systemctl restart docker"
echo "systemctl restart jenkins"
echo "journalctl -u docker -f"
echo "journalctl -u jenkins -f"
echo "docker ps"
echo "docker images"

echo
echo "====================================================================="
echo "LOG FILES"
echo "====================================================================="

echo "/var/log/user-data.log"
echo "/home/ubuntu/user-data.log"

echo
echo "====================================================================="
echo "INSTALLATION COMPLETED SUCCESSFULLY"
echo "====================================================================="
