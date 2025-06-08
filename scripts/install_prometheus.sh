#!/bin/bash
# --------------------------------------------------------------------------------------
# This script used to install and set up prometheus server on a Linux system.
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

create_system_user() {
    local version="$1"
    local PROMETHEUS_USER="prometheus_$version"
    if id "$PROMETHEUS_USER" &>/dev/null; then
        echo "User '$PROMETHEUS_USER' already exists." >&2
    else
        echo "Creating a system user for Prometheus..." >&2
        useradd --no-create-home --shell /bin/false "$PROMETHEUS_USER"
        echo "System user '$PROMETHEUS_USER' created successfully." >&2
    fi
    echo "$PROMETHEUS_USER" # Return the user name as a string
}

install_prometheus() {
    echo "You want install specific version of Prometheus? (y/n)" >&2
    read -r INSTALL_SPECIFIC_VERSION 
    if [[ "${INSTALL_SPECIFIC_VERSION}" =~ ^[yY]$ ]]; then
        echo "Enter the version you want to install (e.g., v2.30.0) other wise it will install latest version:" >&2
        read -r PROMETHEUS_VERSION
    else
        # Fetch the latest version from GitHub
        PROMETHEUS_VERSION=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep '"tag_name":' | cut -d\" -f4)
        echo "Latest Prometheus version: ${PROMETHEUS_VERSION}" >&2
    fi

    # Extract the version number (strip leading 'v' if present)
    PROMETHEUS_VERSION_NUMBER=$(echo "${PROMETHEUS_VERSION}" | sed 's/^v//')
    
    # Construct the download URL based on the version and version number
    DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION_NUMBER}.linux-amd64.tar.gz"

    # Create a directory for Prometheus if it doesn't exist
    mkdir -p /opt/prometheus
    cd /opt/prometheus || { echo "Failed to change directory to /opt/prometheus"; exit 1; }
    echo "Current directory: $(pwd)" >&2

    # Check if wget is installed, if not, install it
    if ! command -v wget &> /dev/null; then
        echo "wget is not installed. Installing wget..." >&2
        apt-get update && apt-get install -y wget
    fi

    # Download the Prometheus tarball
    echo "Downloading Prometheus from: $DOWNLOAD_URL..." >&2
    wget --quiet --show-progress "$DOWNLOAD_URL" || { echo "Download failed."; exit 1; }

    # Extract the downloaded tarball
    echo "Extracting Prometheus..." >&2
    tar -xzf "prometheus-${PROMETHEUS_VERSION_NUMBER}.linux-amd64.tar.gz" || { echo "Extraction failed."; exit 1; }
    echo "Prometheus extracted successfully." >&2

    # Copy the binaries to /usr/local/bin
    echo "Copying Prometheus binaries to /usr/local/bin..." >&2
    cp "prometheus-${PROMETHEUS_VERSION_NUMBER}.linux-amd64/prometheus" /usr/local/bin/
    cp "prometheus-${PROMETHEUS_VERSION_NUMBER}.linux-amd64/promtool" /usr/local/bin/
    echo "Prometheus binaries copied successfully." >&2

    # Copy the console libraries, consoles, and config file to /etc/prometheus
    echo "Copying Prometheus console libraries and configuration files..." >&2
    mkdir -p /etc/prometheus
    cp -r "prometheus-${PROMETHEUS_VERSION_NUMBER}.linux-amd64/consoles" /etc/prometheus/
    cp -r "prometheus-${PROMETHEUS_VERSION_NUMBER}.linux-amd64/console_libraries" /etc/prometheus/
    cp "prometheus-${PROMETHEUS_VERSION_NUMBER}.linux-amd64/prometheus.yml" /etc/prometheus/
    echo "Prometheus console libraries and configuration files copied successfully." >&2

    # Create a system user for Prometheus
    PROMETHEUS_USER=$(create_system_user "$PROMETHEUS_VERSION_NUMBER")

    # Set ownership of the Prometheus directory and binaries
    echo "Setting ownership of the Prometheus directory to user: ${PROMETHEUS_USER}" >&2
    chown "$PROMETHEUS_USER:$PROMETHEUS_USER" /usr/local/bin/prometheus
    chown "$PROMETHEUS_USER:$PROMETHEUS_USER" /usr/local/bin/promtool
    chown  -R "$PROMETHEUS_USER:$PROMETHEUS_USER" /etc/prometheus
    echo "Ownership for Prometheus files set successfully." >&2

    sudo mkdir -p /var/lib/prometheus/data
    sudo chown -R "$PROMETHEUS_USER:$PROMETHEUS_USER" /var/lib/prometheus/data


    # Clean up the downloaded files
    # echo "Cleaning up downloaded files..." >&2
    # rm -rf /opt/prometheus/prometheus-${PROMETHEUS_VERSION_NUMBER}.linux-amd64.tar.gz

    echo "Prometheus installed successfully as user: $PROMETHEUS_USER" >&2
}


