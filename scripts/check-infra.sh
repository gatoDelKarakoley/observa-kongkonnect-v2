#!/bin/bash
# Script de vérification de l'infrastructure Kong + Nginx
# Usage: ./scripts/check-infra.sh

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Vérification de l'infrastructure Kong & Nginx..."
echo ""

# 1. Kong
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🦍 KONG DATA PLANE (Namespace: kong)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get pods -n kong --no-headers | while read line; do
  name=$(echo $line | awk '{print $1}')
  ready=$(echo $line | awk '{print $2}')
  status=$(echo $line | awk '{print $3}')
  if [ "$status" = "Running" ]; then
    echo -e "${GREEN}✅ $name - $status ($ready)${NC}"
  else
    echo -e "${RED}❌ $name - $status ($ready)${NC}"
  fi
done

# Vérifier service proxy
proxy_ip=$(kubectl get svc -n kong kong-dp-kong-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
echo -e "   🌐 Proxy External IP: $proxy_ip"

echo ""

# 2. Nginx
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚦 NGINX INGRESS (Namespace: kong)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get pods -n kong -l app=nginx --no-headers | while read line; do
  name=$(echo $line | awk '{print $1}')
  status=$(echo $line | awk '{print $3}')
  if [ "$status" = "Running" ]; then
    echo -e "${GREEN}✅ $name - $status${NC}"
  else
    echo -e "${RED}❌ $name - $status${NC}"
  fi
done

echo ""

# 3. Echo Server
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔊 ECHO SERVER (Namespace: kong)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get pods -n kong -l app=echo-server --no-headers | while read line; do
  name=$(echo $line | awk '{print $1}')
  status=$(echo $line | awk '{print $3}')
  if [ "$status" = "Running" ]; then
    echo -e "${GREEN}✅ $name - $status${NC}"
  else
    echo -e "${RED}❌ $name - $status${NC}"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔗 ACCES A L'INFRA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   - Kong Proxy:     http://localhost:8000"
echo "   - Kong Admin:     http://localhost:8001"
echo "   - Nginx Proxy:    http://localhost:8080 (Frontal)"
echo ""
