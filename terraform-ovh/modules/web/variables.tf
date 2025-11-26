# Aucune variable nécessaire - tout est défini en local

variable "instance_key" {
  description = "Clé unique de l'instance (ex: web1, web2)"
  type        = string
}

variable "server_number" {
  description = "Numéro du serveur (1, 2, etc.)"
  type        = number
}

variable "flavor_name" {
  description = "Type d'instance"
  type        = string
}

variable "network_name" {
  description = "Nom du réseau"
  type        = string
}
