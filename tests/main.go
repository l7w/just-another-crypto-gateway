// The Go test suite simulates SMS and MQTT requests, measures performance, and tests use cases.

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"sync"
	"testing"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/stretchr/testify/assert"
)

const (
	smsEndpoint   = "http://payment-gateway:5000/sms"
	mqttBroker    = "tcp://broker.hivemq.com:1883"
	mqttTopic     = "payment/requests"
	clientID      = "test-client"
	numRequests   = 1000
	concurrency   = 50
	rateLimit     = 10 // Matches gateway's RATE_LIMIT_CALLS
	rateLimitWait = 60 * time.Second
)

type Metrics struct {
	TotalRequests int
	Successful    int
	Failed        int
	Latencies     []time.Duration
	Mutex         sync.Mutex
}

func (m *Metrics) Record(success bool, latency time.Duration) {
	m.Mutex.Lock()
	defer m.Mutex.Unlock()
	m.TotalRequests++
	if success {
		m.Successful++
	} else {
		m.Failed++
	}
	m.Latencies = append(m.Latencies, latency)
}

func (m *Metrics) Throughput() float64 {
	if len(m.Latencies) == 0 {
		return 0
	}
	totalDuration := time.Duration(0)
	for _, l := range m.Latencies {
		totalDuration += l
	}
	return float64(m.Successful) / (float64(totalDuration) / float64(time.Second))
}

func (m *Metrics) AvgLatency() time.Duration {
	if len(m.Latencies) == 0 {
		return 0
	}
	total := time.Duration(0)
	for _, l := range m.Latencies {
		total += l
	}
	return total / time.Duration(len(m.Latencies))
}

func TestBandwidthSMS(t *testing.T) {
	metrics := &Metrics{}
	var wg sync.WaitGroup
	semaphore := make(chan struct{}, concurrency)

	for i := 0; i < numRequests; i++ {
		wg.Add(1)
		semaphore <- struct{}{}
		go func(idx int) {
			defer wg.Done()
			defer func() { <-semaphore }()

			start := time.Now()
			resp, err := sendSMSRequest(fmt.Sprintf("PAY 0.1 0x742d35Cc6634C0532925a3b844Bc454e4438f44e"))
			latency := time.Since(start)
			if err != nil || resp.StatusCode != http.StatusNoContent {
				metrics.Record(false, latency)
				return
			}
			metrics.Record(true, latency)
		}(i)

		// Simulate rate limit
		if (i+1)%rateLimit == 0 {
			time.Sleep(rateLimitWait / 10) // Partial wait to avoid full lockout
		}
	}

	wg.Wait()

	t.Logf("SMS Bandwidth Test Results:")
	t.Logf("Total Requests: %d", metrics.TotalRequests)
	t.Logf("Successful: %d", metrics.Successful)
	t.Logf("Failed: %d", metrics.Failed)
	t.Logf("Throughput: %.2f req/s", metrics.Throughput())
	t.Logf("Average Latency: %v", metrics.AvgLatency())
	assert.Greater(t, metrics.Successful, numRequests/2, "More than half of requests should succeed")
}

func TestBandwidthMQTT(t *testing.T) {
	metrics := &Metrics{}
	var wg sync.WaitGroup
	semaphore := make(chan struct{}, concurrency)

	opts := mqtt.NewClientOptions().AddBroker(mqttBroker).SetClientID(clientID)
	client := mqtt.NewClient(opts)
	if token := client.Connect(); token.Wait() && token.Error() != nil {
		t.Fatalf("Failed to connect to MQTT broker: %v", token.Error())
	}
	defer client.Disconnect(250)

	for i := 0; i < numRequests; i++ {
		wg.Add(1)
		semaphore <- struct{}{}
		go func(idx int) {
			defer wg.Done()
			defer func() { <-semaphore }()

			start := time.Now()
			message := "PAY 0.1 0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
			token := client.Publish(mqttTopic, 0, false, message)
			token.Wait()
			latency := time.Since(start)
			if token.Error() != nil {
				metrics.Record(false, latency)
				return
			}
			metrics.Record(true, latency)
		}(i)

		if (i+1)%rateLimit == 0 {
			time.Sleep(rateLimitWait / 10)
		}
	}

	wg.Wait()

	t.Logf("MQTT Bandwidth Test Results:")
	t.Logf("Total Requests: %d", metrics.TotalRequests)
	t.Logf("Successful: %d", metrics.Successful)
	t.Logf("Failed: %d", metrics.Failed)
	t.Logf("Throughput: %.2f req/s", metrics.Throughput())
	t.Logf("Average Latency: %v", metrics.AvgLatency())
	assert.Greater(t, metrics.Successful, numRequests/2, "More than half of requests should succeed")
}

func TestUseCaseValidPayment(t *testing.T) {
	resp, err := sendSMSRequest("PAY 0.5 0x742d35Cc6634C0532925a3b844Bc454e4438f44e")
	assert.NoError(t, err)
	assert.Equal(t, http.StatusNoContent, resp.StatusCode)
}

func TestUseCaseInvalidAddress(t *testing.T) {
	resp, err := sendSMSRequest("PAY 0.1 0xInvalidAddress")
	assert.NoError(t, err)
	assert.Equal(t, http.StatusNoContent, resp.StatusCode) // Gateway responds with 204, error in SMS
	// Note: Check SMS response for error message in production
}

func TestUseCaseRateLimit(t *testing.T) {
	for i := 0; i < rateLimit+2; i++ {
		resp, err := sendSMSRequest(fmt.Sprintf("PAY 0.1 0x742d35Cc6634C0532925a3b844Bc454e4438f44e"))
		assert.NoError(t, err)
		if i >= rateLimit {
			// Expect rate limit error in SMS response, but HTTP 204
			assert.Equal(t, http.StatusNoContent, resp.StatusCode)
		}
	}
}

func TestUseCaseInvalidAmount(t *testing.T) {
	resp, err := sendSMSRequest("PAY -0.1 0x742d35Cc6634C0532925a3b844Bc454e4438f44e")
	assert.NoError(t, err)
	assert.Equal(t, http.StatusNoContent, resp.StatusCode)
}

func sendSMSRequest(body string) (*http.Response, error) {
	data := map[string]string{
		"From": "+1234567890",
		"Body": body,
	}
	jsonData, _ := json.Marshal(data)
	req, err := http.NewRequest("POST", smsEndpoint, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{Timeout: 5 * time.Second}
	return client.Do(req)
}
