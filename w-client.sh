#!/bin/bash

# WireGuard server config path
WG_CONF="/etc/wireguard/wg0.conf"
WG_INTERFACE="wg0"
CLIENT_IP_BASE="10.0.0."
START_IP=2

# Replace with your server's public IP or domain and WireGuard port
SERVER_ENDPOINT="your-server-ip-or-domain:51820"

if [ $# -ne 1 ]; then
  echo "Usage: $0 client-name"
  exit 1
fi

CLIENT_NAME=$1

# Generate client private and public keys
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

# Find used IPs from AllowedIPs in server config
USED_IPS=$(grep "AllowedIPs" "$WG_CONF" | awk '{print $3}' | cut -d'/' -f1)

# Find the next available IP in the subnet
NEXT_IP=""
for i in $(seq $START_IP 254); do
  IP="${CLIENT_IP_BASE}${i}"
  if ! grep -q "$IP" <<< "$USED_IPS"; then
    NEXT_IP=$IP
    break
  fi
done

if [ -z "$NEXT_IP" ]; then
  echo "No available IP addresses left in the subnet."
  exit 1
fi

# Add the new client peer to server config
echo -e "\n[Peer]\n# $CLIENT_NAME\nPublicKey = $CLIENT_PUBLIC_KEY\nAllowedIPs = $NEXT_IP/32" >> "$WG_CONF"

# Reload WireGuard configuration
wg syncconf "$WG_INTERFACE" <(wg-quick strip "$WG_INTERFACE")

# Get server public key for client config
SERVER_PUBLIC_KEY=$(wg show "$WG_INTERFACE" public-key)

# Create client config file
cat > "${CLIENT_NAME}.conf" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $NEXT_IP/32
DNS = 8.8.8.8

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_ENDPOINT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

echo "Client configuration created: ${CLIENT_NAME}.conf"
