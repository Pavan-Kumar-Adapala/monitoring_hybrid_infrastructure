#!/bin/bash
# --------------------------------------------------------------------------------------
# This script used to install and set up grafana on a Linux system.
# Author: Pavan Kumar Adapala
# Date: 2025-05-30
# Usage: Run this script as root or with sudo privileges to install Prometheus.
# Ensure the script is run with root privileges
# Version: 1.0
# ---------------------------------------------------------------------------------------

set -e # Exit immediately if a command exits with a non-zero status

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root. Please use sudo or switch to the root user."
        exit 1
    fi
}

check_package_manager() {
    if command -v apt-get &>/dev/null; then
        PACKAGE_MANAGER="apt-get"
    elif command -v yum &>/dev/null; then
        PACKAGE_MANAGER="yum"
    else
        echo "Unsupported package manager. Please install Grafana manually."
        exit 1
    fi
    echo $PACKAGE_MANAGER 
}

install_grafana_for_debian_vms() {
    # Install the prerequisite packages
    sudo apt-get install -y apt-transport-https software-properties-common wget

    # Import the GPG key
    sudo mkdir -p /etc/apt/keyrings/
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

    # To add a repository for stable releases, This adds the Grafana repository using APT:
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

    # Updates the list of available packages
    sudo apt-get update
    # Installs Grafana
    sudo apt-get install -y grafana
    # Enable and start the Grafana service
    sudo systemctl enable grafana-server
    sudo systemctl start grafana-server
    # Check the status of the Grafana service
    sudo systemctl status grafana-server
    echo "Grafana has been installed and started successfully."
}   

install_grafana_for_redhat_vms() {
    # Import the GPG key
    wget -q -O gpg.key https://rpm.grafana.com/gpg.key
    sudo rpm --import gpg.key
    # Create the Grafana repository file
    sudo touch /etc/yum.repos.d/grafana.repo
    # Add the repository configuration to the file
    cat <<EOF >/etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
    # To install Grafana OSS, run the following command:
    sudo dnf install -y grafana
    # Enable and start the Grafana service
    sudo systemctl enable grafana-server
    sudo systemctl start grafana-server
    # Check the status of the Grafana service
    sudo systemctl status grafana-server
    echo "Grafana has been installed and started successfully."
    echo "Please open your web browser and navigate to http://<your-server-ip>:3000 to access Grafana."
    echo "Default login credentials are admin/admin. Please change the password after the first login." 
}   

# Main script execution
main() {
    check_root
    PACKAGE_MANAGER=$(check_package_manager)
    if command -v grafana-server &>/dev/null; then
        echo "Grafana is already installed."
        echo "Version: $(grafana-server -v)"
    else
        echo "Installing Grafana..."
        if [[ $PACKAGE_MANAGER == "apt-get" ]]; then
            echo "Apt package manager detected. Proceeding with Grafana installation."
            install_grafana_for_debian_vms
        elif [[ $PACKAGE_MANAGER == "yum" ]]; then
            echo "Yum package manager detected. Please install Grafana manually."
            install_grafana_for_redhat_vms
        else
            echo "Unsupported package manager. Please install Grafana manually."
            exit 1
        fi
    fi
    # Check if Grafana is running
    if systemctl is-active --quiet grafana-server; then
        echo "Grafana is running."
    else
        echo "Grafana is not running. Please check the service status."
        systemctl status grafana-server
    fi
    echo "Grafana installation and setup completed successfully."
}

main "$@"
# --------------------------------------------------------------------------------------
# End of script
# --------------------------------------------------------------------------------------
