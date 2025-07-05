# VARIABLES
echo "Enter AWS REGION:"
read region
AWS_REGION=$region

echo "Enter AWS Access Key:"
read accesskey
AWS_ACCESS_KEY=$accesskey

echo "Enter AWS Secret Access Key:"
read secretkey
AWS_SECRET_ACCESS_KEY=$secretkey

echo "EC2 Key Pair:"
read keypair

sudo tee wireguard/terraform.tfvars <<EOF
aws_region = "$AWS_REGION"
aws_access_key = "$AWS_ACCESS_KEY"
aws_secret_access_key = "$AWS_SECRET_ACCESS_KEY"
ec2_keypair = "$keypair"
EOF

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME=$(hostname)
#--------------------

print_star() {
  local total_width=70
  printf '%*s\n' "$total_width" '' | tr ' ' '*'
}

print_line() {
  local msg="$1"
  local total_width=70
  local msg_length=${#msg}
  local padding_length=$((total_width - msg_length - 2))
  local left_padding=$((padding_length / 2))
  local right_padding=$((padding_length - left_padding))
  echo
  print_star
  printf '%s %s %s\n' "$(printf '%*s' "$left_padding" '' | tr ' ' '*')" "$msg" "$(printf '%*s' "$right_padding" '' | tr ' ' '*')"
  print_star
  echo
}

print_line_2() {
  local msg="$1"
  local total_width=70
  local msg_length=${#msg}
  local padding_length=$((total_width - msg_length - 2))
  local left_padding=$((padding_length / 2))
  local right_padding=$((padding_length - left_padding))
  printf '%s %s %s\n' "$(printf '%*s' "$left_padding" '' | tr ' ' '*')" "$msg" "$(printf '%*s' "$right_padding" '' | tr ' ' '*')"
}


print_line "STARTING"

#--------------------

print_line "STARTING - AWS CLI Installation"

# AWS Setting

sudo apt install -y unzip

# Check architecture
ARCH=$(uname -m)

if [ "$ARCH" = "aarch64" ]; then
  echo "Detected ARM64 architecture."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
elif [ "$ARCH" = "x86_64" ]; then
  echo "Detected x86_64 architecture."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# Install AWS CLI
unzip -q awscliv2.zip
sudo ./aws/install

# Clean up
rm -rf aws awscliv2.zip

aws configure set aws_access_key_id $AWS_ACCESS_KEY
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
aws configure set default.region $AWS_REGION
aws configure set default.output "json"

echo
print_star
print_line_2 "COMPLETED - AWS CLI Installation"
aws configure list
print_star
echo
#--------------------

print_line "STARTING - Terraform Installation"

# Install Terraform

wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
sudo apt update && sudo apt install -y terraform

echo
print_star
print_line_2 "COMPLETED - Terraform Installation"
print_star
echo

#--------------------

print_line "STARTING - WireGuard Installation"

# WireGuard Installation

sudo apt-get install -y wireguard

# Generate keys

wg genkey | sudo tee /etc/wireguard/privatekey
sudo cat /etc/wireguard/privatekey | wg pubkey | sudo tee /etc/wireguard/publickey

# export TF_VAR_master_public_key="$(sudo cat /etc/wireguard/publickey)"
sudo tee -a $SCRIPT_DIR/wireguard/terraform.tfvars <<EOF
master_public_key = "$(sudo cat /etc/wireguard/publickey)"
EOF

echo
print_star
print_line_2 "COMPLETED - WireGuard Installation"
echo "Master node WireGuard Public Key: $(sudo cat /etc/wireguard/publickey)"
echo "Master node WireGuard Private Key: $(sudo cat /etc/wireguard/privatekey)"
print_star
echo
#--------------------

print_line "STARTING - Terraform - WireGuard VPN Hub Initialization"

# WireGuard Prerequisite
cd $SCRIPT_DIR/wireguard
terraform init
terraform apply --auto-approve

echo
print_star
print_line_2 "COMPLETED - Terraform - WireGuard VPN Hub Initialization"
terraform output
print_star
echo

#--------------------

print_line "STARTING - Linux kernel & Swap & Network Configuration"

# DISABLE SWAP

sudo swapoff -a
sudo sed -i '/ swap /s/^/#/' /etc/fstab

# Load required kernel modules

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Configure sysctl parameters

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

print_line "COMPLETED - Linux kernel & Swap & Network Configuration"

#--------------------

print_line "STARTING - Containerd installation and configuration"

# Install containerd

sudo apt-get update
sudo apt-get install -y containerd

# Configure containerd with SystemdCgroup

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Restart containerd

sudo systemctl restart containerd
sudo systemctl enable containerd

print_line "COMPLETED - Containerd installation and configuration"

#--------------------

print_line "STARTING - Kubernetes components Installation"

# Add Kubernetes repository

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor | sudo tee /etc/apt/keyrings/kubernetes-apt-keyring.gpg >/dev/null
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes components

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

print_line "COMPLETED - Kubernetes components Installation"

#--------------------

print_line "STARTING - WireGuard Configuration"

# Configure WireGuard

# cd $PWD/wireguard
HUB_IP=$(terraform output -raw wireguard_eip_public_ip)

for i in {1..20}; do
  HUB_PUBLIC_KEY=$(aws ssm get-parameter \
    --name /h8s/wireguard/hub-public-key \
    --query Parameter.Value \
    --output text 2>/dev/null)

  if [[ -n "$HUB_PUBLIC_KEY" ]] && [[ "$HUB_PUBLIC_KEY" != "PLACEHOLDER_WILL_BE_UPDATED_BY_INSTANCE" ]]; then
    echo "WireGuard public key retrieved successfully: $HUB_PUBLIC_KEY"
    break
  fi

  echo "Waiting for WireGuard Hub public key to be updated..."
  sleep 3
done

if [[ -z "$HUB_PUBLIC_KEY" ]] || [[ "$HUB_PUBLIC_KEY" == "PLACEHOLDER_WILL_BE_UPDATED_BY_INSTANCE" ]]; then
  echo "ERROR: WireGuard Hub public key not updated after retries."
  exit 1
fi

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

# PRIMARY_IFACE=$(ip route | grep '^default' | awk '{print $5}')
# NODE_IP=$(ip -o -4 addr show $PRIMARY_IFACE | awk '{print $4}' | cut -d/ -f1)

NODE_HOSTNAME=$CLUSTER_NAME
sudo hostnamectl set-hostname $NODE_HOSTNAME

if ! grep -q "$NODE_HOSTNAME" /etc/hosts; then
  echo "Adding $NODE_HOSTNAME to /etc/hosts..."
  echo "10.10.0.2    $NODE_HOSTNAME" | sudo tee -a /etc/hosts
else
  echo "/etc/hosts already contains $NODE_HOSTNAME"
fi

# Enable WireGuard

sudo systemctl restart wg-quick@wg0
sudo systemctl enable --now wg-quick@wg0

echo
print_star
print_line_2 "COMPLETED - WireGuard Configuration"
echo
echo "AWS EC2 WireGuard VPN Hub IP: ${HUB_IP}"
echo
echo "/etc/wireguard/wg0.confwg0.conf"
sudo cat /etc/wireguard/wg0.conf
echo "Waiting for WireGuard connection (60s)"
sleep 60
sudo wg show
print_star
echo

#--------------------

print_line "STARTING - Kubernetes cluster Initialization"

# Initialize cluster with specific configuration

for i in {1..20}; do
  ip a | grep "10.10.0.2/32" && break
  echo "Waiting for WireGuard interface..."
  sleep 3
done

sudo kubeadm init \
  --pod-network-cidr=10.42.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --apiserver-advertise-address=10.10.0.2 \
  --node-name=$CLUSTER_NAME

# Configure kubectl

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

TOKEN=$(kubeadm token create)

CA_CERT_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
    openssl rsa -pubin -outform der 2>/dev/null | \
    openssl dgst -sha256 -hex | sed 's/^.* //')

aws ssm put-parameter \
    --name "/${PROJECT_NAME}/kubernetes/bootstrap-token" \
    --value "$TOKEN" \
    --type "SecureString" \
    --overwrite \
    --region ${AWS_REGION}

aws ssm put-parameter \
    --name "/${PROJECT_NAME}/kubernetes/ca-cert-hash" \
    --value "sha256:$CA_CERT_HASH" \
    --type "String" \
    --overwrite \
    --region ${AWS_REGION}

JOIN_COMMAND="kubeadm join 10.10.0.2:6443 --token $TOKEN --discovery-token-ca-cert-hash sha256:$CA_CERT_HASH"
aws ssm put-parameter \
    --name "/${PROJECT_NAME}/kubernetes/join-command" \
    --value "$JOIN_COMMAND" \
    --type "SecureString" \
    --overwrite \
    --region ${AWS_REGION}

print_line "COMPLETED - Kubernetes cluster Initialization"

#--------------------

print_line "STARTING - Calico Installation"

# Install Tigera operator

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/operator-crds.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/tigera-operator.yaml

# Create custom resources with correct CIDR

cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
      - blockSize: 26
        cidr: 10.42.0.0/16
        encapsulation: None
        natOutgoing: Enabled
        nodeSelector: all()
EOF

print_line "COMPLETED - Calico Installation"

#--------------------

print_line "STARTING - Helm Installation"

# Helm Installation

curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg >/dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

print_line "COMPLETED - Helm Installation"

#--------------------

print_line "STARTING - Karpenter Configuration & Installation"

kubectl create secret generic aws-credentials \
  --namespace kube-system \
  --from-literal=aws_access_key_id=$AWS_ACCESS_KEY \
  --from-literal=aws_secret_access_key=$AWS_SECRET_ACCESS_KEY

# Karpenter Setting

export AWS_REGION
export CLUSTER_NAME

cat <<EOF | envsubst | sudo tee $HOME/karpenter-values.yaml
# karpenter-values.yaml
settings:
  clusterName: "$CLUSTER_NAME"
  clusterEndpoint: "10.10.0.2:6443"
  interruptionQueue: ""
  awsDefaultRegion: "$AWS_REGION"
replicaCount: 1
resources:
  requests:
    cpu: 250m
    memory: 256Mi
tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"
  - key: "node-role.kubernetes.io/master"
    operator: "Exists"
    effect: "NoSchedule"
  - key: "CriticalAddonsOnly"
    operator: "Exists"
topologySpreadConstraints: []
controller:
  resources:
    requests:
      cpu: 1
      memory: 1Gi
    limits:
      cpu: 1
      memory: 1Gi
  nodeSelector:
    kubernetes.io/os: linux
  env:
    - name: AWS_REGION
      value: "$AWS_REGION"
    - name: AWS_ACCESS_KEY_ID
      valueFrom:
        secretKeyRef:
          name: aws-credentials
          key: aws_access_key_id
    - name: AWS_SECRET_ACCESS_KEY
      valueFrom:
        secretKeyRef:
          name: aws-credentials
          key: aws_secret_access_key
logging:
  level: info
metrics:
  port: 8080
serviceAccount:
  name: karpenter
  annotations: {}
webhook:
  enabled: false
EOF

# Set environment variables

export AWS_DEFAULT_REGION=$AWS_REGION
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

# Install via Helm

helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "1.5.1" \
  --namespace kube-system \
  --create-namespace \
  --values $HOME/karpenter-values.yaml \
  --wait
