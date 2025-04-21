#!/bin/bash

# test_device_plugin.sh
# Tests Nomad Device Plugin modem fingerprinting in dev environment

set -euo pipefail

LOG_FILE="test_device_plugin.log"
NOMAD_ADDR="http://localhost:4646"
TEST_PASSED=0
TEST_FAILED=1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check dependencies
for cmd in curl nomad jq; do
    command -v "$cmd" >/dev/null 2>&1 || { log "ERROR: $cmd is required"; exit $TEST_FAILED; }
done

# Test 1: Check modem device registration
log "Checking modem device registration..."
DEVICE_INFO=$(curl -s -m 5 "$NOMAD_ADDR/v1/node/list" | jq -r '.[] | select(.NodeClass == "modem-enabled") | .Drivers[].Attributes["driver.docker.devices"]')
if echo "$DEVICE_INFO" | grep -q "/dev/ttyUSB0"; then
    log "PASS: Modem device /dev/ttyUSB0 registered"
else
    log "FAIL: Modem device /dev/ttyUSB0 not registered"
    exit $TEST_FAILED
fi

# Test 2: Verify device_plugin logs for fingerprinting
log "Checking device_plugin logs..."
PLUGIN_LOGS=$(docker logs nomad-plugin 2>&1 | grep "Fingerprinting modem")
if [[ -n "$PLUGIN_LOGS" ]]; then
    log "PASS: Device plugin fingerprinted modem"
else
    log "FAIL: Device plugin did not fingerprint modem"
    exit $TEST_FAILED
fi

log "All device plugin tests passed"
exit $TEST_PASSED