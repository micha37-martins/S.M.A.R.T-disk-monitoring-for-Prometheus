#!/usr/bin/env bash

# Set the installation path with a default value
SMARTMON_PATH="${SMARTMON_PATH:-/usr/local/bin}"

# Download the smartmon.sh script from the repository or a release asset
wget -O "${SMARTMON_PATH}/smartmon.sh" https://raw.githubusercontent.com/micha37-martins/smart-disk-exporter/main/smartmon.sh

# Set the appropriate permissions on the smartmon.sh script
chmod +x "${SMARTMON_PATH}/smartmon.sh"

# Create the systemd service unit file
cat <<EOF > /etc/systemd/system/smartmon.service
[Unit]
Description=SMART Disk Exporter for Prometheus
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/env bash ${SMARTMON_PATH}/smartmon.sh > /var/lib/node_exporter/textfile_collector/smart_metrics.prom
WorkingDirectory=/var/lib/node_exporter/textfile_collector/

[Install]
WantedBy=multi-user.target
EOF

# Reload the systemd daemon to load the new service unit file
systemctl daemon-reload

# Enable the service to start automatically at boot
systemctl enable smartmon.service

# Start the service immediately
systemctl start smartmon.service

# Create the systemd timer unit file
cat <<EOF > /etc/systemd/system/smartmon.timer
[Unit]
Description=Run SMART Disk Exporter for Prometheus every 10 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=10min

[Install]
WantedBy=multi-user.target
EOF

# Reload the systemd daemon to load the new timer unit file
systemctl daemon-reload

# Enable the timer to start automatically at boot
systemctl enable smartmon.timer

# Start the timer immediately
systemctl start smartmon.timer
