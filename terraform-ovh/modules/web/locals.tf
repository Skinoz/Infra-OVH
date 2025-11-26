locals {
  instance_name        = "Serveur Web ${var.instance_key}"
  image_folder_pattern = "web-${var.server_number}-*"
  flavor_name          = var.flavor_name
  network_name         = var.network_name
}
