# Make terraform variables file
sudo tee wireguard/terraform.tfvars <<EOF
aws_region = "$AWS_REGION"
aws_access_key = "$AWS_ACCESS_KEY"
aws_secret_access_key = "$AWS_SECRET_ACCESS_KEY"
project_name = "$PROJECT_NAME"
cluster_uuid = "$CLUSTER_UUID"
ssh_rsa_public = "$(cat $HOME/ssh.pub)"
EOF

# Generate keys
wg genkey | sudo tee /etc/wireguard/privatekey
sudo cat /etc/wireguard/privatekey | wg pubkey | sudo tee /etc/wireguard/publickey

# export TF_VAR_master_public_key="$(sudo cat /etc/wireguard/publickey)"
sudo tee -a $SCRIPT_DIR/wireguard/terraform.tfvars <<EOF
master_public_key = "$(sudo cat /etc/wireguard/publickey)"
EOF

# WireGuard terraforming
cd $SCRIPT_DIR/wireguard
terraform init
terraform apply --auto-approve

# Get WireGuard VPN Hub public IP
HUB_IP=$(terraform output -raw wireguard_eip_public_ip)

# Get WireGuard VPN Hub public key
sudo aws s3 cp s3://$PROJECT_NAME-$CLUSTER_UUID/hub/publickey $HOME/hub-publickey
HUB_PUBLIC_KEY=$(cat $HOME/hub-publickey)

# Make wg0.conf file for master node
sudo tee /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $(sudo cat /etc/wireguard/privatekey)
Address = 10.10.0.2/32

[Peer]
PublicKey = ${HUB_PUBLIC_KEY}
Endpoint = ${HUB_IP}:51820
AllowedIPs = 10.10.0.1/32, 10.10.0.0/24, 172.31.0.0/16, 10.42.0.0/16
PersistentKeepalive = 25
EOF

# Set master node's hostname
NODE_HOSTNAME=$CLUSTER_NAME
sudo hostnamectl set-hostname $NODE_HOSTNAME

if ! grep -q "10.10.0.2    $NODE_HOSTNAME" /etc/hosts; then
  echo "Adding $NODE_HOSTNAME to /etc/hosts..."
  echo "10.10.0.2    $NODE_HOSTNAME" | sudo tee -a /etc/hosts
else
  echo "/etc/hosts already contains $NODE_HOSTNAME"
fi

# Enable WireGuard
sudo systemctl restart wg-quick@wg0
sudo systemctl enable --now wg-quick@wg0
echo "Waiting for WireGuard connection (60s)"
sudo wg show
