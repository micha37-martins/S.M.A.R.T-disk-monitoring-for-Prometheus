#!/usr/bin/env bats

setup() {
  load 'test_helper/bats-assert/load'
  load 'test_helper/bats-support/load'
  load '../src/smartmon-json.sh'
  # make executables in src/ visible to PATH
  PATH="$( pwd )/src/smartmon-json.sh:$PATH"
}

### Begin Helper Functions
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
### End Helper Functions

#test_info_json=$( jq -n \
#'
#{
#  "json_format_version": [
#    1,
#    0
#  ],
#  "smartctl": {
#    "version": [
#      7,
#      4
#    ],
#    "pre_release": false,
#    "svn_revision": "5530",
#    "platform_info": "x86_64-linux-1.2.3-4-MANJARO",
#    "build_info": "(local build)",
#    "argv": [
#      "smartctl",
#      "-i",
#      "-j",
#      "-H",
#      "/dev/nvme0"
#    ],
#    "exit_status": 0
#  },
#  "local_time": {
#    "time_t": 1234567890,
#    "asctime": "Thu Jul 1 22:22:22 2024 CEST"
#  },
#  "device": {
#    "name": "/dev/nvme0",
#    "info_name": "/dev/nvme0",
#    "type": "nvme",
#    "protocol": "NVMe"
#  },
#  "model_name": "WD_BLACK SN770 1TB",
#  "serial_number": "12345U123456",
#  "firmware_version": "112200WD",
#  "nvme_pci_vendor": {
#    "id": 5559,
#    "subsystem_id": 5559
#  },
#  "nvme_ieee_oui_identifier": 6980,
#  "nvme_total_capacity": 1000204886016,
#  "nvme_unallocated_capacity": 0,
#  "nvme_controller_id": 0,
#  "nvme_version": {
#    "string": "1.4",
#    "value": 66560
#  },
#  "nvme_number_of_namespaces": 1,
#  "nvme_namespaces": [
#    {
#      "id": 1,
#      "size": {
#        "blocks": 1953525168,
#        "bytes": 1000204886016
#      },
#      "capacity": {
#        "blocks": 1953525168,
#        "bytes": 1000204886016
#      },
#      "utilization": {
#        "blocks": 1953525168,
#        "bytes": 1000204886016
#      },
#      "formatted_lba_size": 512,
#      "eui64": {
#        "oui": 6980,
#        "ext_id": 319051012292
#      }
#    }
#  ],
#  "user_capacity": {
#    "blocks": 1953525168,
#    "bytes": 1000204886016
#  },
#  "logical_block_size": 512,
#  "smart_support": {
#    "available": true,
#    "enabled": true
#  },
#  "smart_status": {
#    "passed": true,
#    "nvme": {
#      "value": 0
#    }
#  }
#}
#' )
#
#
#echo "$test_info_json"
#
#
#test_values_json=$( jq -n \
#'
#{
#  "json_format_version": [
#    1,
#    0
#  ],
#  "smartctl": {
#    "version": [
#      7,
#      4
#    ],
#    "pre_release": false,
#    "svn_revision": "5530",
#    "platform_info": "x86_64-linux-1.2.3-4-MANJARO",
#    "build_info": "(local build)",
#    "argv": [
#      "smartctl",
#      "-A",
#      "-j",
#      "-H",
#      "/dev/nvme0"
#    ],
#    "exit_status": 0
#  },
#  "local_time": {
#    "time_t": 1234567890,
#    "asctime": "Thu Jul 1 22:22:22 2024 CEST"
#  },
#  "device": {
#    "name": "/dev/nvme0",
#    "info_name": "/dev/nvme0",
#    "type": "nvme",
#    "protocol": "NVMe"
#  },
#  "smart_status": {
#    "passed": true,
#    "nvme": {
#      "value": 0
#    }
#  },
#  "nvme_smart_health_information_log": {
#    "critical_warning": 0,
#    "temperature": 34,
#    "available_spare": 100,
#    "available_spare_threshold": 10,
#    "percentage_used": 0,
#    "data_units_read": 2454092,
#    "data_units_written": 4090197,
#    "host_reads": 24207664,
#    "host_writes": 53302692,
#    "controller_busy_time": 83,
#    "power_cycles": 1109,
#    "power_on_hours": 74,
#    "unsafe_shutdowns": 53,
#    "media_errors": 0,
#    "num_err_log_entries": 0,
#    "warning_temp_time": 0,
#    "critical_comp_time": 0,
#    "temperature_sensors": [
#      42,
#      34
#    ]
#  },
#  "temperature": {
#    "current": 34
#  },
#  "power_cycle_count": 1109,
#  "power_on_time": {
#    "hours": 74
#  }
#}
#' )
#echo "$test_values_json"

