#!/usr/bin/env bats

setup() {
  load 'test_helper/bats-assert/load'
  load 'test_helper/bats-support/load'
  load '../src/smartmon-json.sh'
  # make executables in src/ visible to PATH
  PATH="$( pwd )/src/smartmon-json.sh:$PATH"
}

### Begin Helper Functions ###
# Helper for parse_smartctl_nvme_attributes_json
run_parse_smartctl_nvme_attributes_json() {
  local disk="$1"
  local disk_type="$2"
  local test_data="$3"
  # echo "$test_data" | parse_smartctl_nvme_attributes_json "$disk" "$disk_type"
  parse_smartctl_nvme_attributes_json "$disk" "$disk_type" "$test_data"
}

# Helper for parse_smartctl_attributes_json
run_parse_smartctl_attributes_json() {
  local disk="$1"
  local disk_type="$2"
  local test_data="$3"
  # echo "$test_data" | parse_smartctl_attributes_json "$disk" "$disk_type"
  parse_smartctl_attributes_json "$disk" "$disk_type" "$test_data"
}
### End Helper Functions ###

### Begin Tests ###
@test "parse_smartctl_nvme_attributes_json with temperature test_data" {
  local disk="nvme0"
  local disk_type="nvme"
  local test_data='{"nvme_smart_health_information_log": {"temperature": 28}}'

  run run_parse_smartctl_nvme_attributes_json "$disk" "$disk_type" "$test_data"
  assert_output 'temperature{disk="nvme0",type="nvme"} 28'
}

@test "parse_smartctl_nvme_attributes_json with empty test_data" {
  local disk="nvme0"
  local disk_type="nvme"
  local test_data='{}'

  run run_parse_smartctl_nvme_attributes_json "$disk" "$disk_type" "$test_data"
  assert_output ""
}

@test "parse_smartctl_nvme_attributes_json data_units_written" {
  local disk="nvme0"
  local disk_type="nvme"
  local test_data='{"nvme_smart_health_information_log": {"data_units_written": 3958438}}'

  run run_parse_smartctl_nvme_attributes_json "$disk" "$disk_type" "$test_data"
  assert_output - <<-EOF
data_units_written{disk="nvme0",type="nvme"} 3958438
EOF
}

@test "parse_smartctl_sata_attributes_json power_on_hours" {
  local disk="sda"
  local disk_type="sat"
  local test_json
  local test_json='{
  "json_format_version": [
    1,
    0
  ],
  "ata_smart_attributes": {
    "table": [
      {
        "id": 9,
        "name": "Power_On_Hours",
        "value": 100,
        "worst": 100,
        "thresh": 50,
        "when_failed": "",
        "flags": {
          "value": 50,
          "string": "-O--CK ",
          "prefailure": false,
          "updated_online": true,
          "performance": false,
          "error_rate": false,
          "event_count": true,
          "auto_keep": true
        },
        "raw": {
          "value": 30839,
          "string": "30839"
        }
      }
    ]
  }
}'

  run run_parse_smartctl_attributes_json "$disk" "$disk_type" "$test_json"
  assert_output - <<-EOF
		Power_On_Hours_value{disk="sda",type="sat",smart_id="9"} 100
		Power_On_Hours_worst{disk="sda",type="sat",smart_id="9"} 100
		Power_On_Hours_threshold{disk="sda",type="sat",smart_id="9"} 50
		Power_On_Hours_raw_value{disk="sda",type="sat",smart_id="9"} 30839
EOF
}

@test "parse_smartctl_sata_attributes_json invalid data" {
  local disk="sda"
  local disk_type="sat"
  local test_data='{}'

  run run_parse_smartctl_attributes_json "$disk" "$disk_type" "$test_data"
  assert_output ""
}

@test "parse_smartctl_sata_attributes_json replace hyphens" {
  local disk="sda"
  local disk_type="sat"
  local test_json
  local test_json='{
  "json_format_version": [
    1,
    0
  ],
  "ata_smart_attributes": {
    "table": [
      {
        "id": 9,
        "name": "Power-On-Hours",
        "value": 100,
        "worst": 100,
        "thresh": 50,
        "raw": {
          "value": 30839,
          "string": "30839"
        }
      }
    ]
  }
}'

  run run_parse_smartctl_attributes_json "$disk" "$disk_type" "$test_json"
  assert_output - <<-EOF
		Power_On_Hours_value{disk="sda",type="sat",smart_id="9"} 100
		Power_On_Hours_worst{disk="sda",type="sat",smart_id="9"} 100
		Power_On_Hours_threshold{disk="sda",type="sat",smart_id="9"} 50
		Power_On_Hours_raw_value{disk="sda",type="sat",smart_id="9"} 30839
EOF
}

@test "parse_smartctl_info_json correctly parses SMART info JSON" {
  local disk="sda"
  local disk_type="sat"
  local json='{
    "vendor": "NorthernDigital",
    "model_family": "JBOD-Star",
    "product": "ND-01",
    "revision": "10.01",
    "lun_id": "0",
    "device_model": "ND-01Model",
    "serial_number": "123456789",
    "firmware_version": "80.00A80",
    "smart_support": {
      "is_available": 1,
      "is_enabled": 1
    },
    "smart_status": {
      "passed": 1
    }
  }'

  local expected_output="device_info{disk=\"${disk}\",type=\"${disk_type}\",model_family=\"JBOD-Star\",device_model=\"ND-01Model\",serial_number=\"123456789\",firmware_version=\"80.00A80\",vendor=\"NorthernDigital\",product=\"ND-01\",revision=\"10.01\",lun_id=\"0\"} 1
smart_support_is_available{disk=\"${disk}\",type=\"${disk_type}\"} 1
smart_support_is_enabled{disk=\"${disk}\",type=\"${disk_type}\"} 1
smart_status_passed{disk=\"${disk}\",type=\"${disk_type}\"} 1"

  local output
  output=$(parse_smartctl_info_json "${disk}" "${disk_type}" "${json}")

  assert_equal "${output}" "${expected_output}"
}
