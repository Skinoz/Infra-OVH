variable "ovh_application_key" {
  description = "OVH Application Key"
  type        = string
  sensitive   = true
}

variable "ovh_application_secret" {
  description = "OVH Application Secret"
  type        = string
  sensitive   = true
}

variable "ovh_consumer_key" {
  description = "OVH Consumer Key"
  type        = string
  sensitive   = true
}

variable "web_instances" {
  description = "Map des instances web à créer"
  type = map(object({
    server_number = number
  }))
}

variable "web_flavor" {
  description = "Type d'instance pour les serveurs web"
  type        = string
}

variable "network_name" {
  description = "Nom du réseau"
  type        = string
}

variable "haproxy_flavor" {
  description = "Type d'instance pour HAProxy"
  type        = string
  default     = "b2-7"
}

variable "haproxy" {
  description = "Configuration du load balancer HAProxy"
  type = object({
    enabled           = bool
    flavor            = string
    backend_instances = list(string)
  })
  default = {
    enabled           = false
    flavor            = "b2-7"
    backend_instances = []
  }
}