#!/bin/bash

# run_all_tests.sh
# Runs all modem tests in parallel and generates a report

set -euo pipefail

REPORT_FILE="test_report.txt"
LOG_DIR="test_logs"
TESTS=("test_modem_connectivity.sh" "test_sms_operations.sh" "test_device_plugin.sh" "test_metrics.sh")
TEST_PASSED=0
TEST_FAILED=1

# Create log directory
mkdir -p "$LOG_DIR"

echo "Modem Test Report - $(date '+%Y-%m-%d %H:%M:%S')" > "$REPORT_FILE"
echo "----------------------------------------" >> "$REPORT_FILE"

# Run tests in parallel
PIDS=()
for test in "${TESTS[@]}"; do
    bash "$test" &> "$LOG_DIR/${test%.sh}.log" &
    PIDS+=($!)
done

# Wait for tests to complete and collect results
FAILED=0
for i in "${!PIDS[@]}"; do
    if wait "${PIDS[$i]}"; then
        echo "${TESTS[$i]}: PASS" >> "$REPORT_FILE"
    else
        echo "${TESTS[$i]}: FAIL (see $LOG_DIR/${TESTS[$i]%.sh}.log)" >> "$REPORT_FILE"
        FAILED=1
    fi
done

# Summary
if [[ $FAILED -eq 0 ]]; then
    echo "All tests passed" >> "$REPORT_FILE"
    cat "$REPORT_FILE"
    exit $TEST_PASSED
else
    echo "Some tests failed" >> "$REPORT_FILE"
    cat "$REPORT_FILE"
    exit $TEST_FAILED
fi