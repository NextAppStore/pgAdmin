packer {
  required_plugins {
    openstack = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/openstack"
    }
  }
}

locals {
  cloud                   = "openstack"
  provision_script        = "scripts/provision.sh"
  source_image_name       = "Ubuntu 22.04"
  flavor                  = "gp1.small"
  ssh_username            = "ubuntu"
  ssh_timeout             = "20m"
  use_blockstorage_volume = false
  volume_size             = 10
  use_floating_ip         = false
}

source "openstack" "image" {
  cloud                   = local.cloud
  image_name              = var.image_name
  source_image_name       = local.source_image_name
  flavor                  = local.flavor
  networks                = var.networks
  security_groups         = var.security_groups
  use_blockstorage_volume = local.use_blockstorage_volume
  volume_size             = local.volume_size
  use_floating_ip         = local.use_floating_ip
  # DHBWV6 is dual-stack; without an explicit version Packer prefers the
  # IPv4 address. The DHBW VPN only routes IPv6 (2001:7c0:1b20::/48) to
  # the build host, no route into the 10.200.x.x net - so IPv6 must be
  # forced for local builds over VPN to reach SSH at all.
  ssh_ip_version = "6"
  ssh_timeout    = local.ssh_timeout
  ssh_username   = local.ssh_username
}

build {
  sources = ["source.openstack.image"]
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init...'",
      "cloud-init status --wait || true",
      "echo 'Cloud-init ready'"
    ]
  }
  provisioner "shell" {
    script      = local.provision_script
    max_retries = 3
  }
}
