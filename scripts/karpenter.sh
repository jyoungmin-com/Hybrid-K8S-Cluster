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

print_line "COMPLETED - Karpenter Configuration & Installation"

#--------------------

print_line "STARTING - Karpenter Spot Instance NodePool & EC2NodeClass Applying"


sudo tee $HOME/spot-nodepool.yaml <<EOF
# spot-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: spot-nodepool
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r", "t"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        - key: karpenter.k8s.aws/instance-size
          operator: NotIn
          values: ["nano", "micro", "small"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: spot-nodeclass
      taints:
        - key: "karpenter.sh/capacity-type"
          value: "spot"
          effect: "NoSchedule"
  limits:
    cpu: 1000
    memory: 1000Gi
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s
    expireAfter: 720h
EOF

cat <<EOF | envsubst | sudo tee $HOME/karpenter-nodeclass.yaml
# spot-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: spot-nodeclass
spec:
  role: "KarpenterNodeRole-hybrid-cluster"
  amiSelectorTerms:
    - alias: "al2023@latest"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "hybrid-cluster"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "hybrid-cluster"
  instanceStorePolicy: "RAID0"
  userData: |
    #!/bin/bash
    # Configure WireGuard on worker nodes

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
    
    
    wg genkey | sudo tee /etc/wireguard/privatekey
    sudo cat /etc/wireguard/privatekey | wg pubkey | sudo tee /etc/wireguard/publickey
    


    # WireGuard configuration
    cat <<EOF > /etc/wireguard/wg0.conf
    [Interface]
    Address = 10.10.0.20/24
    PrivateKey = <WORKER_PRIVATE_KEY>
    DNS = 10.10.0.1
    
    [Peer]
    PublicKey = <MASTER_PUBLIC_KEY>
    AllowedIPs = 10.10.0.0/24, 10.42.0.0/16, 10.96.0.0/12, 192.168.0.0/24
    Endpoint = <MASTER_PUBLIC_IP>:51820
    PersistentKeepalive = 25
    EOF
    
    # Enable WireGuard
    systemctl enable --now wg-quick@wg0
    
    # Bootstrap Kubernetes
    /etc/eks/bootstrap.sh hybrid-cluster \
      --apiserver-endpoint https://10.10.0.1:6443 \
      --b64-cluster-ca <BASE64_ENCODED_CA>
  blockDeviceMappings:
    - deviceName: /dev/sda1
      ebs:
        volumeSize: 20Gi
        volumeType: gp3
        deleteOnTermination: true
  metadataOptions:
    httpEndpoint: enabled
    httpProtocolIPv6: disabled
    httpPutResponseHopLimit: 2
    httpTokens: required
  tags:
    Environment: "hybrid"
    ManagedBy: "karpenter"
EOF