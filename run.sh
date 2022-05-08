# Copyright (c) 2021 Tailscale Inc & AUTHORS All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.
#
# based on https://github.com/tailscale/tailscale/blob/main/docs/k8s/subnet.yaml
# adjusted to work with F5XC vk8s and blindfold

#! /bin/sh

export PATH=$PATH:/tailscale/bin

BLINDFOLD="${BLINDFOLD:-}"
AUTH_KEY="${AUTH_KEY:-}"
ROUTES="${ROUTES:-}"
DEST_IP="${DEST_IP:-}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
USERSPACE="${USERSPACE:-true}"

if [ ! -z "$BLINDFOLD" ]; then
  echo "decrypting blindfold $BLINDFOLD ..."
  cat > /tmp/authkey.json <<EOF
{
  "type": "blindfold",
  "location": "string:///$BLINDFOLD"
}
EOF
  until [ -s /tmp/authkey ]; do
    sleep 5
    curl -f -XPOST http://localhost:8070/secret/unseal -d @/tmp/authkey.json | base64 -d > /tmp/authkey
  done
  AUTH_KEY=$(cat /tmp/authkey)
  echo "blindfold decrypt successful, AUTH_KEY set"
fi
set -e

TAILSCALED_ARGS="--state=/tmp/tailscaled.state --socket=/tmp/tailscaled.sock"

if [[ "${USERSPACE}" == "true" ]]; then
  if [[ ! -z "${DEST_IP}" ]]; then
    echo "IP forwarding is not supported in userspace mode"
    exit 1
  fi
  TAILSCALED_ARGS="${TAILSCALED_ARGS} --tun=userspace-networking"
else
  if [[ ! -d /dev/net ]]; then
    mkdir -p /dev/net
  fi

  if [[ ! -c /dev/net/tun ]]; then
    mknod /dev/net/tun c 10 200
  fi
fi

echo "Starting tailscaled"
tailscaled ${TAILSCALED_ARGS} &
PID=$!

UP_ARGS="--accept-dns=false"
if [[ ! -z "${ROUTES}" ]]; then
  UP_ARGS="--advertise-routes=${ROUTES} ${UP_ARGS}"
fi
if [[ ! -z "${AUTH_KEY}" ]]; then
  UP_ARGS="--authkey=${AUTH_KEY} ${UP_ARGS}"
fi
if [[ ! -z "${EXTRA_ARGS}" ]]; then
  UP_ARGS="${UP_ARGS} ${EXTRA_ARGS:-}"
fi
if [ ! -z "$VES_IO_SITENAME" ]; then
  UP_ARGS="${UP_ARGS} --hostname=${VES_IO_SITENAME}"
  echo "Setting tailscale hostname to ${VES_IO_SITENAME}" 
fi

echo "Running tailscale up"
tailscale --socket=/tmp/tailscaled.sock up ${UP_ARGS}

if [[ ! -z "${DEST_IP}" ]]; then
  echo "Adding iptables rule for DNAT"
  iptables -t nat -I PREROUTING -d "$(tailscale --socket=/tmp/tailscaled.sock ip -4)" -j DNAT --to-destination "${DEST_IP}"
fi

wait ${PID}
