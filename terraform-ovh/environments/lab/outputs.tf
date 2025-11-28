output "web_instances" {
  description = "Outputs de toutes les instances web"
  value       = module.web
}

output "haproxy" {
  description = "Outputs du load balancer HAProxy"
  value       = var.haproxy.enabled ? module.haproxy[0] : null
}

output "load_balancer_url" {
  description = "URL du load balancer"
  value       = var.haproxy.enabled ? module.haproxy[0].lb_url : "HAProxy désactivé"
}

output "haproxy_backends" {
  description = "Liste des instances web utilisées comme backends"
  value = var.haproxy.enabled ? {
    for key in var.haproxy.backend_instances : key => module.web[key].instance_ip
  } : {}
}
