#!/bin/bash
# Script pour configurer les Data Views Kibana
# Crée 3 Data Views propres pour l'observability Kong
# Usage: ./setup-kibana-views.sh

set -e

KIBANA_URL="${KIBANA_URL:-http://localhost:30561}"

echo "🔧 Configuration des Data Views Kibana..."
echo "   Kibana URL: $KIBANA_URL"

# Attendre que Kibana soit prêt
echo "⏳ Attente de Kibana..."
for i in {1..30}; do
  if curl -s "$KIBANA_URL/api/status" 2>/dev/null | grep -q "available"; then
    echo "✅ Kibana est prêt"
    break
  fi
  echo -n "."
  sleep 2
done
echo ""

# 1. Kong API Logs (http-log plugin - logs détaillés)
echo "📊 1/3 - Création 'Kong API Logs'..."
curl -s -X POST "$KIBANA_URL/api/data_views/data_view" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{"data_view":{"title":"kong-api-logs*","name":"Kong API Logs","timeFieldName":"started_at"}}' > /dev/null 2>&1
echo "   ✅ Kong API Logs (headers, body, latency)"

# 2. Kong System Logs (Fluent Bit - logs stdout)
echo "📊 2/3 - Création 'Kong System Logs'..."
curl -s -X POST "$KIBANA_URL/api/data_views/data_view" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{"data_view":{"title":"kong-logs*","name":"Kong System Logs","timeFieldName":"@timestamp"}}' > /dev/null 2>&1
echo "   ✅ Kong System Logs (logs stdout Fluent Bit)"

# 3. Kong Traces (OpenTelemetry)
echo "📊 3/3 - Création 'Kong Traces'..."
curl -s -X POST "$KIBANA_URL/api/data_views/data_view" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{"data_view":{"title":"traces-kong*","name":"Kong Traces"}}' > /dev/null 2>&1
echo "   ✅ Kong Traces (traces OpenTelemetry)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 3 Data Views créés !"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📌 Accès: $KIBANA_URL → Discover"
echo ""
echo "📊 Data Views disponibles:"
echo "   1. Kong API Logs    → Logs détaillés (headers, body, status)"
echo "   2. Kong System Logs → Logs stdout Kong (debug, erreurs)"
echo "   3. Kong Traces      → Traces distribuées"
