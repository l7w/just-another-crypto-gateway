datacenter = "dc1"
server {
  enabled = true
  bootstrap_expect = 1
}
client {
  enabled = true
  node_class = "modem-enabled"
  options {
    "driver.docker.enable" = "1"
  }
}