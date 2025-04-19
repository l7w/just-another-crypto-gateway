resource "nomad_job" "sms_proxy" {
  jobspec = file("${path.module}/sms_proxy.nomad")
  hcl2 {
    enabled = true
  }
}

resource "nomad_job" "device_plugin" {
  jobspec = file("${path.module}/device_plugin.nomad")
  hcl2 {
    enabled = true
  }
}

resource "local_file" "sms_proxy_nomad" {
  content = templatefile("${path.module}/sms_proxy.nomad.tmpl", {
    github_repository = var.github_repository
    environment      = var.environment
  })
  filename = "${path.module}/sms_proxy.nomad"
}

resource "local_file" "device_plugin_nomad" {
  content = templatefile("${path.module}/device_plugin.nomad.tmpl", {
    github_repository = var.github_repository
    environment      = var.environment
  })
  filename = "${path.module}/device_plugin.nomad"
}