terraform {
  required_version = ">= 1.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "openstack" {
  cloud = "openstack"
}

############################
# APP-DEFAULTS (defined by the app developer)
############################

locals {
  app_name = "pgadmin"
  flavor   = "gp1.small"
  key_pair = ""

  # Addresses are publicly routed, so the fixed address is reachable
  # on its own - and a floating IP cannot be attached.
  enable_floating_ip = false
}

data "openstack_images_image_v2" "image" {
  name        = var.image_name
  most_recent = true
}

# External network for floating IPs
data "openstack_networking_network_v2" "external" {
  name = var.floating_ip_pool
}

############################
# USER MANAGEMENT (CONTRACT)
############################

locals {
  all_users = flatten([
    for team, members in var.users : [
      for member in members : {
        id       = "${team}-${replace(split("@", member.email)[0], ".", "-")}"
        team     = team
        email    = member.email
        username = replace(split("@", member.email)[0], ".", "-")
      }
    ]
  ])

  users_map  = { for user in local.all_users : user.id => user }
  teams_list = distinct([for user in local.all_users : user.team])

  # Team email used as the pgAdmin login.
  # Team names may contain spaces and special characters (e.g. "Team #1"),
  # which are invalid in email addresses. The name is therefore normalized:
  # lowercased, spaces → "-", all non-alphanumeric characters (except "-") removed.
  # "Team #1" → "team-1@example.com"
  team_account_email = {
    for team in local.teams_list : team =>
    "${replace(replace(lower(team), " ", "-"), "/[^a-z0-9-]/", "")}@example.com"
  }
}

# One password per team — no YAML special characters
resource "random_password" "team_passwords" {
  for_each         = toset(local.teams_list)
  length           = 16
  special          = true
  override_special = "!#-_~"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

############################
# TEAM-BASED VMs
############################

resource "openstack_networking_port_v2" "team_port" {
  for_each           = toset(local.teams_list)
  network_id         = var.network_uuid
  security_group_ids = [var.shared_secgroup_id]
}

# One VM per team — a single shared pgAdmin account for the entire team
resource "openstack_compute_instance_v2" "team_pgadmin" {
  for_each = toset(local.teams_list)

  name        = "${local.app_name}-${each.key}"
  image_id    = data.openstack_images_image_v2.image.id
  flavor_name = local.flavor
  key_pair    = local.key_pair != "" ? local.key_pair : null

  timeouts {
    create = "15m"
    delete = "15m"
  }

  network {
    port = openstack_networking_port_v2.team_port[each.key].id
  }

  user_data = templatefile("${path.module}/user-data.yaml.tpl", {
    users     = { (each.key) = { id = each.key, team = each.key, email = local.team_account_email[each.key] } }
    passwords = { (each.key) = random_password.team_passwords[each.key].result }
  })

  metadata = {
    team = each.key
  }
}

############################
# FLOATING IPs
############################

resource "openstack_networking_floatingip_v2" "team_fip" {
  for_each = local.enable_floating_ip ? toset(local.teams_list) : toset([])

  pool = data.openstack_networking_network_v2.external.name
}

resource "openstack_networking_floatingip_associate_v2" "team_fip_assoc" {
  for_each = local.enable_floating_ip ? toset(local.teams_list) : toset([])

  floating_ip = openstack_networking_floatingip_v2.team_fip[each.key].address
  port_id     = openstack_networking_port_v2.team_port[each.key].id

  depends_on = [openstack_compute_instance_v2.team_pgadmin]
}

############################
# OUTPUT CONTRACT
############################

locals {
  # Each user in the output receives the credentials of the shared team account
  user_accounts = {
    for uid, user in local.users_map : uid => {
      type     = "password"
      ip       = local.enable_floating_ip ? openstack_networking_floatingip_v2.team_fip[user.team].address : openstack_networking_port_v2.team_port[user.team].all_fixed_ips[0]
      port     = 80
      username = local.team_account_email[user.team]
      auth     = random_password.team_passwords[user.team].result
    }
  }
}
