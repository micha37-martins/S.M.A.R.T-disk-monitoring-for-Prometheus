#!/usr/bin/env bash

# This script is designed to collect SMART data from various types of
# disks (ATA, NVMe, SCSI) and format it for Prometheus monitoring.
# Be aware that SCSI type is not tested!
#
# By design this script works with a filter list of values. Opposed to parsing
# all elements from the JSON output of smartctl this seems more robust as
# different vendors might use inconsistent value naming.


# Global Variables
device_infos=""

# Ensure jq is installed. This function checks if the 'jq' command is available.
ensure_jq_installed() {
  if ! command -v jq &>/dev/null; then
    echo "jq could not be found. Please install it:"
    echo "https://jqlang.github.io/jq/download/"
    exit 1
  fi
}

# Parse and extract SMART information from the provided JSON.
# The function extracts various fields and prints them in a formatted manner.
# Arguments:
#   $1 - Disk name
#   $2 - Disk type
#   $3 - JSON string containing SMART information
parse_smartctl_info_json() {
  local disk="$1"
  local disk_type="$2"
  local json="$3"
  local labels="disk=\"${disk}\",type=\"${disk_type}\""

  declare -a keys_general=("model_family" "device_model" "serial_number" "firmware_version" "vendor" "product" "revision" "lun_id")
  declare -a keys_binary=("smart_support.is_available" "smart_support.is_enabled" "smart_status.passed")

  # Print the extracted information in Prometheus format
  # Note: use TABS for indentation
  device_infos=$(cat <<-EOF
device_info{${labels},
EOF
)

for key in "${keys_general[@]}"; do
  device_infos+="$key="\"$(jq -r --arg key "$key" '.[$key] // empty' <<< "$json")\"\,
done

# Remove the last comma
device_infos_jsonized=${device_infos%,}

  echo "$device_infos_jsonized""}" "1"
for key in "${keys_binary[@]}"; do
  value="$(jq -r ."$key // 0" <<< "$json")"
  echo "$(echo "$key" | tr '.' '_'){${labels}} ${value}"
done
}

# Parse and extract ATA SMART attributes from the provided JSON.
# The function extracts various fields and prints them in a formatted manner.
# Arguments:
#   $1 - Disk name
#   $2 - Disk type
#   $3 - JSON string containing SMART attributes
parse_smartctl_attributes_json() {
  local disk="$1"
  local disk_type="$2"
  local json="$3"
  local labels="disk=\"${disk}\",type=\"${disk_type}\""

  # return early if no input
  if [ "$json" == {} ]; then
    return 0
  fi

  # Extract and format SMART attributes using jq
  echo "$json" | jq -r '
    .ata_smart_attributes.table[] |
    select(.id and .name and (.value | type != "array") and (.worst | type != "array") and (.thresh | type != "array") and (.raw.value | type != "array")) |
    [
      .id,
      (.name | gsub("-"; "_")),
      .value,
      .worst,
      .thresh,
      .raw.value
    ] | @tsv
  ' | while IFS=$'\t' read -r id name value worst thresh raw; do
    echo "${name}_value{${labels},smart_id=\"${id}\"} ${value}"
    echo "${name}_worst{${labels},smart_id=\"${id}\"} ${worst}"
    echo "${name}_threshold{${labels},smart_id=\"${id}\"} ${thresh}"
    echo "${name}_raw_value{${labels},smart_id=\"${id}\"} ${raw}"
  done
}

# Parse and extract NVMe SMART attributes from the provided JSON.
# The function extracts various fields and prints them in a formatted manner.
# Arguments:
#   $1 - Disk name
#   $2 - Disk type
#   $3 - JSON string containing NVMe SMART attributes
parse_smartctl_nvme_attributes_json() {
  local disk="$1"
  local disk_type="$2"
  local json="$3"
  local labels="disk=\"${disk}\",type=\"${disk_type}\""

  # return early if no input
  if [ "$json" == {} ]; then
    return 0
  fi

  # Extract and format NVMe SMART attributes using jq
  echo "$json" | jq -r '
    .nvme_smart_health_information_log |
    to_entries[] |
    select(.key and (.value | type != "array")) |
    [
      (.key | gsub("-"; "_")),
      .value
    ] | @tsv
  ' | while IFS=$'\t' read -r key value; do
    echo "${key}{${labels}} ${value}"
  done
}

# Parse and extract SCSI SMART attributes from the provided JSON.
# The function extracts various fields and prints them in a formatted manner.
# Arguments:
#   $1 - Disk name
#   $2 - Disk type
#   $3 - JSON string containing SCSI SMART attributes
parse_smartctl_scsi_attributes_json() {
  local disk="$1"
  local disk_type="$2"
  local json="$3"
  local labels="disk=\"${disk}\",type=\"${disk_type}\""

  # Extract and format SCSI SMART attributes using jq
  echo "$json" | jq -r '
    [
      {key: "power_on_hours", value: .scsi_grown_defects_count},
      {key: "Current_Drive_Temperature", value: .temperature.current},
      {key: "Accumulated_start-stop_cycles", value: .accumulated_start_stop_cycles},
      {key: "Unsafe_Shutdowns", value: .unsafe_shutdowns},
      {key: "Power_Cycles", value: .power_cycles},
      {key: "Power_On_Hours", value: .power_on_hours},
      {key: "Host_Read_Commands", value: .host_read_commands},
      {key: "Host_Write_Commands", value: .host_write_commands},
      {key: "Controller_Busy_Time", value: .controller_busy_time},
      {key: "Error_Information_Log_Entries", value: .error_information_log_entries},
      {key: "Temperature", value: .temperature},
      {key: "Percentage_Used", value: .percentage_used},
      {key: "Available_Spare", value: .available_spare},
      {key: "Available_Spare_Threshold", value: .available_spare_threshold},
      {key: "Media_and_Data_Integrity_Errors", value: .media_and_data_integrity_errors}
    ] |
    map(select(.value != null and (.value | type != "array"))) |
    .[] |
    "\(.key){${labels}} \(.value)"
  ' | while IFS=$'\t' read -r key value; do
    echo "${key}{${labels}} ${value}"
  done
}

# AWK script to format the output in Prometheus format.
# This script processes the sorted output to add HELP and TYPE comments
# for each unique metric.
# v = $1 is used to store last metric and avoid duplicates in the next run
# This is used to track the last seen metric name to avoid printing duplicate help and type lines.
format_output_awk="$(
  cat <<'OUTPUTAWK'
BEGIN { v = "" }
(v != $1 && $0 != $1 ){
  print "# HELP smartmon_" $1 " SMART metric " $1;
  print "# TYPE smartmon_" $1 " gauge";
  v = $1
}
($0 != $1 ) {print "smartmon_" $0}
OUTPUTAWK
)"

