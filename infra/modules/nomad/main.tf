variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name (e.g., user/repo)"
  type        = string
}

variable "nomad_address" {
  description = "Nomad server address"
  type        = string
}

variable "modem_count" {
  description = "Number of modems to manage"
  type        = number
  default     = 50
  validation {
    condition     = var.modem_count >= 1 && var.modem_count <= 50
    error_message = "Modem count must be between 1 and 50."
  }
}

locals {
  modem_devices = [
    for i in range(var.modem_count) : {
      host_path      = "/dev/ttyUSB${i}"
      container_path = "/dev/ttyUSB${i}"
    }
  ]
  replicas = var.environment == "prod" ? 3 : 1
  resources = {
    dev    = { cpu = 200, memory = 256 }
    staging = { cpu = 500, memory = 512 }
    prod   = { cpu = 1000, memory = 1024 }
  }
}

resource "nomad_job" "sms_proxy" {
  jobspec = templatefile("${path.module}/sms_proxy.nomad.tmpl", {
    github_repository = var.github_repository
    environment      = var.environment
    modem_devices    = local.modem_devices
    replicas         = local.replicas
    resources        = local.resources[var.environment]
  })
}

resource "nomad_job" "device_plugin" {
  jobspec = templatefile("${path.module}/device_plugin.nomad.tmpl", {
    github_repository = var.github_repository
    environment      = var.environment
    modem_count      = var.modem_count
    replicas         = local.replicas
    resources        = local.resources[var.environment]
  })
}