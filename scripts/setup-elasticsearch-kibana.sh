#!/bin/bash

# Script to setup Elasticsearch indices and Kibana index patterns
# This ensures proper mapping and avoids VALUE_NULL errors in Kibana

set -e

ELASTICSEARCH_URL="${ELASTICSEARCH_URL:-http://localhost:9200}"
KIBANA_URL="${KIBANA_URL:-http://localhost:5601}"

echo "🔧 Elasticsearch & Kibana Setup Script"
echo "========================================"
echo ""
echo "Elasticsearch: $ELASTICSEARCH_URL"
echo "Kibana: $KIBANA_URL"
echo ""

# Function to wait for Elasticsearch
wait_for_elasticsearch() {
    echo "⏳ Waiting for Elasticsearch to be ready..."
    until curl -s "$ELASTICSEARCH_URL/_cluster/health" > /dev/null 2>&1; do
        echo "   Elasticsearch not ready yet, waiting..."
        sleep 2
    done
    echo "✅ Elasticsearch is ready"
}

# Function to wait for Kibana
wait_for_kibana() {
    echo "⏳ Waiting for Kibana to be ready..."
    until curl -s "$KIBANA_URL/api/status" > /dev/null 2>&1; do
        echo "   Kibana not ready yet, waiting..."
        sleep 2
    done
    echo "✅ Kibana is ready"
}

# Function to create Elasticsearch index with proper mapping
create_elasticsearch_index() {
    local index_name=$1
    
    echo ""
    echo "📊 Creating index: $index_name"
    
    # Delete existing index if it exists
    curl -s -X DELETE "$ELASTICSEARCH_URL/$index_name" > /dev/null 2>&1 || true
    
    # Create index with proper mapping
    curl -s -X PUT "$ELASTICSEARCH_URL/$index_name" \
        -H 'Content-Type: application/json' \
        -d '{
            "settings": {
                "number_of_shards": 1,
                "number_of_replicas": 1,
                "index.mapping.total_fields.limit": 2000
            },
            "mappings": {
                "properties": {
                    "started_at": {"type": "date"},
                    "client_ip": {"type": "ip"},
                    "request": {
                        "properties": {
                            "method": {"type": "keyword"},
                            "uri": {"type": "keyword"},
                            "url": {"type": "keyword"},
                            "size": {"type": "long"},
                            "querystring": {"type": "object", "enabled": true},
                            "headers": {"type": "object", "enabled": true}
                        }
                    },
                    "response": {
                        "properties": {
                            "status": {"type": "integer"},
                            "size": {"type": "long"},
                            "headers": {"type": "object", "enabled": true}
                        }
                    },
                    "upstream": {
                        "properties": {
                            "url_extended": {"type": "keyword"},
                            "request": {
                                "properties": {
                                    "body": {"type": "text"}
                                }
                            },
                            "response": {
                                "properties": {
                                    "body": {"type": "text"},
                                    "status": {"type": "integer"}
                                }
                            }
                        }
                    },
                    "latencies": {
                        "properties": {
                            "kong": {"type": "long"},
                            "proxy": {"type": "long"},
                            "request": {"type": "long"}
                        }
                    },
                    "service": {
                        "properties": {
                            "id": {"type": "keyword"},
                            "name": {"type": "keyword"}
                        }
                    },
                    "route": {
                        "properties": {
                            "id": {"type": "keyword"},
                            "name": {"type": "keyword"}
                        }
                    },
                    "workspace": {"type": "keyword"},
                    "workspace_name": {"type": "keyword"}
                }
            }
        }' | jq -r 'if .acknowledged then "✅ Index created successfully" else "❌ Failed to create index: " + .error.reason end'
}

# Function to create Kibana index pattern
create_kibana_index_pattern() {
    local pattern_name=$1
    local index_pattern=$2
    local time_field=$3
    
    echo ""
    echo "📋 Creating Kibana index pattern: $pattern_name"
    
    curl -s -X POST "$KIBANA_URL/api/saved_objects/index-pattern" \
        -H "kbn-xsrf: true" \
        -H "Content-Type: application/json" \
        -d "{
            \"attributes\": {
                \"title\": \"$index_pattern\",
                \"timeFieldName\": \"$time_field\"
            }
        }" | jq -r 'if .id then "✅ Index pattern created: " + .id else "⚠️  Index pattern may already exist" end'
}

# Main execution
echo ""
echo "🚀 Starting setup..."
echo ""

wait_for_elasticsearch
wait_for_kibana

# Create Elasticsearch indices
create_elasticsearch_index "kong-api-logs"
create_elasticsearch_index "kong-logs"

# Create Kibana index patterns
create_kibana_index_pattern "Kong API Logs" "kong-api-logs*" "started_at"
create_kibana_index_pattern "Kong System Logs" "kong-logs*" "time"

echo ""
echo "✅ Setup completed successfully!"
echo ""
echo "📊 Access Kibana: $KIBANA_URL"
echo ""
echo "Next steps:"
echo "1. Open Kibana in your browser"
echo "2. Go to Analytics → Discover"
echo "3. Select 'Kong API Logs' index pattern"
echo "4. Start exploring your Kong logs!"
echo ""
