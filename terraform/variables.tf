########################################
# Pflicht-Variablen (vom Worker injiziert)
########################################

variable "users" {
  description = "Per-team roster — vom Worker injiziert. @platform:internal"
  type = map(list(object({
    email = string
  })))
  default = {}
}

variable "image_name" {
  description = "Glance-Image-Name — vom Worker zur Apply-Zeit gesetzt. @platform:internal"
  type        = string
}

########################################
# Konfigurierbare Variablen (vom Deployer gesetzt)
########################################

variable "network_uuid" {
  description = "UUID des internen Netzwerks @openstack:network:id"
  type        = string
  # DHBWV6: dual-stack (v4+v6 auf demselben Subnetz-Paar) — jede VM
  # bekommt automatisch beide Fixed-IPs von Neutron.
  default = "9b579624-d844-4df3-b38d-89978b31d37d"
}

variable "floating_ip_pool" {
  description = "Name des External Networks für Floating IPs @openstack:floating_ip_pool:name"
  type        = string
  default     = "DHBWV6"
}

variable "shared_secgroup_id" {
  description = "ID der gemeinsamen Security Group für alle VMs @openstack:security_group:id"
  type        = string
  # appstore-deploy: SSH (22) + HTTP (80) + HTTPS (443) ingress v4+v6.
  # pgAdmin is served over HTTP on port 80 (see outputs.tf), so the
  # SSH-only "appstore-insides" group used for Ubuntu-App doesn't fit
  # here — it has no 80/443 ingress rule at all.
  default = "5c0e96fb-bd1f-41b3-b400-deccf7712a80"
}
