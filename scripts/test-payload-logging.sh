#!/bin/bash

# Configuration
KONG_URL="http://localhost:8000"
ELASTIC_URL="http://localhost:9200"
INDEX_NAME="kong-api-logs"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Démarrage des tests de charge et d'observabilité...${NC}"

# Fonction pour attendre que les logs soient indexés
wait_for_indexing() {
    echo -e "⏳ Attente de l'indexation Elasticsearch (5s)..."
    sleep 5
}

# Fonction de test
test_payload() {
    local size_kb=$1
    local size_bytes=$((size_kb * 1024))
    local filename="payload_${size_kb}kb.txt"
    
    echo -e "\n--------------------------------------------------"
    echo -e "${YELLOW}🧪 Test avec Payload: ${size_kb}KB (${size_bytes} bytes)${NC}"
    
    # Générer le fichier
    # Utilise /dev/urandom pour éviter la compression trop facile par Gzip si on avait que des zéros
    # Mais ici on veut tester le comportement du plugin Lua, donc du texte simple suffit pour la lecture humaine
    # On va générer un pattern répétitif pour que ce soit compressable mais pas vide
    yes "Data data data data " | head -c "$size_bytes" > "$filename"
    
    # Envoyer la requête
    echo -e "📤 Envoi de la requête POST vers $KONG_URL/local-echo..."
    local start_time=$(date +%s%N)
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KONG_URL/local-echo" \
        -H "Content-Type: text/plain" \
        --data-binary "@$filename")
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))

    if [ "$http_code" -eq 200 ]; then
        echo -e "${GREEN}✅ Succès (HTTP 200) - Durée: ${duration}ms${NC}"
    else
        echo -e "${RED}❌ Échec (HTTP $http_code) - Durée: ${duration}ms${NC}"
    fi

    # Nettoyage
    rm "$filename"

    # Vérification Elasticsearch
    wait_for_indexing
    
    echo -e "🔎 Vérification des logs dans Elasticsearch..."
    # On cherche le dernier log pour cette URI
    # Note: On filtre par taille approximative du body si possible, ou juste le dernier log
    
    local log_query='{
        "size": 1,
        "sort": [{"started_at": "desc"}],
        "query": {
            "bool": {
                "must": [
                    { "match": { "request.uri": "/local-echo" } }
                ]
            }
        }
    }'

    local response=$(curl -s -X GET "$ELASTIC_URL/$INDEX_NAME/_search" -H 'Content-Type: application/json' -d "$log_query")
    
    # Extraction des champs intéressants avec jq
    local log_body=$(echo "$response" | jq -r '.hits.hits[0]._source.request.body // "N/A"')
    local log_size=${#log_body}
    
    echo -e "📝 Taille du body logué dans Elastic: ${log_size} caractères"
    
    if [ "$log_size" -gt 0 ] && [ "$log_body" != "N/A" ]; then
        # Vérification si c'est du Base64 (indication de compression gzippée par le code Lua)
        if [[ "$log_body" == *"=="* ]] || [[ "$log_size" -lt "$size_bytes" ]]; then
             echo -e "${GREEN}✅ Body logué (potentiellement compressé/base64)${NC}"
        else
             echo -e "${GREEN}✅ Body logué en clair${NC}"
        fi
        
        # Afficher un extrait
        echo -e "📄 Extrait du body logué: ${log_body:0:100}..."
    else
        echo -e "${RED}❌ Body non trouvé ou vide dans les logs${NC}"
    fi
}

# 1. Test Tiny Payload (1KB) - Devrait être en clair
test_payload 1

# 2. Test Medium Payload (20KB) - Devrait être en clair (< 32KB config)
test_payload 20

# 3. Test Large Payload (40KB) - Devrait être compressé (Base64/Gzip) car > 32KB
test_payload 40

# 4. Test Huge Payload (1MB) - Test des limites Kong/Nginx
test_payload 1024

echo -e "\n--------------------------------------------------"
echo -e "${GREEN}🎉 Tests terminés${NC}"
