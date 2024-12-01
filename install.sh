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

      # Hole den vollständigen Befehl des laufenden Node Exporters
      node_exporter_cmd=$(ps -o args= -C node_exporter)

      # Überprüfe, ob die Option für das Textfile-Directory gesetzt ist
      if [[ "$node_exporter_cmd" != *"--collector.textfile.directory=${TEXTFILE_DIR}"* ]]; then
          echo "ERROR: Node Exporter is missing the required --collector.textfile.directory option."
          echo "Expected option: --collector.textfile.directory=${TEXTFILE_DIR}"
          echo "Please ensure Node Exporter is started with this option."
          echo "To fix this, update the Node Exporter systemd unit file and reload the service:"
          echo "  systemctl daemon-reload && systemctl restart node_exporter"
          exit 1
      fi

      echo "Node Exporter is correctly configured for the textfile collector at ${TEXTFILE_DIR}."
  else
      echo "ERROR: Node Exporter is not running. Please start it and ensure correct configuration."
      exit 1
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
prepare_script
create_systemd_service
create_systemd_timer
