#!/bin/bash

# Port-forward check
nc -z localhost 8000
if [ $? -ne 0 ]; then
    echo "Error: Kong Proxy port 8000 is not accessible. Make sure port-forward is running."
    exit 1
fi

URL="http://localhost:8000/geo-test"
COUNT=${1:-20}

echo "Sending $COUNT requests to $URL..."
echo "Expected behavior: Load balancing between backend-eu and backend-us"

EU_COUNT=0
US_COUNT=0

# Loop
for i in $(seq 1 $COUNT); do
  # Detailed curl to debugging
  RESPONSE=$(curl -s -m 2 $URL)
  
  # Check if jq is installed
  if ! command -v jq &> /dev/null; then
      echo "jq could not be found, just printing response:"
      echo "$RESPONSE"
      exit 1
  fi

  # Parse hostname
  HOSTNAME=$(echo "$RESPONSE" | jq -r '.environment.HOSTNAME')
  
  if [[ "$HOSTNAME" == *"backend-eu"* ]]; then
    EU_COUNT=$((EU_COUNT+1))
    echo "Request $i: 🇪🇺 EU Region ($HOSTNAME)"
  elif [[ "$HOSTNAME" == *"backend-us"* ]]; then
    US_COUNT=$((US_COUNT+1))
    echo "🇺🇸 US Region ($HOSTNAME)"
  else
    echo "Request $i: ❓ UNKNOWN ($HOSTNAME)"
  fi
  
  sleep 0.1
done

echo "--------------------------------"
echo "Traffic Distribution Results:"
echo "🇪🇺 EU Requests: $EU_COUNT"
echo "🇺🇸 US Requests: $US_COUNT"
echo "--------------------------------"

if [ $EU_COUNT -gt 0 ] && [ $US_COUNT -gt 0 ]; then
    echo "✅ SUCCESS: Traffic is being distributed between regions."
else
    echo "❌ FAILURE: Traffic is NOT distributed properly (Check Upstream config)."
fi
