#!/bin/bash

URL="http://localhost:8000/geo-test"

echo "🧪 Starting Circuit Breaker Test..."
echo "---"
echo "traffic is initially 80% EU / 20% US."
echo "We will crash EU backend and watch traffic shift to US."
echo "---"

# Function to send requests loop
send_requests() {
  for i in {1..50}; do
    RESPONSE=$(curl -s -m 1 $URL)
    
    # Extract hostname to verify origin
    if [[ "$RESPONSE" == *"backend-eu"* ]]; then
      echo -e "Request $i: 🇪🇺 EU Region (Healthy)"
    elif [[ "$RESPONSE" == *"backend-us"* ]]; then
      echo -e "Request $i: 🇺🇸 US Region (Failover)"
    else
      echo -e "Request $i: ❌ Error / Timeout"
    fi
    sleep 0.5
  done
}

# Start sending requests in background
echo "🚀 Traffic started..."
send_requests &
PID_TRAFFIC=$!

# Wait a few seconds then crash EU
sleep 5
echo ""
echo "💥 SIMULATING FAILURE: Stopping backend-eu..."
kubectl scale deployment backend-eu -n kong --replicas=0
echo "Waiting for Circuit Breaker to trip..."

# Wait for failover visibility
sleep 15

# Recover
echo ""
echo "🚑 RECOVERING: Starting backend-eu..."
kubectl scale deployment backend-eu -n kong --replicas=1
echo "Waiting for Active Health Check to recover..."

# Wait for recovery visibility
wait $PID_TRAFFIC

echo ""
echo "✅ Test Complete."
