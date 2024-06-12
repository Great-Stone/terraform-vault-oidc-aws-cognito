#!/bin/sh

# env.sh
cat <<EOF
{
  "address": "$VAULT_ADDR",
  "namespace": "$VAULT_NAMESPACE",
  "token": "$VAULT_TOKEN"
}
EOF