#!/usr/bin/env bash

# TODO: remove json postfix
# TODO: warning breaking changes
# TODO: test tolowercase
# - Renaming
# - JSON
# - Drop SCSI

# This script is designed to collect SMART data from various types of
# disks (ATA, NVMe, SCSI) and format it for Prometheus monitoring.
# Be aware that SCSI type is not tested!
#
# By design this script works with a filter list of values. Opposed to parsing
# all elements from the JSON output of smartctl this seems more robust as
# different vendors might use inconsistent value naming.


# Check if the 'jq' command is available.
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
  local device_infos=""
  local disk="$1"
  local disk_type="$2"
  local json="$3"
  local labels="disk=\"${disk}\",type=\"${disk_type}\""

  declare -a keys_general=("model_family" "model_name" "device_model" "serial_number" "firmware_version" "vendor" "product" "revision" "lun_id")
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
    # Convert boolean to numeric
    if [ "$value" == "true" ]; then
      value=1
    elif [ "$value" == "false" ]; then
      value=0
    fi
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
    select(
      .id and
      .name and
      (.value | type != "array") and
      (.worst | type != "array") and
      (.thresh | type != "array") and
      (.raw.value | type != "array")
    ) |
    [
      .id,
      (.name | gsub("-"; "_")),
      .value,
      .worst,
      .thresh,
      (.raw.string | capture("(?<num>^[0-9]+)") | .num)
    ] | @tsv
  ' | while IFS=$'\t' read -r id name value worst thresh raw; do

    local metric_name

    metric_name="${name}_value"
    printf "%s{%s,smart_id=\"%s\"} %s\n" \
      "$(echo "$metric_name" | awk '{print tolower($0)}')" \
      "$labels" \
      "$id" \
      "$value"

    metric_name="${name}_worst"
    printf "%s{%s,smart_id=\"%s\"} %s\n" \
      "$(echo "$metric_name" | awk '{print tolower($0)}')" \
      "$labels" \
      "$id" \
      "$worst"

    metric_name="${name}_threshold"
    printf "%s{%s,smart_id=\"%s\"} %s\n" \
      "$(echo "$metric_name" | awk '{print tolower($0)}')" \
      "$labels" \
      "$id" \
      "$thresh"

    metric_name="${name}_raw_value"
    printf "%s{%s,smart_id=\"%s\"} %s\n" \
      "$(echo "$metric_name" | awk '{print tolower($0)}')" \
      "$labels" \
      "$id" \
      "$raw"
  done

  # Extract and format temperature
  local temperature
  temperature=$(echo "$json" | jq -r '.temperature.current // empty')

  if [[ -n "$temperature" ]]; then
    printf "temperature_current{%s} %s\n" "$labels" "$temperature"
  fi

}

# Parse and extract NVMe SMART attributes from the provided JSON.
# The function extracts various fields and prints them in a formatted manner.
# Arguments:
#   $1 - Disk name
#   $2 - Disk type
#   $3 - JSON string containing NVMe SMART attributes
#parse_smartctl_nvme_attributes_json() {
#  local disk="$1"
#  local disk_type="$2"
#  local json="$3"
#  local labels="disk=\"${disk}\",type=\"${disk_type}\""
#
#  # return early if no input
#  if [ "$json" == {} ]; then
#    return 0
#  fi
#
#  # Extract and format NVMe SMART attributes using jq
#  echo "$json" | jq -r '
#    .nvme_smart_health_information_log |
#    to_entries[] |
#    select(.key and (.value | type != "array")) |
#    [
#      (.key | gsub("-"; "_")),
#      .value
#    ] | @tsv
#  ' | while IFS=$'\t' read -r key value; do
#    local metric_name="${key}"
#    echo "$(echo "${metric_name}" | awk '{print tolower($0)}'){${labels}} ${value}"
#  done
#}
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
    local metric_name="${key}"
    # Data Units Written: Represents the number of 512-byte data units written.
    # It is reported as thousends 1 = 1000 units of 512 bytes)
    # Block-sizes different from 512 will be converted to 512
    if [ "${metric_name}" == "data_units_written" ]; then
      local written_bytes=$((value * 512 *1000))
      echo "written_bytes{${labels}} ${written_bytes}"
    fi
    echo "$(echo "${metric_name}" | awk '{print tolower($0)}'){${labels}} ${value}"
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

# Check if a storage device is active.
# Arguments:
#   $1 - Disk name
#   $2 - Disk type
# Returns 0 if the device is active, and a non-zero value otherwise.
is_device_active() {
  local disk=$1
  local type=$2
  /usr/sbin/smartctl -n standby -d "${type}" "${disk}" > /dev/null
}

# This function processes a single storage device.
# Arguments:
#   $1 - Disk name
#   $2 - Disk type
# Performed operations:
# - Record the time of the smartctl run
# - Check if the device is active
# - Skip inactive devices
# - Get and parses SMART information
# - Get and parses SMART attributes
# Returns nothing
process_device() {
  local disk=$1
  local type=$2
  local active=1

  # Record the time of smartctl run
  local metric_name="smartctl_run"
  echo "$(echo "${metric_name}" | awk '{print tolower($0)}'){disk=\"${disk}\",type=\"${type}\"}" "$(TZ=UTC date '+%s')"

  # Check if the device is active
  if is_device_active "${disk}" "${type}"; then
    active=1
  else
    active=0
  fi
  metric_name="device_active"
  # make metric names lowercase
  echo "$(echo "${metric_name}" | awk '{print tolower($0)}'){disk=\"${disk}\",type=\"${type}\"}" "${active}"

  # Skip inactive devices
  test ${active} -eq 0 && return

  # Get and parse SMART information
  local info_json
  info_json=$(/usr/sbin/smartctl -i -j -d "${type}" "${disk}")
  parse_smartctl_info_json "${disk}" "${type}" "${info_json}"

  # Get and parse SMART attributes
  local attributes_json
  attributes_json=$(/usr/sbin/smartctl -A -j -d "${type}" "${disk}")
  case ${type} in
    sat|sat+megaraid*)
    # TODO: continue integrating block size if available from json info and multiply with lbs_written if avail
      parse_smartctl_attributes_json "${disk}" "${type}" "${attributes_json}"
      ;;
    nvme)
      parse_smartctl_nvme_attributes_json "${disk}" "${type}" "${attributes_json}"
      ;;
    *)
      echo "disk type is not supported: ${type}"
      exit 1
      ;;
  esac
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
    local disk; disk=$(echo "${device}" | cut -f1 -d'|')
    local type; type=$(echo "${device}" | cut -f2 -d'|')

    process_device "${disk}" "${type}"
  done | format_output
}

# Run the main function
main
