#!/bin/bash
# This script sets up Prometheus Node Exporter on a Linux system.
# Author: Pavan Kumar Adapala
# Date: 2025-05-30
# Usage: Run this script as root or with sudo privileges to install Node Exporter.
# Ensure the script is run with root privileges
# Version: 1.0
# Exit immediately if a command exits with a non-zero status

# The set -e command in a Bash script tells the shell to exit immediately if any command returns a non-zero exit status (i.e., if any command fails).
set -e 

# Function to check if the script is run as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root. Please use sudo or switch to the root user."
        exit 1
    fi
}

# Function to check if Node Exporter is already installed
check_node_exporter_installed() {
    if command -v node_exporter &>/dev/null; then
        echo "Node Exporter is already installed."
        echo "Version: $(node_exporter --version)"
        return 0
    else
        return 1
    fi
}

# Function to create a system user for Node Exporter
create_system_user() {
    local version="$1"
    NODE_EXPORTER_USER="node_exporter_$version"
    if id "$NODE_EXPORTER_USER" &>/dev/null; then
        echo "NODE_EXPORTER_USER '$NODE_EXPORTER_USER' already exists." >&2
    else
        echo "Creating a system user for Node Exporter..." >&2
        useradd --no-create-home --shell /bin/false "$NODE_EXPORTER_USER"
        echo "System user '$NODE_EXPORTER_USER' created successfully." >&2
    fi
    echo "$NODE_EXPORTER_USER" # because the value type is string, otherwise it will return the last command output
}

# Function to install Node Exporter
install_node_exporter() {
    echo "You want install specific version of Node Exporter? (y/n)" >&2
    read -r INSTALL_SPECIFIC_VERSION 
    if [[ "${INSTALL_SPECIFIC_VERSION}" =~ ^[yY]$ ]]; then
        echo "Enter the version you want to install (e.g., v1.2.3):" >&2
        read -r NODE_EXPORTER_VERSION
    else
        # Fetch the latest version from GitHub
        NODE_EXPORTER_VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep '"tag_name":' | cut -d\" -f4)
        echo "Latest Node Exporter version: ${NODE_EXPORTER_VERSION}" >&2
    fi
    # Extract the version number (strip leading 'v' if present)
    NODE_EXPORTER_VERSION_NUMBER=$(echo "${NODE_EXPORTER_VERSION}" | sed 's/^v//')
    # echo "Node Exporter version number: $NODE_EXPORTER_VERSION_NUMBER"

    # Construct the download URL based on the version and version number
    DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION_NUMBER}.linux-amd64.tar.gz"
    echo "Download URL: $DOWNLOAD_URL" >&2

    # Download the Node Exporter tarball
    echo "Downloading Node Exporter from: $DOWNLOAD_URL..." >&2
    # Create a directory in /opt for Node Exporter
    mkdir -p /opt/node_exporter
    echo "Changing directory to /opt/node_exporter..." >&2
    cd /opt/node_exporter || { echo "Failed to change directory to /opt/node_exporter"; exit 1; }

    # Check if wget is installed, if not, install it   
    if ! command -v wget &>/dev/null; then
        echo "wget is not installed. Installing wget..." >&2
        apt-get update && apt-get install -y wget
    fi

    wget --quiet --show-progress "$DOWNLOAD_URL" || { echo "Download failed."; exit 1; }

    echo "Extracting Node Exporter..." >&2
    tar -xzf node_exporter-*.*-amd64.tar.gz
    echo "Node Exporter extracted successfully." >&2

    # copy the binary to /usr/local/bin
    cp node_exporter-*/node_exporter /usr/local/bin/

    # Create a system user for Node Exporter
    NODE_EXPORTER_USER=$(create_system_user "${NODE_EXPORTER_VERSION_NUMBER}") # Function call to create a system user

    echo "Set the ownership to the system user: ${NODE_EXPORTER_USER}" >&2
    chown "$NODE_EXPORTER_USER:$NODE_EXPORTER_USER" /usr/local/bin/node_exporter
    # Clean up the downloaded files
    # rm -rf /opt/node_exporter/node_exporter-*
    echo "Node Exporter installed successfully as user: $NODE_EXPORTER_USER" >&2
    echo "$NODE_EXPORTER_USER"
}

# Function to create a systemd service for Node Exporter
create_systemd_service() {

    local NODE_EXPORTER_USER="$1"
    echo "Creating systemd service for Node Exporter..."
    cat <<EOF >/etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=$NODE_EXPORTER_USER
Group=$NODE_EXPORTER_USER
ExecStart=/usr/local/bin/node_exporter
  # --web.listen-address=":9100" \
  # --web.telemetry-path="/metrics" \
  # --collector.textfile.directory="/var/lib/node_exporter/textfile_collector" \
  # --collector.procfs="/proc" \
  # --collector.sysfs="/sys" \
  # --collector.filesystem.ignored-mount-points="^/(dev|proc|sys|run|var/lib/docker/.+)($|/)" \
  # --collector.filesystem.ignored-fs-types="^(autofs|binfmt_misc|cgroup|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|mqueue|nfsd|overlay|proc|pstore|rpc_pipefs|securityfs|tmpfs)$"

[Install]
WantedBy=multi-user.target
EOF
echo "Node Exporter systemd service created successfully."
    echo "Service file content:"
    cat /etc/systemd/system/node_exporter.service   
}

# Function to daemon-reloadand enable the Node Exporter service
daemon_reload_and_enable() {
    # Reload systemd to recognize the new service
    systemctl daemon-reload
    # Enable the Node Exporter service to start on boot
    systemctl enable node_exporter
}

# Function to start Node Exporter service
start_node_exporter() {
    echo "Starting Node Exporter service..."
    systemctl start node_exporter
    echo "Node Exporter service started successfully."
    # Check the status of the Node Exporter service
    systemctl status node_exporter --no-pager | grep -E 'Active:|Loaded:|Main PID:|CGroup:'
}

# Main script execution
main() {
    check_root
    # Check if Node Exporter is already installed
    if check_node_exporter_installed; then
        echo "Node Exporter is already installed. Checking for systemd service..."
        if [[ -e /etc/systemd/system/node_exporter.service ]]; then
            echo "Node Exporter systemd service already exists. Skipping service creation."
            NODE_EXPORTER_USER=$(grep -oP '(?<=^User=).+' /etc/systemd/system/node_exporter.service)
            if [[ -z "$NODE_EXPORTER_USER" ]]; then
                echo "Failed to retrieve NODE_EXPORTER_USER from service file. Exiting."
                exit 1
            fi
        else
            echo "Node Exporter systemd service does not exist. Creating service..."
            INSTALLED_VERSION=$(node_exporter --version 2>/dev/null | grep -oP 'version \K[0-9]+\.[0-9]+\.[0-9]+') || {
                echo "Failed to detect installed node_exporter version"; exit 1;
            }
            NODE_EXPORTER_USER=$(create_system_user "$INSTALLED_VERSION")
            create_systemd_service "$NODE_EXPORTER_USER"
        fi
    else
        NODE_EXPORTER_USER=$(install_node_exporter)
        create_systemd_service "$NODE_EXPORTER_USER"
    fi
    daemon_reload_and_enable
    start_node_exporter
}

# Call the main function to execute the script
main
# End of script
