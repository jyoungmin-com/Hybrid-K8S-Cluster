# Configure K8S
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

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
CA_CERT_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt |
    openssl rsa -pubin -outform der 2>/dev/null |
    openssl dgst -sha256 -hex | sed 's/^.* //')
JOIN_COMMAND="kubeadm join 10.10.0.2:6443 --token $TOKEN --discovery-token-ca-cert-hash sha256:$CA_CERT_HASH"

aws s3 cp $TOKEN s3://$PROJECT_NAME-$CLUSTER_UUID/kubernetes/bootstrap-token
aws s3 cp sha256:$CA_CERT_HASH s3://$PROJECT_NAME-$CLUSTER_UUID/kubernetes/ca-cert-hash
aws s3 cp $JOIN_COMMAND s3://$PROJECT_NAME-$CLUSTER_UUID/kubernetes/join-command

# Calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/operator-crds.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/tigera-operator.yaml

# Make custon resoureces
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
