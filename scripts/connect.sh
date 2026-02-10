#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔌 Establishing connections to Kong and Nginx...${NC}"

# Kill existing port-forwards to avoid conflicts
pkill -f "kubectl port-forward svc/kong-dp-kong-proxy" || true
pkill -f "kubectl port-forward svc/nginx" || true

# Start Kong Proxy port-forward in background
echo -e "${GREEN}Starting Kong Proxy (port 8000)...${NC}"
kubectl port-forward svc/kong-dp-kong-proxy -n kong 8000:80 > /dev/null 2>&1 &
PID_KONG=$!

# Start Nginx port-forward in background
echo -e "${GREEN}Starting Nginx (port 8080)...${NC}"
kubectl port-forward svc/nginx -n kong 8080:80 > /dev/null 2>&1 &
PID_NGINX=$!

echo -e "${BLUE}✅ Connected!${NC}"
echo -e "   - Kong Proxy: http://localhost:8000"
echo -e "   - Nginx:      http://localhost:8080"
echo -e ""
echo -e "⚠️  Keep this terminal open, or run this script in a separate terminal to keep connections alive."
echo -e "Press CTRL+C to stop."

# Wait for user to exit
wait $PID_KONG $PID_NGINX
