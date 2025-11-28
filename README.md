# Infrastructure OVH - Terraform & Packer

Ce projet permet de gérer l'infrastructure OVH avec Terraform et de créer des images personnalisées avec Packer.

## Prérequis

- Terraform >= 0.14.0
- Packer >= 1.7.0
- Ansible >= 2.9
- Un compte OVH avec les credentials API
- Accès OpenStack configuré

## Configuration initiale

### 1. Configuration des credentials OVH

Importez votre fichier de configuration OpenStack :

```bash
source openrc.sh
```

Le système vous demandera votre mot de passe OpenStack.

### 2. Configuration Terraform

Créez un fichier `terraform.tfvars` dans `terraform-ovh/environments/lab/` :

```bash
cd terraform-ovh/environments/lab/
cp terraform.tfvars.example terraform.tfvars
```

Éditez `terraform.tfvars` et remplissez vos credentials :

```hcl
# Credentials OVH
ovh_application_key    = "votre_application_key"
ovh_application_secret = "votre_application_secret"
ovh_consumer_key       = "votre_consumer_key"

# Configuration des instances web
web_instances = {
  web1 = {
    server_number = 1
  }
  web2 = {
    server_number = 2
  }
}

# Configuration du Load Balancer HAProxy
haproxy = {
  enabled           = true
  flavor            = "b2-7"
  backend_instances = ["web1", "web2"]  # Références aux clés de web_instances
}

web_flavor   = "b2-7"
network_name = "Ext-Net"
```

## Création d'images avec Packer

Les images sont créées avec Nginx préinstallé et configuré via **Ansible**. Le script `build.sh` vous permet de choisir :
- Le **numéro du serveur** (1, 2, 3, etc.)
- La **version** de l'image (ex: 1.0, 1.1, 2.0)

### Utilisation

```bash
cd packer/
./build.sh
# Exemple : ./build.sh 1 1.0 
```

Le script vous demandera :
1. Le numéro du serveur (ex: 1 pour web-1)
2. La version (ex: 1.0)

L'image sera créée dans `~/infra-ovh/vm-images/web-{server_number}-{version}/`

### Architecture

```
packer/
├── debian-nginx.pkr.hcl    # Template Packer
├── build.sh                # Script de build
└── http/
    └── preseed.cfg         # Configuration Debian

ansible/
├── playbooks/
│   └── web.yml             # Playbook de configuration
├── templates/
│   ├── nginx-template.conf.j2
│   └── index.html.j2
└── ansible.cfg
```

### Structure des images

```
vm-images/
├── web-1-1.0/
│   └── terraform-vars.json
├── web-1-1.1/
│   └── terraform-vars.json
└── web-2-1.0/
    └── terraform-vars.json
```

Le fichier `terraform-vars.json` contient :
```json
{
  "image_name": "web-1-1.0",
  "server": "web1"
}
```

## Déploiement avec Terraform

### Initialisation

```bash
cd terraform-ovh/environments/lab/
terraform init
```

### Planification

```bash
terraform plan
```

### Déploiement

```bash
terraform apply
```

Terraform vous demandera votre **mot de passe OpenStack** pour l'authentification.

### Destruction

```bash
terraform destroy
```

## Gestion des instances

### Ajouter une instance

Éditez `terraform.tfvars` et ajoutez une entrée dans `web_instances` :

```hcl
web_instances = {
  web1 = {
    server_number = 1
  }
  web2 = {
    server_number = 1
  }
  web3 = {
    server_number = 2
  }
}
```

Puis exécutez :

```bash
terraform apply
```

### Supprimer une instance

Retirez l'entrée correspondante de `web_instances` dans `terraform.tfvars` et exécutez :

```bash
terraform apply
```

## Outputs

Après le déploiement, vous pouvez voir les informations des instances :

```bash
terraform output
```

Exemple de sortie avec HAProxy activé :

