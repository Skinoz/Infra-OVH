# Instances Web avec gestion dynamique
module "web" {
  source   = "../../modules/web"
  for_each = var.web_instances

  instance_key  = each.key
  server_number = each.value.server_number
  flavor_name   = var.web_flavor
  network_name  = var.network_name
}