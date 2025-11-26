#!/bin/bash
# filepath: /home/skinoz/infra-ovh/packer/build.sh

set -e

SRV_NUMBER=${1:-1}
VERSION=${2:-1.1}

echo "==> Construction de l'image Web Server ${SRV_NUMBER} v${VERSION}..."

# Vérifier si OpenStack est configuré pour l'upload automatique
if ! command -v openstack &> /dev/null; then
    echo "⚠️  Warning: OpenStack CLI non trouvé. L'image ne sera pas uploadée automatiquement."
    echo "   Installez openstack CLI et sourcez openrc.sh pour l'upload automatique."
fi

packer build \
  -var "srv=${SRV_NUMBER}" \
  -var "version=${VERSION}" \
  debian-nginx.pkr.hcl

echo "==> ✅ Image Web Server ${SRV_NUMBER} v${VERSION} construite avec succès!"
