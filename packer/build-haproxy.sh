#!/bin/bash
set -e

VERSION=${1:-1.0}

echo "==> Construction de l'image HAProxy v${VERSION}..."

if ! command -v openstack &> /dev/null; then
    echo "⚠️  Warning: OpenStack CLI non trouvé. L'image ne sera pas uploadée automatiquement."
fi

packer build \
  -var "version=${VERSION}" \
  debian-haproxy.pkr.hcl

echo "==> ✅ Image HAProxy v${VERSION} construite avec succès!"
