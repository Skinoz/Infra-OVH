packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "version" {
  type        = string
  default     = "1.0"
  description = "Version de l'image à construire"
}

variable "output_directory" {
  type    = string
  default = "../vm-images"
}

variable "srv" {
  type        = string
  description = "Numéro du serveur (1, 2, 3, etc.)"
}

variable "ssh_public_key_file" {
  type        = string
  default     = "~/.ssh/id_rsa.pub"
  description = "Chemin vers la clé SSH publique à ajouter dans l'image"
}

source "qemu" "debian12-nginx" {
  iso_url          = "https://cdimage.debian.org/cdimage/archive/12.7.0/amd64/iso-cd/debian-12.7.0-amd64-netinst.iso"
  iso_checksum     = "sha256:8fde79cfc6b20a696200fc5c15219cf6d721e8feb367e9e0e33a79d1cb68fa83"
  output_directory = "${var.output_directory}/web-${var.srv}-${var.version}"
  skip_compaction  = false
  use_backing_file = false
  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"
  disk_size        = "20G"
  format           = "qcow2"
  accelerator      = "kvm"
  memory           = 1024
  http_directory   = "http"
  ssh_username     = "debian"
  ssh_password     = "debian"
  ssh_timeout      = "20m"
  vm_name          = "web-${var.srv}-${var.version}.qcow2"
  net_device       = "virtio-net"
  disk_interface   = "virtio"
  boot_wait        = "5s"
  boot_command = [
    "<esc><wait>",
    "auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg<enter>"
  ]
}

build {
  sources = ["source.qemu.debian12-nginx"]

  provisioner "shell" {
    inline = [
      "sudo rm -rf /var/lib/cloud/*",
      "sudo cloud-init clean",
      "sudo rm -f /etc/nginx/sites-enabled/default"
    ]
  }

  # Ajouter la clé SSH publique pour l'utilisateur debian
  provisioner "file" {
    source      = pathexpand(var.ssh_public_key_file)
    destination = "/tmp/authorized_keys"
  }

  provisioner "shell" {
    inline = [
      "mkdir -p /home/debian/.ssh",
      "cat /tmp/authorized_keys >> /home/debian/.ssh/authorized_keys",
      "chmod 700 /home/debian/.ssh",
      "chmod 600 /home/debian/.ssh/authorized_keys",
      "chown -R debian:debian /home/debian/.ssh",
      "rm /tmp/authorized_keys",
      "# Configurer SSH pour accepter les clés",
      "sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config",
      "sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config"
    ]
  }

  provisioner "file" {
    source      = "files/nginx-template.conf"
    destination = "/tmp/nginx-template.conf"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/nginx-template.conf /etc/nginx/sites-available/default",
      "sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default",
      "sudo rm -f /var/www/html/index.nginx-debian.html"
    ]
  }

  # Générer le HTML à partir du template avec templatefile()
  provisioner "file" {
    content     = templatefile("files/web-template.pkrtpl.hcl", {
      server_number = var.srv
      version       = var.version
    })
    destination = "/tmp/index.html"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/index.html /var/www/html/index.html",
      "sudo chmod 644 /var/www/html/index.html",
      "sudo chown www-data:www-data /var/www/html/index.html",
      "sudo nginx -t"
    ]
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      image_name    = "web-${var.srv}-${var.version}"
      server_number = var.srv
      version       = var.version
      build_time    = timestamp()
    }
  }

  post-processor "shell-local" {
    inline = [
      "echo 'Image web-${var.srv}-${var.version}.qcow2 créée avec succès'",
      "ls -lh ${var.output_directory}/web-${var.srv}-${var.version}/web-${var.srv}-${var.version}.qcow2",
      "echo 'Upload vers OpenStack OVH...'",
      "openstack image create --disk-format qcow2 --container-format bare --file ${var.output_directory}/web-${var.srv}-${var.version}/web-${var.srv}-${var.version}.qcow2 --property image_original_user=debian --property hw_disk_bus=scsi --property hw_scsi_model=virtio-scsi --property packer_version=${var.version} --property packer_server=${var.srv} --private web-${var.srv}-${var.version} || echo 'Image déjà existante'",
      "echo '{\"image_name\": \"web-${var.srv}-${var.version}\", \"version\": \"${var.version}\", \"server\": \"${var.srv}\"}' > ${var.output_directory}/web-${var.srv}-${var.version}/terraform-vars.json"
    ]
  }
}
