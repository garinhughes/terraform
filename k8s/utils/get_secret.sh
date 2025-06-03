#!/usr/bin/env bash
# Get secret from Kubernetes secret

secret_name=$1
if [ -z "$secret_name" ]; then
  echo "Usage: $0 <secret-name>"
  exit 1
fi

kubectl get secret $secret_name -n ics -o jsonpath="{.data.redis-password}" | base64 --decode