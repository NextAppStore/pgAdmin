variable "image_name" {
  type        = string
  description = "Glance image name — set by the worker at build time. @platform:internal"
}

variable "networks" {
  type        = list(string)
  description = "@openstack:network:id:list Build networks"
  # DHBWV6 — same default choice as terraform/variables.tf's network_uuid;
  # the previous ID no longer exists in this OpenStack project.
  default = ["9b579624-d844-4df3-b38d-89978b31d37d"]
}

variable "security_groups" {
  type        = list(string)
  description = "@openstack:security_group:id:list Build security groups"
  # appstore-insides — allows SSH (22) ingress v4+v6; the previous ID
  # no longer exists in this OpenStack project and failed every Packer
  # build with "Unable to find security_group" without a wizard override.
  default = ["934851d7-90a2-42ab-927c-fae610697fc7"]
}
