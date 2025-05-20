#!/bin/bash

# Variables for client and server
CLIENT_NAME="android"
CLIENT_PRIVATE_KEY="oIihVTq+6ApXPZgTn8UIFekXNymznn/bwrtkIm1V72w="
CLIENT_IP="10.0.0.3/24"
DNS_SERVER="8.8.8.8"
SERVER_PUBLIC_KEY="n3uXywfarOm2Wq/9e4B4Mgb8LPSC+GCZt7HW6I7RJUI="
SERVER_ENDPOINT="3.82.125.16:51820"
WG_CONF="/etc/wireguard/wg0.conf"
WG_INTERFACE="wg0"

# Install WireGuard if not installed
if ! command -v wg > /dev/null; then
    echo "Installing WireGuard..."
    sudo apt update
    sudo apt install -y wireguard
else
    echo "WireGuard is already installed."
fi

# Make sure wg0.conf exists
if [ ! -f "$WG_CONF" ]; then
    echo "[Interface]" | sudo tee "$WG_CONF"
    echo "Address = 10.0.0.1/24" | sudo tee -a "$WG_CONF"
    echo "ListenPort = 51820" | sudo tee -a "$WG_CONF"
    echo "PrivateKey = +IcGcTh4b4oN1MMOaiOxPH34tJfXmTsOgLlJ0ywkAmU=" | sudo tee -a "$WG_CONF"
fi

# Derive client public key from private key
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

# Check if peer already exists in config
if grep -q "$CLIENT_PUBLIC_KEY" "$WG_CONF"; then
    echo "Client peer already exists in server config."
else
    echo -e "\n[Peer]\n# $CLIENT_NAME\nPublicKey = $CLIENT_PUBLIC_KEY\nAllowedIPs = ${CLIENT_IP%/*}/32" | sudo tee -a "$WG_CONF"
    echo "Added client peer to server config."
fi

# Reload WireGuard config on server
sudo wg syncconf "$WG_INTERFACE" <(sudo wg-quick strip "$WG_INTERFACE")
echo "WireGuard configuration reloaded."

# Create client config file locally
cat > "${CLIENT_NAME}.conf" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP
DNS = $DNS_SERVER

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0
Endpoint = $SERVER_ENDPOINT
PersistentKeepalive = 25
EOF

echo "Client config file '${CLIENT_NAME}.conf' created."
