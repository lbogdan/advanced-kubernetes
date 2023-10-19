#!/bin/bash

set -euo pipefail

# for user in "$(yq -I 0 -o json .users[] workshop.yaml)"; do
#   echo "user: $user"
# done

_ssh_config () {
  local username="$1"
  local type="$2"
  local ip="$3"
  cat <<EOT
Host $username-$type-0
  HostName $ip
  User $username
  Port 33133
EOT
}

while IFS= read -r user
do
  # echo "user: $user"
  if USERNAME="$(echo "$user" | yq -e .username 2>/dev/null)"; then
    # echo "username: $USERNAME"
    if CP_IP="$(echo "$user" | yq -e .cpIp 2>/dev/null)"; then
      # echo "cpIp: $CP_IP"
      _ssh_config "$USERNAME" cp "$CP_IP"
    fi
    if NODE_IP="$(echo "$user" | yq -e .nodeIp 2>/dev/null)"; then
      # echo "nodeIp: $NODE_IP"
      _ssh_config "$USERNAME" node "$NODE_IP"
    fi
  fi
done < <(yq -I 0 -o json .users[] workshop.yaml)
