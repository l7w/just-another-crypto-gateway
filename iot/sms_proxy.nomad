job "sms_proxy" {
  datacenters = ["dc1"]
  type        = "service"

  group "proxy" {
    count = 5

    network {
      mode = "bridge"
      port "http" { to = 8080 }
      port "metrics" { to = 9090 }
    }

    service {
      name     = "sms-proxy"
      port     = "http"
      provider = "consul"
      tags     = ["proxy"]
      check {
        type     = "http"
        path     = "/metrics"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "proxy" {
      driver = "docker"

      config {
        image = "sms-proxy:latest"
        ports = ["http", "metrics"]
        volumes = ["/etc/sms-proxy/config.toml:/etc/sms-proxy/config.toml"]
        devices = [
          {
            name = "modem"
            count = 10
          }
        ]
      }

      resources {
        cpu    = 500
        memory = 512
      }

      template {
        destination = "/etc/sms-proxy/config.toml"
        data        = <<EOF
redis_url = "redis://redis:6379"
api_addr = "0.0.0.0:8080"
modem_ports = "{{range $i, $modem := .Nomad.Devices.modem}}{{if $i}},{{end}}{{$modem.Attributes.port}}{{end}}"
EOF
      }
    }
  }

  group "sms_processor" {
    count = 50

    network {
      mode = "bridge"
      port "http" {}
    }

    task "processor" {
      driver = "docker"

      config {
        image = "sms-processor:latest" # Image for processing SMS tasks
        ports = ["http"]
      }

      resources {
        cpu    = 200
        memory = 256
      }

      constraint {
        attribute = "${device.modem}"
        operator  = "exists"
      }

      affinity {
        attribute = "${device.modem.signal}"
        operator  = ">="
        value     = "15"
      }
    }
  }
}