edit_prometheus_config() {
    local IP_ADDRESS_NODE_EXPORTER="$1"
    echo "Editing Prometheus configuration file..."
    # Add your configuration changes here
    # For example, you can add a scrape config for Node Exporter
    cat <<EOF >>/etc/prometheus/prometheus.yml

  - job_name: "node_exporter"
    static_configs:
      - targets: ["$IP_ADDRESS_NODE_EXPORTER:9100"]
        labels:   
          group: "node_exporter"
EOF
    echo "Prometheus configuration file edited successfully." >&2
}

create_systemd_service() {
    local PROMETHEUS_USER="$1"
    echo "Creating systemd service for Prometheus..."
    cat <<EOF >/etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Monitoring System
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=$PROMETHEUS_USER
Group=$PROMETHEUS_USER
ExecStart=/usr/local/bin/prometheus \
  --config.file /etc/prometheus/prometheus.yml \
  --storage.tsdb.path /var/lib/prometheus/data \
  --web.console.libraries /etc/prometheus/console_libraries \
  --web.console.templates /etc/prometheus/consoles

[Install]
WantedBy=multi-user.target
EOF
    echo "Prometheus systemd service created successfully." >&2
    echo "Service file content:"
    cat /etc/systemd/system/prometheus.service
}

daemon_reload_and_enable() {
    # Reload systemd to recognize the new service
    echo "Reloading systemd to recognize the new Prometheus service..." >&2
    systemctl daemon-reload
    # Enable the Prometheus service to start on boot
    echo "Enabling Prometheus service to start on boot..." >&2
    systemctl enable prometheus
}

start_prometheus() {
    echo "Starting Prometheus service..."
    systemctl start prometheus
    echo "Prometheus service started successfully." >&2
}

# Main script execution
main() {
    local IP_ADDRESS_NODE_EXPORTER="$1"

    check_root
    if command -v prometheus &>/dev/null; then
        echo "Prometheus is already installed."
        echo "Prometheus Version: $(prometheus --version)"
        if [[ -f /etc/prometheus/prometheus.yml ]]; then
            echo "Prometheus configuration file found at /etc/prometheus/prometheus.yml."
            if [[ -e /etc/systemd/system/prometheus.service ]]; then
                echo "Prometheus systemd service already exists."
                echo "prometheus user in the service file:"
                PROMETHEUS_USER=$(grep -oP '(?<=^User=).+' /etc/systemd/system/prometheus.service)
                if [[ -z "$PROMETHEUS_USER" ]]; then
                    echo "Failed to retrieve PROMETHEUS_USER from service file. Exiting."
                    exit 1
                fi
            else
                echo "Prometheus systemd service not found. Creating a new one..."
                PROMETHEUS_USER=$(grep -oP '(?<=^User=).+' /etc/systemd/system/prometheus.service)
                if [[ -z "$PROMETHEUS_USER" ]]; then
                    echo "Failed to retrieve PROMETHEUS_USER from service file. Exiting."
                    exit 1
                fi
                create_systemd_service "$PROMETHEUS_USER"
                daemon_reload_and_enable
                start_prometheus
            fi
        else
            echo "Prometheus configuration file not found. Proceeding to create a new one..."
            edit_prometheus_config "$IP_ADDRESS_NODE_EXPORTER"
            PROMETHEUS_USER=$(create_system_user "$(prometheus --version | grep -oP 'version \K[0-9]+\.[0-9]+\.[0-9]+')")
            create_systemd_service "$PROMETHEUS_USER"
            daemon_reload_and_enable
            start_prometheus
        fi

    else
        echo "Prometheus is not installed. Proceeding with installation..."
        # Install Prometheus
        install_prometheus
        # Edit the Prometheus configuration file
        edit_prometheus_config "$IP_ADDRESS_NODE_EXPORTER"
        # Create the systemd service for Prometheus
        PROMETHEUS_USER=$(echo "prometheus_$(prometheus --version | grep -oP 'version \K[0-9]+\.[0-9]+\.[0-9]+')")
        create_systemd_service "$PROMETHEUS_USER"
        # Reload systemd and enable the Prometheus service
        daemon_reload_and_enable
        # Start the Prometheus service
        start_prometheus
    fi

    # Check the status of the Prometheus service
    echo "Checking the status of the Prometheus service..."
    systemctl status prometheus --no-pager | grep -E 'Active:|Loaded:|Main PID:|CGroup:'
    echo "Prometheus setup completed successfully." >&2
}
# Call the main function to execute the script
main "$1"
# End of script
# --------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------
# This script used to install and set up Node Exporter on a Linux system. 
