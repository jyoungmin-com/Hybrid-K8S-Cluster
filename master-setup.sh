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

echo "Enter Cluster Name:"
read clustername
CLUSTER_NAME=$clustername

PWD=$(pwd)

#--------------------

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


#--------------------

# Install Terraform

wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform


#--------------------

# WireGuard Prerequisite
cd wireguard
terraform init
terraform apply --auto-approve


#--------------------

# DISABLE SWAP

sudo swapoff -a
sudo sed -i '/ swap / s/^(.*)$/#\1/g' /etc/fstab


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


#--------------------

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


#--------------------

# Add Kubernetes repository

curl -fsSL [https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key](https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key) | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] [https://pkgs.k8s.io/core:/stable:/v1.33/deb/](https://pkgs.k8s.io/core:/stable:/v1.33/deb/) /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes components

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet


#--------------------

# Initialize cluster with specific configuration - this will be reset

sudo kubeadm init 
--pod-network-cidr=10.42.0.0/16 
--service-cidr=10.96.0.0/12 
--apiserver-advertise-address=192.168.0.200 
--node-name=master-temp

# Configure kubectl

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


#--------------------

# Install Tigera operator

kubectl create -f [https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/operator-crds.yaml](https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/operator-crds.yaml)
kubectl create -f [https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/tigera-operator.yaml](https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/tigera-operator.yaml)

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
encapsulation: VXLANCrossSubnet
natOutgoing: Enabled
nodeSelector: all()
EOF


#--------------------

# WireGuard Installation

sudo apt-get install -y wireguard

# Generate keys

wg genkey | sudo tee /etc/wireguard/privatekey
sudo cat /etc/wireguard/privatekey | wg pubkey | sudo tee /etc/wireguard/publickey

# Configure WireGuard

sudo tee /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $(sudo cat /etc/wireguard/privatekey)
Address = 10.10.0.2/32

[Peer]
PublicKey = <HUB_PUBLIC_KEY>
Endpoint = <HUB_ENDPOINT_IP>:51820
AllowedIPs = 10.10.0.1/32
PersistentKeepalive = 25
EOF

# Enable WireGuard

sudo systemctl enable --now wg-quick@wg0


#--------------------

# Helm Installation

curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm


#--------------------

# Karpenter Setting


export AWS_REGION
export CLUSTER_NAME

cat <<EOF | envsubst | sudo tee $HOME/karpenter-values.yaml
# karpenter-values.yaml
settings:
  clusterName: "$CLUSTER_NAME"
  clusterEndpoint: "https://$(ip -o -4 route show to default | awk '{print $9}'):6443"
  interruptionQueue: ""
  awsDefaultRegion: "$AWS_REGION"
controller:
  resources:
    requests:
      cpu: 1
      memory: 1Gi
    limits:
      cpu: 1
      memory: 1Gi
  topologySpreadConstraints: []
  nodeSelector:
    kubernetes.io/os: linux
  tolerations:
    - key: "CriticalAddonsOnly"
      operator: "Exists"
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
    - key: "node-role.kubernetes.io/master"
      operator: "Exists"
      effect: "NoSchedule"
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

helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter 
--version "1.5.1" 
--namespace kube-system 
--create-namespace 
--values karpenter-values.yaml
--wait


# WireGuard VPN Setup
cd $PWD/wireguard
HUB_IP=$(terraform output -raw wireguard_eip_public_ip)
HUB_PUBLIC_KEY=$(aws ssm get-parameter --name /h8s/wireguard/hub-public-key --with-decryption --query Parameter.Value --output text)
sudo tee /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.10.0.2/24
PrivateKey = $(sudo cat /etc/wireguard/privatekey)
DNS = 10.10.0.1

[Peer]
PublicKey = ${HUB_PUBLIC_KEY}
Endpoint = ${HUB_IP}:51820
AllowedIPs = 10.10.0.0/24, 172.31.0.0/16, 10.42.0.0/16
PersistentKeepalive = 25
EOF

sudo systemctl restart wg-quick@wg0