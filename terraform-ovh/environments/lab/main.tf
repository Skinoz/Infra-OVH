# Instances Web avec gestion dynamique
module "web" {
  source   = "../../modules/web"
  for_each = var.web_instances

  instance_key  = each.key
  server_number = each.value.server_number
  flavor_name   = var.web_flavor
  network_name  = var.network_name
}

# Attendre que toutes les instances web soient prêtes
resource "time_sleep" "wait_for_web_instances" {
  depends_on = [module.web]
  
  create_duration = "10s"
}

# Instance HAProxy (Load Balancer)
module "haproxy" {
  count  = var.haproxy.enabled ? 1 : 0
  source = "../../modules/haproxy"

  instance_name = "HAProxy Load Balancer"
  backend_ips = [
    for instance_key in var.haproxy.backend_instances : 
    module.web[instance_key].instance_ip
  ]
  flavor_name  = var.haproxy.flavor
  network_name = var.network_name

  depends_on = [time_sleep.wait_for_web_instances]
}