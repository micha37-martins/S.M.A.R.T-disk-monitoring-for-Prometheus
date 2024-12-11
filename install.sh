#!/usr/bin/env bash

# This script is designed to help you install smartmon. It was created and
# tested for Ubuntu but should be usable for other Linux distributions
# (with small adjustments).
# The path for textfile directory and the location of the smartmon.sh script
# can be configuration as environment variables:

SMARTMON_PATH="${SMARTMON_PATH:-/usr/local/bin}"
TEXTFILE_DIR="${TEXTFILE_DIR:-/var/lib/node_exporter/textfile_collector}"

# Check node_exporter status and configuration
check_node_exporter () {
  if systemctl is-active --quiet node_exporter; then
    echo "Node Exporter is running. Verifying textfile collector configuration..."

if ! ps aux | grep -q "[n]ode_exporter.*--collector.textfile.directory"; then
    echo "❌ The Prometheus Node Exporter is not configured with the required \
      --collector.textfile.directory option." >&2
    echo "ℹ️ Please configure the Node Exporter with \
      --collector.textfile.directory=${TEXTFILE_DIR}" >&2
    exit 1
fi

      echo "✅ Node Exporter is correctly configured for the textfile collector at ${TEXTFILE_DIR}."
  else
      echo "❌ ERROR: Node Exporter is not running. \
        Please start it and ensure correct configuration." >&2
      exit 1
  fi
}
#
# Check if the textfile collector directory exists
ensure_textfile_directory () {
  if [ ! -d "${TEXTFILE_DIR}" ]; then
    echo "ℹ️ The directory ${TEXTFILE_DIR} does not exist. Creating it..."
    mkdir -p "${TEXTFILE_DIR}" || {
      echo "❌ ERROR: Failed to create directory ${TEXTFILE_DIR}. Check permissions." >&2
      exit 1
    }
    echo "✅ Directory ${TEXTFILE_DIR} created successfully."
  else
    echo "✅ Directory ${TEXTFILE_DIR} already exists."
  fi
}

prepare_script () {
  # Download the smartmon.sh script from the repository or a release asset
  wget -O "${SMARTMON_PATH}/smartmon.sh" https://raw.githubusercontent.com/micha37-martins/S.M.A.R.T-disk-monitoring-for-Prometheus/master/src/smartmon.sh

  # Set the appropriate permissions on the smartmon.sh script
  chmod +x "${SMARTMON_PATH}/smartmon.sh"
}

# Create the systemd service unit file
create_systemd_service () {
cat <<EOF > /etc/systemd/system/smartmon.service
[Unit]
Description=SMART Disk Exporter for Prometheus
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/env bash ${SMARTMON_PATH}/smartmon.sh
StandardOutput=truncate:/var/lib/node_exporter/textfile_collector/smart_metrics.prom
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
}

# Create the systemd timer unit file
create_systemd_timer () {
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
}

# Execute the individual steps
check_node_exporter
ensure_textfile_directory
prepare_script
create_systemd_service
create_systemd_timer
