#!/bin/bash

# Script pour rafraîchir l'index pattern Kibana et voir les logs Kong

echo "🔧 Rafraîchissement de l'index pattern Kibana..."
echo ""

# Rafraîchir l'index pattern via l'API Kibana
curl -s -X POST "http://localhost:5601/api/index_patterns/index_pattern/kong-api-logs/_fields_for_wildcard" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" > /dev/null 2>&1

echo "✅ Index pattern rafraîchi"
echo ""
echo "📊 Derniers logs /local-echo avec X-Forwarded-For:"
echo ""

# Afficher les derniers logs
curl -s 'http://localhost:9200/kong-api-logs/_search?size=5&sort=started_at:desc&q=request.uri:local-echo' | \
  jq -r '.hits.hits[]._source | "[\(.started_at | todate)] \(.request.method) \(.request.uri) - XFF: \(.request.headers["x-forwarded-for"]) - Status: \(.response.status) - Client IP: \(.client_ip)"'

echo ""
echo "🌐 Accès Kibana: http://localhost:5601"
echo ""
echo "📋 Pour voir dans Kibana:"
echo "1. Menu ☰ → Analytics → Discover"
echo "2. Sélectionner 'Kong API Logs'"
echo "3. Filtrer: request.uri : \"/local-echo\""
echo "4. Ajouter colonne: request.headers.x-forwarded-for"