# Example test_data for: "parse_smartctl_nvme_attributes_json"
#
#sudo smartctl -A -d nvme /dev/nvme0
#smartctl 7.4 2023-08-01 r5530 [x86_64-linux-6.6.32-1-MANJARO] (local build)
#Copyright (C) 2002-23, Bruce Allen, Christian Franke, www.smartmontools.org
#
#=== START OF SMART DATA SECTION ===
#SMART/Health Information (NVMe Log 0x02)
#Critical Warning:                   0x00
#Temperature:                        28 Celsius
#Available Spare:                    100%
#Available Spare Threshold:          10%
#Percentage Used:                    0%
#Data Units Read:                    2,389,400 [1.22 TB]
#Data Units Written:                 3,958,438 [2.02 TB]
#Host Read Commands:                 23,444,268
#Host Write Commands:                51,391,963
#Controller Busy Time:               79
#Power Cycles:                       1,012
#Power On Hours:                     70
#Unsafe Shutdowns:                   52
#Media and Data Integrity Errors:    0
#Error Information Log Entries:      0
#Warning  Comp. Temperature Time:    0
#Critical Comp. Temperature Time:    0
#Temperature Sensor 1:               36 Celsius
#Temperature Sensor 2:               28 Celsius

###############################################################################
# sudo smartctl -A /dev/sda
#smartctl 7.1 2019-12-30 r5022 [x86_64-linux-5.4.0-182-generic] (local build)
#Copyright (C) 2002-19, Bruce Allen, Christian Franke, www.smartmontools.org
#
#=== START OF READ SMART DATA SECTION ===
#SMART Attributes Data Structure revision number: 1
#Vendor Specific SMART Attributes with Thresholds:
#ID# ATTRIBUTE_NAME          FLAG     VALUE WORST THRESH TYPE      UPDATED  WHEN_FAILED RAW_VALUE
#  1 Raw_Read_Error_Rate     0x002f   100   100   050    Pre-fail  Always       -       0
#  5 Reallocate_NAND_Blk_Cnt 0x0032   100   100   010    Old_age   Always       -       0
#  9 Power_On_Hours          0x0032   100   100   050    Old_age   Always       -       30104
# 12 Power_Cycle_Count       0x0032   100   100   050    Old_age   Always       -       57
#171 Program_Fail_Count      0x0032   100   100   050    Old_age   Always       -       0
#172 Erase_Fail_Count        0x0032   100   100   050    Old_age   Always       -       0
#173 Ave_Block-Erase_Count   0x0032   100   100   050    Old_age   Always       -       183
#174 Unexpect_Power_Loss_Ct  0x0032   100   100   050    Old_age   Always       -       31
#180 Unused_Reserve_NAND_Blk 0x0032   100   100   050    Old_age   Always       -       100
#183 SATA_Interfac_Downshift 0x0032   100   100   050    Old_age   Always       -       120
#184 Error_Correction_Count  0x0032   100   100   050    Old_age   Always       -       8
#187 Reported_Uncorrect      0x0032   100   100   050    Old_age   Always       -       0
#194 Temperature_Celsius     0x0022   069   049   050    Old_age   Always   In_the_past 31 (Min/Max 25/51)
#196 Reallocated_Event_Count 0x0032   100   100   050    Old_age   Always       -       0
#197 Current_Pending_Sector  0x0032   100   100   050    Old_age   Always       -       0
#198 Offline_Uncorrectable   0x0030   100   100   050    Old_age   Offline      -       0
#199 UDMA_CRC_Error_Count    0x0032   100   100   050    Old_age   Always       -       0
#202 Percent_Lifetime_Remain 0x0030   088   088   001    Old_age   Offline      -       88
#206 Write_Error_Rate        0x002e   100   100   050    Old_age   Always       -       0
#210 Success_RAIN_Recov_Cnt  0x0032   100   100   050    Old_age   Always       -       0
#246 Total_LBAs_Written      0x0032   100   100   050    Old_age   Always       -       8866549306
#247 Host_Program_Page_Count 0x0032   100   100   050    Old_age   Always       -       277079665
#248 FTL_Program_Page_Count  0x0032   100   100   050    Old_age   Always       -       318468096


### Begin Tests

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
  local test_data
  test_data=$(jq -n \
'
{
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
}
'
)

  run run_parse_smartctl_attributes_json "$disk" "$disk_type" "$test_data"
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
  local test_data
  test_data=$(jq -n \
'
{
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
}
'
)

  run run_parse_smartctl_attributes_json "$disk" "$disk_type" "$test_data"
  assert_output - <<-EOF
		Power_On_Hours_value{disk="sda",type="sat",smart_id="9"} 100
		Power_On_Hours_worst{disk="sda",type="sat",smart_id="9"} 100
		Power_On_Hours_threshold{disk="sda",type="sat",smart_id="9"} 50
		Power_On_Hours_raw_value{disk="sda",type="sat",smart_id="9"} 30839
EOF
}
