#!/usr/bin/env bash

# Set the installation path with a default value
SMARTMON_PATH="${SMARTMON_PATH:-/usr/local/bin}"

# Stop the timer
systemctl stop smartmon.timer

# Disable the timer
systemctl disable smartmon.timer

# Remove the timer unit file
rm /etc/systemd/system/smartmon.timer

# Stop the service
systemctl stop smartmon.service

# Disable the service
systemctl disable smartmon.service

# Remove the service unit file
rm /etc/systemd/system/smartmon.service

# Reload the systemd daemon
systemctl daemon-reload

# Remove the smartmon.sh script
rm "${SMARTMON_PATH}/smartmon.sh"

# Print a message indicating that the uninstallation is complete
echo "Uninstallation complete."
