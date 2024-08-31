#!/usr/bin/env bash

SRC_DIR="./src"
TEST_DIR="./test"
COVERAGE_DIR="./coverage"

# Function to create the coverage directory
create_coverage_dir() {
  mkdir -p "$COVERAGE_DIR"
}

# Function to run kcov with bats tests
run_kcov() {
  local test_file; test_file="$1"
  local src_file; src_file="$2"
  local coverage_file; coverage_file="$COVERAGE_DIR/$(basename "$test_file" .bats).coverage"

  if ! kcov --bash-dont-parse-binary-dir --include-path="$SRC_DIR" "$coverage_file" bats -t "$test_file"; then
    printf "Error: kcov failed for %s\n" "$test_file" >&2
    return 1
  fi
}

# Main function
main() {
  create_coverage_dir

  local test_file; test_file="$TEST_DIR/test_smartmon.bats"
  local src_file; src_file="$SRC_DIR/smartmon.sh"

  if [[ ! -f "$test_file" ]]; then
    printf "Error: Test file %s does not exist\n" "$test_file" >&2
    return 1
  fi

  if [[ ! -f "$src_file" ]]; then
    printf "Error: Source file %s does not exist\n" "$src_file" >&2
    return 1
  fi

  if ! run_kcov "$test_file" "$src_file"; then
    printf "Error: Failed to run kcov for %s\n" "$test_file" >&2
    return 1
  fi

  printf "Coverage report generated in %s\n" "$COVERAGE_DIR"
}

main "$@"
