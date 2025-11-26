data "external" "latest_image" {
  program = ["bash", "-c", <<-EOF
    latest_version=$(ls -t ~/infra-ovh/vm-images/${local.image_folder_pattern}/terraform-vars.json 2>/dev/null | head -n1)
    if [ -z "$latest_version" ]; then
      echo '{"image_name":"web-${var.server_number}-1.0","server":"web${var.server_number}"}'
    else
      cat "$latest_version"
    fi
  EOF
  ]
}

data "openstack_images_image_v2" "image" {
  name = data.external.latest_image.result.image_name
}

resource "openstack_compute_instance_v2" "web" {
  name            = local.instance_name
  image_name      = data.openstack_images_image_v2.image.name
  image_id        = data.openstack_images_image_v2.image.id
  flavor_name     = local.flavor_name

  network {
    name = local.network_name
  }
}
