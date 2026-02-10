# Deck Configuration - APIOps

This folder contains Kong declarative configuration files for services, routes, and plugins.

## Usage

```bash
# Sync to Konnect
deck gateway sync kong.yaml \
  --konnect-control-plane-name nginx-poc-dp \
  --konnect-token-file ~/.konnect/pat \
  --konnect-addr https://eu.api.konghq.com

# Dump current config
deck gateway dump \
  --konnect-control-plane-name nginx-poc-dp \
  --konnect-token-file ~/.konnect/pat \
  --konnect-addr https://eu.api.konghq.com
```