# Format the output using awk.
# This function sorts the input and processes it using the awk script defined above.
format_output() {
  sort |
    awk -F'{' "${format_output_awk}"
}

# Get the smartctl version and output it in Prometheus format.
# Exits if version is too old.
output_smartctl_version() {
  # Get the smartctl version
  local smartctl_version
  smartctl_version=$(/usr/sbin/smartctl -V | head -n1 | awk '$1 == "smartctl" {print $2}')

  # Output the smartctl version in Prometheus format
  echo "smartctl_version{version=\"${smartctl_version}\"} 1" | format_output

  # Exit if smartctl version is less than 6
  if [[ "$(expr "${smartctl_version}" : '\([0-9]*\)\..*')" -lt 6 ]]; then
    echo "Error: smartctl version is less than 6." >&2
    exit 1
  fi
}

# Main function to orchestrate the script.
main() {
  ensure_jq_installed

  output_smartctl_version

  # Get the list of devices
  local device_list
  device_list=$(/usr/sbin/smartctl --scan-open | awk '/^\/dev/{print $1 "|" $3}')

  # Iterate over each device and gather SMART information
  for device in ${device_list}; do
    local disk
    local type
    disk=$(echo "${device}" | cut -f1 -d'|')
    type=$(echo "${device}" | cut -f2 -d'|')
    local active=1

    # Record the time of smartctl run
    echo "smartctl_run{disk=\"${disk}\",type=\"${type}\"}" "$(TZ=UTC date '+%s')"
    # Check if the device is active
    /usr/sbin/smartctl -n standby -d "${type}" "${disk}" > /dev/null || active=0
    echo "device_active{disk=\"${disk}\",type=\"${type}\"}" "${active}"

    # Skip inactive devices
    test ${active} -eq 0 && continue

    # Get and parse SMART information
    local info_json
    info_json=$(/usr/sbin/smartctl -i -H -j -d "${type}" "${disk}")
    parse_smartctl_info_json "${disk}" "${type}" "${info_json}"

    # Get and parse SMART attributes
    local attributes_json
    attributes_json=$(/usr/sbin/smartctl -A -j -d "${type}" "${disk}")
    case ${type} in
      sat|sat+megaraid*)
        parse_smartctl_attributes_json "${disk}" "${type}" "${attributes_json}"
        ;;
      scsi|megaraid*)
        parse_smartctl_scsi_attributes_json "${disk}" "${type}" "${attributes_json}"
        ;;
      nvme)
        parse_smartctl_nvme_attributes_json "${disk}" "${type}" "${attributes_json}"
        ;;
      *)
        echo "disk type is not supported: ${type}"
        exit 1
        ;;
    esac
  done | format_output
}

# Run the main function
main
