#!/usr/bin/env bash
# Create Kubernetes secret

secret_name=$1
key=$2
value=$3

if [ -z "$secret_name" ] || [ -z "$key" ] || [ -z "$value" ]; then
  echo "Usage: $0 <secret-name> <key> <value>"
  exit 1
fi

kubectl create secret generic $secret_name --from-literal=$key=$value -n ics