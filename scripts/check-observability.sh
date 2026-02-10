#!/bin/bash
# Script de vérification et démarrage de la stack observabilité Kong
# Usage: ./scripts/check-observability.sh

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Vérification de la stack d'observabilité Kong..."
echo ""

# 1. Vérifier les pods
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 PODS OBSERVABILITY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get pods -n observability --no-headers | while read line; do
  name=$(echo $line | awk '{print $1}')
  ready=$(echo $line | awk '{print $2}')
  status=$(echo $line | awk '{print $3}')
  if [ "$status" = "Running" ]; then
    echo -e "${GREEN}✅ $name - $status${NC}"
  else
    echo -e "${RED}❌ $name - $status${NC}"
  fi
done

echo ""
kubectl get pods -n logging --no-headers 2>/dev/null | while read line; do
  name=$(echo $line | awk '{print $1}')
  status=$(echo $line | awk '{print $3}')
  if [ "$status" = "Running" ]; then
    echo -e "${GREEN}✅ $name (logging) - $status${NC}"
  else
    echo -e "${RED}❌ $name (logging) - $status${NC}"
  fi
done

# 2. Vérifier les services
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 SERVICES (URLs d'accès)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}Grafana${NC}:     http://localhost:30300"
echo -e "${YELLOW}Kibana${NC}:      http://localhost:30561"
echo -e "${YELLOW}Prometheus${NC}:  http://localhost:30090"

# 3. Générer du trafic
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Génération de trafic test..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for i in {1..20}; do 
  curl -s http://localhost:30919/flights > /dev/null 2>&1
  echo -n "."
done
echo ""
echo -e "${GREEN}✅ 20 requêtes envoyées${NC}"

# 4. Vérifier Elasticsearch
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 ELASTICSEARCH - Index"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Port-forward en background
pkill -f "port-forward.*elasticsearch" 2>/dev/null || true
kubectl port-forward svc/elasticsearch 9200:9200 -n observability &>/dev/null &
sleep 3

indices=$(curl -s "http://localhost:9200/_cat/indices?h=index,docs.count" 2>/dev/null | grep -v "^\." || echo "")
if [ -n "$indices" ]; then
  echo "$indices" | while read idx count; do
    echo -e "${GREEN}✅ $idx - $count documents${NC}"
  done
else
  echo -e "${YELLOW}⚠️  Pas encore d'index (attendre quelques secondes)${NC}"
fi

# 5. Créer les Data Views Kibana si nécessaire
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 KIBANA - Data Views"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

pkill -f "port-forward.*kibana.*5601" 2>/dev/null || true
kubectl port-forward svc/kibana 5601:5601 -n observability &>/dev/null &
sleep 3

# Tester si Kibana répond
kibana_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5601/api/status" 2>/dev/null)
if [ "$kibana_status" = "200" ]; then
  echo -e "${GREEN}✅ Kibana accessible${NC}"
  
  # 1. Kong API Logs (http-log plugin - logs détaillés)
  curl -s -X POST "http://localhost:5601/api/data_views/data_view" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d '{"data_view":{"title":"kong-api-logs*","name":"Kong API Logs"}}' > /dev/null 2>&1
  echo -e "${GREEN}✅ Data View 'Kong API Logs' créé/existant${NC}"
  
  # 2. Kong System Logs (Fluent Bit - logs stdout)
  curl -s -X POST "http://localhost:5601/api/data_views/data_view" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d '{"data_view":{"title":"kong-logs*","name":"Kong System Logs","timeFieldName":"@timestamp"}}' > /dev/null 2>&1
  echo -e "${GREEN}✅ Data View 'Kong System Logs' créé/existant${NC}"
  
  # 3. Kong Traces (OpenTelemetry)
  curl -s -X POST "http://localhost:5601/api/data_views/data_view" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d '{"data_view":{"title":"traces-kong*","name":"Kong Traces"}}' > /dev/null 2>&1
  echo -e "${GREEN}✅ Data View 'Kong Traces' créé/existant${NC}"
else
  echo -e "${RED}❌ Kibana ne répond pas (status: $kibana_status)${NC}"
  echo -e "${YELLOW}   Conseil: Redémarrer les pods Elasticsearch et Kibana${NC}"
fi



# 6. Vérifier Prometheus
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📈 PROMETHEUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
prom_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:30090/-/healthy" 2>/dev/null)
if [ "$prom_status" = "200" ]; then
  echo -e "${GREEN}✅ Prometheus accessible${NC}"
else
  echo -e "${YELLOW}⚠️  Prometheus status: $prom_status${NC}"
fi

# 7. Vérifier Grafana
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 GRAFANA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
grafana_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:30300/api/health" 2>/dev/null)
if [ "$grafana_status" = "200" ]; then
  echo -e "${GREEN}✅ Grafana accessible${NC}"
else
  echo -e "${YELLOW}⚠️  Grafana status: $grafana_status${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Vérification terminée !"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📌 Accès rapides:"
echo "   - Grafana:    http://localhost:30300 (admin/admin)"
echo "   - Kibana:     http://localhost:30561"
echo "   - Prometheus: http://localhost:30090"
