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

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
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
	rateLimit     = 10
	rateLimitWait = 60 * time.Second
)

var (
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total HTTP requests",
		},
		[]string{"path", "status"},
	)
	mqttRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mqtt_requests_total",
			Help: "Total MQTT requests",
		},
		[]string{"status"},
	)
	httpRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request duration",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"path"},
	)
	mqttRequestDuration = prometheus.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "mqtt_request_duration_seconds",
			Help:    "MQTT request duration",
			Buckets: prometheus.DefBuckets,
		},
	)
)

func init() {
	prometheus.MustRegister(httpRequestsTotal, mqttRequestsTotal, httpRequestDuration, mqttRequestDuration)
	go func() {
		http.Handle("/metrics", promhttp.Handler())
		http.ListenAndServe(":9090", nil)
	}()
}

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
				httpRequestsTotal.WithLabelValues("/sms", fmt.Sprintf("%d", resp.StatusCode)).Inc()
				httpRequestDuration.WithLabelValues("/sms").Observe(float64(latency) / float64(time.Second))
				return
			}
			metrics.Record(true, latency)
			httpRequestsTotal.WithLabelValues("/sms", "204").Inc()
			httpRequestDuration.WithLabelValues("/sms").Observe(float64(latency) / float64(time.Second))
		}(i)

		if (i+1)%rateLimit == 0 {
			time.Sleep(rateLimitWait / 10)
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
				mqttRequestsTotal.WithLabelValues("error").Inc()
				mqttRequestDuration.Observe(float64(latency) / float64(time.Second))
				return
			}
			metrics.Record(true, latency)
			mqttRequestsTotal.WithLabelValues("success").Inc()
			mqttRequestDuration.Observe(float64(latency) / float64(time.Second))
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
	httpRequestsTotal.WithLabelValues("/sms", "204").Inc()
}

func TestUseCaseInvalidAddress(t *testing.T) {
	resp, err := sendSMSRequest("PAY 0.1 0xInvalidAddress")
	assert.NoError(t, err)
	assert.Equal(t, http.StatusNoContent, resp.StatusCode)
	httpRequestsTotal.WithLabelValues("/sms", "204").Inc()
}

func TestUseCaseRateLimit(t *testing.T) {
	for i := 0; i < rateLimit+2; i++ {
		resp, err := sendSMSRequest(fmt.Sprintf("PAY 0.1 0x742d35Cc6634C0532925a3b844Bc454e4438f44e"))
		assert.NoError(t, err)
		if i >= rateLimit {
			httpRequestsTotal.WithLabelValues("/sms", "429").Inc()
		} else {
			httpRequestsTotal.WithLabelValues("/sms", "204").Inc()
		}
	}
}

func TestUseCaseInvalidAmount(t *testing.T) {
	resp, err := sendSMSRequest("PAY -0.1 0x742d35Cc6634C0532925a3b844Bc454e4438f44e")
	assert.NoError(t, err)
	assert.Equal(t, http.StatusNoContent, resp.StatusCode)
	httpRequestsTotal.WithLabelValues("/sms", "204").Inc()
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
