#!/bin/bash

set -e

cd ~/infra-ovh/terraform-ovh/environments/lab/

echo "=========================================="
echo "   TEST COMPLET DE L'INFRASTRUCTURE"
echo "=========================================="

# Récupérer les informations
MASTER_IP=$(terraform output -json database_master | jq -r '.db1.instance_ip')
BACKEND_IP=$(terraform output -json backend_instances | jq -r '.api1.instance_ip')
LB_URL=$(terraform output -raw load_balancer_url)

echo -e "\n📍 Infrastructure:"
echo "  - Load Balancer: $LB_URL"
echo "  - Backend API: $BACKEND_IP"
echo "  - Database Master: $MASTER_IP"

# 1. Vérifier l'état initial de la base de données
echo -e "\n=========================================="
echo "1️⃣  ÉTAT INITIAL DE LA BASE DE DONNÉES"
echo "=========================================="

INITIAL_COUNT=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no debian@$MASTER_IP \
  "sudo -u postgres psql appdb -t -c 'SELECT COUNT(*) FROM data;'" | tr -d ' ')

echo "Nombre d'entrées dans la base: $INITIAL_COUNT"

# 2. Ajouter des données via le Load Balancer (frontend)
echo -e "\n=========================================="
echo "2️⃣  AJOUT DE DONNÉES VIA LE FRONTEND"
echo "=========================================="

TEST_VALUE="Test Full Stack $(date +%s)"
echo "Ajout de la valeur: '$TEST_VALUE'"

RESPONSE=$(curl -s -X POST $LB_URL/api/data \
  -H "Content-Type: application/json" \
  -d "{\"value\":\"$TEST_VALUE\"}")

echo "Réponse du backend:"
echo "$RESPONSE" | jq '.'

# Extraire l'ID de la donnée ajoutée
NEW_ID=$(echo "$RESPONSE" | jq -r '.data.id')
echo -e "\n✅ Donnée ajoutée avec l'ID: $NEW_ID"

# 3. Vérifier dans la base de données master
echo -e "\n=========================================="
echo "3️⃣  VÉRIFICATION DANS LA BASE MASTER"
echo "=========================================="

sleep 2  # Attendre la propagation

DB_RESULT=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no debian@$MASTER_IP \
  "sudo -u postgres psql appdb -t -c \"SELECT id, value, created_at FROM data WHERE id=$NEW_ID;\"")

echo "Résultat dans la base:"
echo "$DB_RESULT"

# 4. Vérifier le nombre total d'entrées
NEW_COUNT=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no debian@$MASTER_IP \
  "sudo -u postgres psql appdb -t -c 'SELECT COUNT(*) FROM data;'" | tr -d ' ')

echo -e "\nNombre d'entrées maintenant: $NEW_COUNT"
echo "Différence: +$((NEW_COUNT - INITIAL_COUNT))"

# 5. Vérifier via l'API que la donnée est bien là
echo -e "\n=========================================="
echo "4️⃣  VÉRIFICATION VIA L'API"
echo "=========================================="

API_DATA=$(curl -s $LB_URL/api/data | jq ".data[] | select(.id==$NEW_ID)")

if [ -n "$API_DATA" ]; then
    echo "✅ Donnée trouvée via l'API:"
    echo "$API_DATA" | jq '.'
else
    echo "❌ Donnée NON trouvée via l'API"
    exit 1
fi

# 6. Vérifier la réplication sur les slaves
echo -e "\n=========================================="
echo "5️⃣  VÉRIFICATION DE LA RÉPLICATION"
echo "=========================================="

SLAVE_IP=$(terraform output -json database_slaves | jq -r '.db2.instance_ip')

if [ "$SLAVE_IP" != "null" ]; then
    echo "Vérification sur le slave: $SLAVE_IP"
    
    sleep 3  # Attendre la réplication
    
    SLAVE_RESULT=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no debian@$SLAVE_IP \
      "sudo -u postgres psql appdb -t -c \"SELECT id, value FROM data WHERE id=$NEW_ID;\"")
    
    if [ -n "$SLAVE_RESULT" ]; then
        echo "✅ Donnée répliquée sur le slave:"
        echo "$SLAVE_RESULT"
    else
        echo "❌ Donnée NON répliquée sur le slave"
    fi
else
    echo "ℹ️  Pas de slave configuré"
fi

# 7. Ajouter plusieurs données en masse
echo -e "\n=========================================="
echo "6️⃣  TEST D'AJOUT EN MASSE"
echo "=========================================="

echo "Ajout de 5 données supplémentaires..."

for i in {1..5}; do
    VALUE="Batch Test $i - $(date +%s)"
    curl -s -X POST $LB_URL/api/data \
      -H "Content-Type: application/json" \
      -d "{\"value\":\"$VALUE\"}" > /dev/null
    echo "  ✓ Donnée $i ajoutée"
    sleep 0.5
done

# 8. Vérifier le total final
FINAL_COUNT=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no debian@$MASTER_IP \
  "sudo -u postgres psql appdb -t -c 'SELECT COUNT(*) FROM data;'" | tr -d ' ')

echo -e "\n📊 Statistiques finales:"
echo "  - Début: $INITIAL_COUNT entrées"
echo "  - Fin: $FINAL_COUNT entrées"
echo "  - Ajoutées: $((FINAL_COUNT - INITIAL_COUNT)) entrées"

# 9. Récupérer les dernières données via l'API
echo -e "\n=========================================="
echo "7️⃣  DERNIÈRES DONNÉES VIA L'API"
echo "=========================================="

curl -s $LB_URL/api/data | jq '{
  total: .count,
  dernières_5_entrées: [.data[0:5] | .[] | {id, value, created_at}]
}'

# 10. Tester la suppression
echo -e "\n=========================================="
echo "8️⃣  TEST DE SUPPRESSION"
echo "=========================================="

echo "Suppression de la donnée ID: $NEW_ID"

DELETE_RESPONSE=$(curl -s -X DELETE $LB_URL/api/data/$NEW_ID)
echo "Réponse:"
echo "$DELETE_RESPONSE" | jq '.'

# Vérifier que la donnée a été supprimée
sleep 1

DELETED_CHECK=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no debian@$MASTER_IP \
  "sudo -u postgres psql appdb -t -c \"SELECT COUNT(*) FROM data WHERE id=$NEW_ID;\"" | tr -d ' ')

if [ "$DELETED_CHECK" = "0" ]; then
    echo "✅ Donnée bien supprimée de la base"
else
    echo "❌ Erreur: la donnée est toujours présente"
fi

# 11. Status global
echo -e "\n=========================================="
echo "9️⃣  STATUS GLOBAL DE L'INFRASTRUCTURE"
echo "=========================================="

curl -s $LB_URL/api/status | jq '{
  status,
  version,
  hostname,
  database: {
    connected: .database.connected,
    records: .database.records_count
  }
}'

echo -e "\n=========================================="
echo "✅ TOUS LES TESTS SONT TERMINÉS"
echo "=========================================="
