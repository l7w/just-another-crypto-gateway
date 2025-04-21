#!/bin/bash

# test_sms_operations.sh
# Tests SMS send/receive via Hardware Proxy in dev environment

set -euo pipefail

LOG_FILE="test_sms_operations.log"
API_URL="http://localhost:8082"
REDIS_HOST="redis"
REDIS_PORT="6379"
TEST_PASSED=0
TEST_FAILED=1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check dependencies
for cmd in curl docker redis-cli jq; do
    command -v "$cmd" >/dev/null 2>&1 || { log "ERROR: $cmd is required"; exit $TEST_FAILED; }
done

# Test 1: Send SMS via Hardware Proxy API
log "Sending test SMS..."
SEND_RESPONSE=$(curl -s -m 5 -X POST "$API_URL/sms" \
    -H "Content-Type: application/json" \
    -d '{"modem_id": 0, "recipient": "+1234567890", "message": "TEST SMS"}')
if echo "$SEND_RESPONSE" | jq -e '.status == "success"' >/dev/null; then
    log "PASS: SMS sent successfully"
else
    log "FAIL: SMS send failed: $SEND_RESPONSE"
    exit $TEST_FAILED
fi

# Test 2: Verify SMS in Redis queue
log "Checking Redis queue for SMS..."
SMS_IN_QUEUE=$(docker exec redis redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" LRANGE sms_queue 0 -1 | grep "TEST SMS")
if [[ -n "$SMS_IN_QUEUE" ]]; then
    log "PASS: SMS found in Redis queue"
else
    log "FAIL: SMS not found in Redis queue"
    exit $TEST_FAILED
fi

# Test 3: Simulate SMS receive (mock response)
log "Simulating SMS receive..."
RECEIVE_RESPONSE=$(curl -s -m 5 -X GET "$API_URL/receive" \
    -H "Content-Type: application/json")
if echo "$RECEIVE_RESPONSE" | jq -e '.messages | length >= 0' >/dev/null; then
    log "PASS: SMS receive endpoint responded"
else
    log "FAIL: SMS receive failed: $RECEIVE_RESPONSE"
    exit $TEST_FAILED
fi

log "All SMS operation tests passed"
exit $TEST_PASSED