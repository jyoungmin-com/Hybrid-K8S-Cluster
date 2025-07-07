sudo apt update && sudo apt install -y unzip

# Check architecture
ARCH=$(uname -m)


# AWS CLIa
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

#--------------------------------------------------------------------------------

# Add Terraform repository
wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null


# Add Kubernetes repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor | sudo tee /etc/apt/keyrings/kubernetes-apt-keyring.gpg >/dev/null
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Add Helm repository
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg >/dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list



# APT Install
sudo apt update && sudo apt install -y unzip terraform wireguard containerd kubelet kubeadm kubectl helm

#--------------------------------------------------------------------------------

