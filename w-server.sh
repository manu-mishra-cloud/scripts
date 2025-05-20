#!/bin/bash

# Auto-detect the public network interface connected to the default route
PUBLIC_IF=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}' | head -1)

# Default variables - you can still customize these if you want, but no manual update required for PUBLIC_IF
WG_INTERFACE="wg0"
WG_PORT=51820
WG_SUBNET="10.0.0.0/24"
SERVER_IP="10.0.0.1"
DNS="8.8.8.8"

echo "Detected public interface: $PUBLIC_IF"

echo "Installing WireGuard..."
sudo apt update
sudo apt install -y wireguard

sudo mkdir -p /etc/wireguard
sudo chmod 700 /etc/wireguard

echo "Generating WireGuard keys..."
SERVER_PRIVATE_KEY=$(wg genkey)
SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)

sudo tee /etc/wireguard/server_private.key >/dev/null <<< "$SERVER_PRIVATE_KEY"
sudo tee /etc/wireguard/server_public.key >/dev/null <<< "$SERVER_PUBLIC_KEY"

echo "Creating WireGuard config..."
sudo tee /etc/wireguard/${WG_INTERFACE}.conf >/dev/null <<EOF
[Interface]
Address = ${SERVER_IP}/24
ListenPort = ${WG_PORT}
PrivateKey = $SERVER_PRIVATE_KEY
EOF

echo "Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1

# Persist IP forwarding after reboot
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
fi
if ! grep -q "net.ipv6.conf.all.forwarding=1" /etc/sysctl.conf; then
  echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf
fi

echo "Setting up firewall rules..."
sudo iptables -A FORWARD -i ${WG_INTERFACE} -j ACCEPT
sudo iptables -A FORWARD -o ${WG_INTERFACE} -j ACCEPT
sudo iptables -t nat -A POSTROUTING -s ${WG_SUBNET} -o ${PUBLIC_IF} -j MASQUERADE

# Save iptables rules to persist after reboot
sudo apt install -y iptables-persistent
sudo netfilter-persistent save

echo "Starting WireGuard interface..."
sudo wg-quick up ${WG_INTERFACE}
sudo systemctl enable wg-quick@${WG_INTERFACE}

echo "WireGuard server public key:"
echo "$SERVER_PUBLIC_KEY"

echo "Setup complete! Server VPN IP: $SERVER_IP, Port: $WG_PORT"
