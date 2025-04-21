resource "kubernetes_deployment" "prometheus" {
  metadata {
    name = "prometheus"
    namespace = "default"
  }
  spec {
    selector {
      match_labels = {
        app = "prometheus"
      }
    }
    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }
      spec {
        container {
          image = "prom/prometheus:v2.45.0"
          name  = "prometheus"
          port {
            container_port = 9090
          }
          volume_mount {
            name       = "config"
            mount_path = "/etc/prometheus"
          }
        }
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.prometheus.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "grafana" {
  metadata {
    name = "grafana"
    namespace = "default"
  }
  spec {
    selector {
      match_labels = {
        app = "grafana"
      }
    }
    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }
      spec {
        container {
          image = "grafana/grafana:8.3.3"
          name  = "grafana"
          port {
            container_port = 3000
          }
          volume_mount {
            name       = "dashboard"
            mount_path = "/etc/grafana/provisioning/dashboards"
          }
        }
        volume {
          name = "dashboard"
          config_map {
            name = kubernetes_config_map.grafana.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_config_map" "prometheus" {
  metadata {
    name = "prometheus-config"
    namespace = "default"
  }
  data = {
    "prometheus.yml" = file("${path.module}/prometheus.yml")
  }
}

resource "kubernetes_config_map" "grafana" {
  metadata {
    name = "grafana-dashboard"
    namespace = "default"
  }
  data = {
    "dashboard.json" = file("${path.module}/grafana_dashboard.json")
  }
}

resource "kubernetes_service" "prometheus" {
  metadata {
    name = "prometheus"
    namespace = "default"
  }
  spec {
    selector = {
      app = "prometheus"
    }
    port {
      port        = 9090
      target_port = 9090
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_service" "grafana" {
  metadata {
    name = "grafana"
    namespace = "default"
  }
  spec {
    selector = {
      app = "grafana"
    }
    port {
      port        = 3000
      target_port = 3000
    }
    type = "ClusterIP"
  }
}