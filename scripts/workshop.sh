#!/bin/bash

set -euo pipefail

CONFIG="workshop.yaml"
REBUILD=""
VALID_ARGS=$(getopt -o '' --long rebuild -- "$@")

_get_vps_ip () {
  local vps_name="$1"
  hcloud server describe -o json "$vps_name" | jq -r .public_net.ipv4.ip
}

_update_config () {
  local username="$1"
  local key="$2"
  local value="$3"
  yq -i "(.users[] | select (.username == \"$username\")) .$key = \"$value\"" workshop.yaml
}

_setup_vps () {
  local vps_name="$1"
  local user_yaml="$2"
  local username name ssh_public_key ip_key ip
  username="$(echo "$user_yaml" | yq .username)"
  name="$(echo "$user_yaml" | yq .name)"
  ssh_public_key="$(echo "$user_yaml" | yq .sshPublicKey)"
  if ip="$(_get_vps_ip "$vps_name")"; then
    if [ -n "$REBUILD" ]; then
      echo "rebuilding $vps_name ($ip)"
      hcloud server rebuild "$vps_name" --image ubuntu-22.04
      echo "waiting for server"
      sleep 20
      bash ./k8s.sh "$ip" "$username" "$name" "$ssh_public_key"
    else
      echo "WARNING: VPS \"$vps_name\" already exists, use --rebuild to rebuild it." >&2
    fi
  else
    echo "creating server $vps_name"
    hcloud server create --datacenter hel1-dc2 --image ubuntu-22.04 --name "$vps_name" --ssh-key bogdan --type cpx21
    if [[ $vps_name =~ -cp- ]]; then
      echo "creating volume $vps_name"
      hcloud volume create --name "$vps_name" --server "$vps_name" --size 10
    fi
    echo "waiting for server"
    sleep 20
    ip="$(_get_vps_ip "$vps_name")"
    bash ./k8s.sh "$ip" "$username" "$name" "$ssh_public_key"
  fi
  if [[ $vps_name =~ -cp- ]]; then
    ip_key="cpIp"
  else
    ip_key="nodeIp"
  fi
  _update_config "$username" "$ip_key" "$ip"
}

# echo "$VALID_ARGS"

eval set -- "$VALID_ARGS"
while true; do
  # echo "arg: $1"
  case "$1" in
    --rebuild)
      REBUILD="1"
      ;;
    --)
      shift
      break
  esac
  shift
done

NODE_TYPE=""

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 USERNAME [NODE_TYPE] [--rebuild]" >&2
  echo "  NODE_TYPE: cp, node"
  exit 1
fi

USERNAME="$1"

if [ $# -eq 2 ]; then
  NODE_TYPE="$2"
  if [ "$NODE_TYPE" != cp ] && [ "$NODE_TYPE" != node ]; then
    echo "ERROR: Invalid node type \"$NODE_TYPE\"." >&2
    exit 1
  fi
fi

echo "DEBUG: username: $USERNAME"
echo "DEBUG: node type: $NODE_TYPE"
echo -n "DEBUG: rebuild: "
if [ -n "$REBUILD" ]; then echo "yes"; else echo "no"; fi

if ! USER="$(yq -e "(.users[] | select (.username == \"$USERNAME\" ))" "$CONFIG" 2>/dev/null)"; then
  echo "ERROR: User \"$USERNAME\" does not exist." >&2
  exit 1
fi

# echo "user: $USER"

if [ -n "$NODE_TYPE" ]; then
  _setup_vps "$USERNAME-$NODE_TYPE-0" "$USER"
else
  _setup_vps "$USERNAME-cp-0" "$USER" &
  _setup_vps "$USERNAME-node-0" "$USER"
  wait
fi