```
web_instances = {
  "web1" = {
    "instance_id" = "de1bdae3-ca6c-43e4-b227-bce036b30420"
    "instance_ip" = "37.59.26.205"
    "instance_name" = "Serveur Web web1"
    "ssh_command" = "ssh -i ~/.ssh/id_rsa debian@37.59.26.205"
  }
  "web2" = {
    "instance_id" = "43f18b8e-9ba4-4c09-baa6-91ede0ffae15"
    "instance_ip" = "51.255.60.24"
    "instance_name" = "Serveur Web web2"
    "ssh_command" = "ssh -i ~/.ssh/id_rsa debian@51.255.60.24"
  }
}

haproxy = {
  "instance_id" = "abc-123-def"
  "instance_ip" = "51.xxx.xxx.xxx"
  "lb_url"      = "http://51.xxx.xxx.xxx"
  "ssh_command" = "ssh -i ~/.ssh/id_rsa debian@51.xxx.xxx.xxx"
}

load_balancer_url = "http://51.xxx.xxx.xxx"

haproxy_backends = {
  "web1" = "37.59.26.205"
  "web2" = "51.255.60.24"
}
```

## Connexion SSH

Utilisez la commande SSH fournie dans les outputs :

```bash
ssh -i ~/.ssh/id_rsa debian@<IP_INSTANCE>
```

## Structure du projet

```
infra-ovh/
├── packer/
│   ├── build.sh              # Script de build des images
│   ├── debian-nginx.pkr.hcl  # Template Packer
│   └── http/                 # Fichiers de configuration
├── ansible/
│   ├── playbooks/            # Playbooks Ansible
│   ├── templates/            # Templates Jinja2
│   └── ansible.cfg           # Configuration Ansible
├── terraform-ovh/
│   ├── modules/
│   │   └── web/              # Module pour instances web
│   └── environments/
│       └── lab/              # Environnement lab
├── vm-images/                # Images générées par Packer
├── openrc.sh                 # Configuration OpenStack
└── README.md
```

## Sécurité

⚠️ **Important** :
- Ne jamais commiter `terraform.tfvars` avec vos credentials
- Ne jamais commiter `openrc.sh`
- Utiliser `.gitignore` pour exclure les fichiers sensibles
- Les credentials sont marqués comme `sensitive = true` dans Terraform

## Dépannage

### Erreur "External Program Execution Failed"

Si vous voyez cette erreur, vérifiez que :
1. Les dossiers d'images existent dans `~/infra-ovh/vm-images/`
2. Les fichiers `terraform-vars.json` sont présents et valides
3. Le pattern `web-{number}-*` correspond à vos dossiers

### Erreur d'authentification OpenStack

1. Vérifiez que vous avez sourcé `openrc.sh`
2. Vérifiez votre mot de passe OpenStack
3. Vérifiez vos credentials OVH dans `terraform.tfvars`

## Support

Pour plus d'informations :
- [Documentation Terraform OVH](https://registry.terraform.io/providers/ovh/ovh/latest/docs)
- [Documentation OpenStack Provider](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs)
- [Documentation Packer](https://www.packer.io/docs)

## Architecture avec Load Balancer

Lorsque HAProxy est activé, l'architecture devient :

```
                    Internet
                       |
                 [HAProxy LB]
                    /  |  \
                   /   |   \
              [Web1] [Web2] [Web3]
```

### Activer/Désactiver le Load Balancer

Pour **activer** HAProxy, dans `terraform.tfvars` :

```hcl
haproxy = {
  enabled           = true
  flavor            = "b2-7"
  backend_instances = ["web1", "web2", "web3"]
}
```

Pour **désactiver** HAProxy :

```hcl
haproxy = {
  enabled           = false
  flavor            = "b2-7"
  backend_instances = []
}
```

### Choisir les backends

Vous pouvez sélectionner quelles instances web seront derrière le load balancer :

```hcl
web_instances = {
  web1 = { server_number = 1 }
  web2 = { server_number = 1 }
  web3 = { server_number = 2 }
  web4 = { server_number = 2 }
}

haproxy = {
  enabled           = true
  flavor            = "b2-7"
  backend_instances = ["web1", "web2"]  # Seulement web1 et web2 derrière HAProxy
}
```

### Construire l'image HAProxy

Avant de déployer HAProxy pour la première fois :

```bash
cd packer/
chmod +x build-haproxy.sh
./build-haproxy.sh 1.0
```
