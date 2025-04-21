#!/bin/bash

# test_modem_connectivity.sh
# Tests modem device availability and Nomad job status in dev environment

set -euo pipefail

LOG_FILE="test_modem_connectivity.log"
NOMAD_ADDR="http://localhost:4646"
DEVICE="/dev/ttyUSB0"
TEST_PASSED=0
TEST_FAILED=1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check dependencies
for cmd in curl docker nomad jq; do
    command -v "$cmd" >/dev/null 2>&1 || { log "ERROR: $cmd is required"; exit $TEST_FAILED; }
done

# Test 1: Check modem device in hardware-proxy container
log "Checking modem device ($DEVICE)..."
if docker exec hardware-proxy ls "$DEVICE" >/dev/null 2>&1; then
    log "PASS: Modem device $DEVICE is available"
else
    log "FAIL: Modem device $DEVICE not found"
    exit $TEST_FAILED
fi

# Test 2: Check sms_proxy Nomad job status
log "Checking sms_proxy Nomad job status..."
SMS_PROXY_STATUS=$(nomad job status -address="$NOMAD_ADDR" sms_proxy -short | grep Status | awk '{print $2}')
if [[ "$SMS_PROXY_STATUS" == "running" ]]; then
    log "PASS: sms_proxy job is running"
else
    log "FAIL: sms_proxy job status is $SMS_PROXY_STATUS"
    exit $TEST_FAILED
fi

# Test 3: Check device_plugin Nomad job status
log "Checking device_plugin Nomad job status..."
DEVICE_PLUGIN_STATUS=$(nomad job status -address="$NOMAD_ADDR" device_plugin -short | grep Status | awk '{print $2}')
if [[ "$DEVICE_PLUGIN_STATUS" == "running" ]]; then
    log "PASS: device_plugin job is running"
else
    log "FAIL: device_plugin job status is $DEVICE_PLUGIN_STATUS"
    exit $TEST_FAILED
fi

log "All modem connectivity tests passed"
exit $TEST_PASSED