#!/bin/bash
set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /home/ubuntu/wireguard-setup.log
}

log "Starting WireGuard hub setup..."

# Variables
WIREGUARD_HUB_IP="${wireguard_hub_ip}"
MASTER_PUBLIC_KEY="${master_public_key}"
MASTER_WIREGUARD_IP="${master_wireguard_ip}"
MASTER_INTERNAL_CIDR="${master_internal_cidr}"
PROJECT_NAME="${project_name}"
AWS_ACCESS_KEY="${aws_access_key}"
AWS_SECRET_ACCESS_KEY="${aws_secret_access_key}"

# System update and Install WireGuard
apt-get update
apt-get install -y wireguard unzip

# AWS CLI Installation
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# IP Forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
sysctl -p

# WireGuard Key
cd /etc/wireguard
umask 077
wg genkey | tee privatekey | wg pubkey > publickey

PRIVATE_KEY=$(cat /etc/wireguard/privatekey)
PUBLIC_KEY=$(cat /etc/wireguard/publickey)

# Find default network interface
PRIMARY_IFACE=$(ip -o -4 route show to default | awk '{print $5}')

# WireGuard setting file
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = $${WIREGUARD_HUB_IP}/24
ListenPort = 51820
PrivateKey = $${PRIVATE_KEY}
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -A FORWARD -o wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o $${PRIMARY_IFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -D FORWARD -o wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o $${PRIMARY_IFACE} -j MASQUERADE

# On-premise master node
[Peer]
PublicKey = $${MASTER_PUBLIC_KEY}
AllowedIPs = $${MASTER_WIREGUARD_IP}/32, $${MASTER_INTERNAL_CIDR}
PersistentKeepalive = 25

# Spot instance workers will be added later
EOF

# WireGuard start and enable auto start
systemctl start wg-quick@wg0
systemctl enable wg-quick@wg0

# Get AWS region
export AWS_ACCESS_KEY_ID=$${AWS_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=$${AWS_SECRET_ACCESS_KEY}
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $${TOKEN}" http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')

# Store keys in AWS SSM Parameter Store
aws ssm put-parameter \
    --name "/${project_name}/wireguard/hub-private-key" \
    --value "$${PRIVATE_KEY}" \
    --type "SecureString" \
    --overwrite \
    --region $${AWS_REGION}

aws ssm put-parameter \
    --name "/${project_name}/wireguard/hub-public-key" \
    --value "$${PUBLIC_KEY}" \
    --type "String" \
    --overwrite \
    --region $${AWS_REGION}

# Logging
log "WireGuard hub setup completed"
log "Public key: $${PUBLIC_KEY}"
log "Hub IP: $${WIREGUARD_HUB_IP}/24"

# Save report
cat > /home/ubuntu/wireguard-keys.txt << EOF
=== WireGuard Hub Keys ===
Server Public Key: $(cat /etc/wireguard/publickey)
Server Private Key: $(cat /etc/wireguard/privatekey)

=== Configuration for Master Node ===
[Peer]
PublicKey = $(cat /etc/wireguard/publickey)
Endpoint = $(curl -s http://checkip.amazonaws.com/):51820
AllowedIPs = 10.10.0.0/24, 172.31.0.0/16
PersistentKeepalive = 25
EOF

chown ubuntu:ubuntu /home/ubuntu/wireguard-keys.txt

# Completion
log "WireGuard hub setup completed!"
log "Keys saved to /home/ubuntu/wireguard-keys.txt"