package main

import (
	"context"
	"fmt"
	"github.com/hashicorp/nomad/devices"
	"github.com/hashicorp/nomad/plugins/device"
	"github.com/hashicorp/go-hclog"
	"os/exec"
	"strings"
	"time"
)

type ModemDevicePlugin struct {
	logger hclog.Logger
}

func (p *ModemDevicePlugin) PluginInfo() (*device.PluginInfo, error) {
	return &device.PluginInfo{
		Name:       "quectel_modem",
		PluginType: "device",
	}, nil
}

func (p *ModemDevicePlugin) Fingerprint(ctx context.Context) (<-chan *device.FingerprintResponse, error) {
	ch := make(chan *device.FingerprintResponse)
	go p.fingerprint(ctx, ch)
	return ch, nil
}

func (p *ModemDevicePlugin) fingerprint(ctx context.Context, ch chan *device.FingerprintResponse) {
	defer close(ch)

	for {
		select {
		case <-ctx.Done():
			return
		default:
			modems, err := detectModems()
			if err != nil {
				p.logger.Error("Failed to detect modems", "error", err)
				continue
			}

			for _, modem := range modems {
				ch <- &device.FingerprintResponse{
					Devices: []*device.DeviceGroup{
						{
							Vendor: "Quectel",
							Type:   "modem",
							Name:   fmt.Sprintf("modem-%s", modem.IMEI),
							Devices: []*device.Device{
								{
									ID: modem.IMEI,
									Health: device.DeviceHealthHealthy,
									Attributes: map[string]*devices.Attribute{
										"port":   {Value: modem.Port},
										"imei":   {Value: modem.IMEI},
										"signal": {Value: modem.Signal},
									},
								},
							},
						},
					},
				}
			}
			time.Sleep(10 * time.Second)
		}
	}
}

type ModemInfo struct {
	Port   string
	IMEI   string
	Signal string
}

func detectModems() ([]ModemInfo, error) {
	// Simulate modem detection (use `ls /dev/ttyUSB*` and AT commands in production)
	cmd := exec.Command("ls", "/dev/ttyUSB*")
	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	ports := strings.Split(strings.TrimSpace(string(output)), "\n")
	var modems []ModemInfo
	for i, port := range ports {
		// Mock IMEI and signal (replace with AT+CGSN and AT+CSQ)
		modems = append(modems, ModemInfo{
			Port:   port,
			IMEI:   fmt.Sprintf("12345678901234%d", i),
			Signal: "20",
		})
	}
	return modems, nil
}

func main() {
	plugin := &ModemDevicePlugin{
		logger: hclog.New(&hclog.LoggerOptions{
			Name:   "quectel_modem",
			Level:  hclog.Info,
			Output: hclog.DefaultOutput,
		}),
	}
	device.Serve(plugin)
}
