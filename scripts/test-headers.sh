#!/bin/bash
# Test script for IP Preservation POC
# Usage: ./test-headers.sh

echo "=========================================="
echo "  POC: Nginx + Kong IP Preservation Test  "
echo "=========================================="
echo ""
echo "Environment:"
echo "  - Nginx NodePort: 30919"
echo "  - Kong Proxy: localhost:80"
echo "  - Echo Server: local-echo route"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Test 1: Direct to Kong (bypassing Nginx) ==="
RESULT1=$(curl -s http://localhost:80/local-echo 2>/dev/null)
XFF1=$(echo $RESULT1 | jq -r '.request.headers["x-forwarded-for"] // "NOT SET"')
XRI1=$(echo $RESULT1 | jq -r '.request.headers["x-real-ip"] // "NOT SET"')
echo -e "  X-Forwarded-For: ${YELLOW}$XFF1${NC}"
echo -e "  X-Real-IP:       ${YELLOW}$XRI1${NC}"
echo ""

echo "=== Test 2: Through Nginx (localhost:30919) ==="
RESULT2=$(curl -s http://localhost:30919/local-echo 2>/dev/null)
XFF2=$(echo $RESULT2 | jq -r '.request.headers["x-forwarded-for"] // "NOT SET"')
XRI2=$(echo $RESULT2 | jq -r '.request.headers["x-real-ip"] // "NOT SET"')
echo -e "  X-Forwarded-For: ${GREEN}$XFF2${NC}"
echo -e "  X-Real-IP:       ${GREEN}$XRI2${NC}"
echo ""

echo "=== Analysis ==="
if [[ "$XFF2" != "NOT SET" && "$XRI2" != "NOT SET" ]]; then
    echo -e "${GREEN}✓ SUCCESS: IP headers are preserved through Nginx → Kong chain${NC}"
    echo ""
    echo "The X-Forwarded-For header contains:"
    echo "  - First IP: Client/Docker host IP"
    echo "  - Second IP: Nginx pod IP"
    echo ""
    echo "Kong configuration applied:"
    echo "  - trusted_ips: 0.0.0.0/0,::/0"
    echo "  - real_ip_header: X-Forwarded-For"
    echo "  - real_ip_recursive: on"
else
    echo -e "${RED}✗ FAILED: IP headers not found${NC}"
fi

echo ""
echo "=== Full headers (through Nginx) ==="
echo $RESULT2 | jq '.request.headers'
