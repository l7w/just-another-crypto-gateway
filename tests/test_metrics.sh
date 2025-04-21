#!/bin/bash

# test_metrics.sh
# Tests Prometheus metrics for modem activity in dev environment

set -euo pipefail

LOG_FILE="test_metrics.log"
PROMETHEUS_URL="http://localhost:9090"
TEST_PASSED=0
TEST_FAILED=1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check dependencies
for cmd in curl; do
    command -v "$cmd" >/dev/null 2>&1 || { log "ERROR: $cmd is required"; exit $TEST_FAILED; }
done

# Test 1: Check sms_sent_total metric
log "Checking sms_sent_total metric..."
METRIC_RESPONSE=$(curl -s -m 5 "$PROMETHEUS_URL/api/v1/query?query=sms_sent_total")
if echo "$METRIC_RESPONSE" | grep -q '"metric":.*"__name__":"sms_sent_total"'; then
    log "PASS: sms_sent_total metric available"
else
    log "FAIL: sms_sent_total metric not found"
    exit $TEST_FAILED
fi

# Test 2: Check modem_active metric
log "Checking modem_active metric..."
METRIC_RESPONSE=$(curl -s -m 5 "$PROMETHEUS_URL/api/v1/query?query=modem_active")
if echo "$METRIC_RESPONSE" | grep -q '"metric":.*"__name__":"modem_active"'; then
    log "PASS: modem_active metric available"
else
    log "FAIL: modem_active metric not found"
    exit $TEST_FAILED
fi

log "All metrics tests passed"
exit $TEST_PASSED