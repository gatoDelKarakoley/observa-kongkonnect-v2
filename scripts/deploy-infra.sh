#!/bin/bash
# Script de déploiement de l'infrastructure Kong + Nginx + Echo Server
# Usage: ./scripts/deploy-infra.sh

set -e

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}🚀 Démarrage du déploiement de l'infrastructure...${NC}"

# 1. Namespaces
echo "📦 Création des namespaces..."
kubectl create namespace kong --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -

# 2. Kong Data Plane (Helm)
echo "🦍 Installation de Kong Data Plane..."
if ! helm repo list | grep -q "kong"; then
  helm repo add kong https://charts.konghq.com
  helm repo update
fi

helm upgrade --install kong-dp kong/kong -n kong -f kong-dp/values.yaml \
  --set ingressController.installCRDs=false

# 3. Nginx Reverse Proxy
echo "🚦 Déploiement de Nginx..."
kubectl apply -f k8s/nginx/

# 4. Echo Server (Backend)
echo "🔊 Déploiement du Echo Server..."
kubectl apply -f k8s/echo-server/

# 5. Multi-Region Backends
echo "🌍 Déploiement des backends multi-régions..."
kubectl apply -f k8s/backends/

# 6. Kong Status Service (pour Prometheus)
echo "📊 Déploiement du Service Kong Status..."
kubectl apply -f k8s/kong-status-service.yaml

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Déploiement terminé !${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📌 Prochaines étapes :"
echo "   1. Attendez que les pods soient 'Running' :"
echo "      kubectl get pods -n kong -w"
echo "   2. Configurez Kong :"
echo "      deck gateway sync deck/kong.yaml --select-tag=poc-observability"
echo "   3. Vérifiez l'infra :"
echo "      ./scripts/check-infra.sh"
echo ""
