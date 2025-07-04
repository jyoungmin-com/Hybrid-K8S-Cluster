# Hybrid-K8S-Cluster

Cost-optimized hybrid Kubernetes cluster with on-premises master node and AWS Spot instance worker nodes connected via WireGuard VPN

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                 Hybrid K8S Cluster                              │
├─────────────────────────────────────────┬───────────────────────────────────────┤
│               On-Premises               │                AWS Cloud              │
│             (192.168.0.0/24)            │             (172.31.0.0/16)           │
│                                         │                                       │
│  ┌──────────────────────────────────┐   │   ┌─────────────────────────────────┐ │
│  │           Master Node            │   │   │           WireGuard Hub         │ │
│  │         192.168.0.200/24         │◄──┼──►│           10.10.0.1/24          │ │
│  │        WG IP: 10.10.0.2/24       │   │   │          (EC2 Instance)         │ │
│  └──────────────────────────────────┘   │   └─────────────────────────────────┘ │
│                                         │                   ▲                   │
│                                         │                   │                   │
│                                         │                   ▼                   │
│                                         │   ┌─────────────────────────────────┐ │
│                                         │   │      Spot Instance Workers      │ │
│                                         │   │   WG IPs: 10.10.0.20-100/24     │ │
│                                         │   │   (Auto-scaled by Karpenter)    │ │
│                                         │   └─────────────────────────────────┘ │
└─────────────────────────────────────────┴───────────────────────────────────────┘

Network Segments:
├── On-premises: 192.168.0.0/24
│   └── Master node: 192.168.0.200
├── WireGuard VPN: 10.10.0.0/24
│   ├── VPN Hub: 10.10.0.1
│   ├── Master: 10.10.0.2
│   └── Workers: 10.10.0.20-100
├── AWS VPC: 172.31.0.0/16 (public subnets only)
│   └── Subnets: 172.31.1.0/24, 172.31.2.0/24, 172.31.3.0/24
└── Kubernetes Networks:
    ├── Pod CIDR: 10.42.0.0/16 (cluster-wide pods)
    └── Service CIDR: 10.96.0.0/12 (cluster services)
```

## Cost Benefits

- **Cost savings**
  - **No EKS cluster fees**
  - **No NAT Gateway fees**
- **Spot instance pricing**
- **Self-managed infrastructure**

## Prerequisites

- **On-premises server** with Ubuntu 24.04
- **AWS Account**
- **Internet connectivity** for both on-premises and AWS components

## Network Planning

```bash
# Network segmentation strategy
Home Network:     192.168.0.0/24
WireGuard VPN:    10.10.0.0/24      (secure tunnel)
Kubernetes Pods:  10.42.0.0/16      (cluster-wide pods)
Services:         10.96.0.0/12      (cluster services)
AWS VPC:          172.31.0.0/16     (public subnets)
```

**IP Address Allocation:**
- **Master Node**: 192.168.0.200 + 10.10.0.2 (VPN)
- **WireGuard Hub**: 10.10.0.1 (AWS EC2 instance)
- **Spot Workers**: 10.10.0.20-100 (dynamic allocation)
- **AWS Subnets**: 172.31.1.0/24, 172.31.2.0/24, 172.31.3.0/24

## How To Start

### 1. Master Node Setup
```bash
# Run the complete setup script
chmod +x master-setup.sh
./master-setup.sh

# The script will prompt for:
# - AWS Region
# - AWS Access Key
# - AWS Secret Access Key  
# - Cluster Name

# Script automatically handles:
# System preparation (swap, kernel modules)
# Container runtime installation (containerd)
# Kubernetes installation (kubeadm, kubectl, kubelet)
# Cluster initialization
# Calico CNI deployment
# WireGuard VPN setup with key generation (for on-premise master node only)
# Helm installation
```

### 2. Get Master Node WireGuard Public Key
```bash
# After master setup completes, get the public key
sudo cat /etc/wireguard/publickey
# Copy this key for terraform configuration
```

### 3. Deploy AWS Infrastructure
```bash
cd wireguard

# Deploy infrastructure
terraform init
terraform plan
terraform apply --auto-approve
```

### 4. Connect Master to AWS VPN Hub
```bash
# Get AWS WireGuard hub public IP from terraform output
terraform output wireguard_eip_public_ip

# Update master WireGuard configuration with hub details
```


## To-Do

1. **Karpenter Configuration** 

2. **Spot Instance Auto-Join**

3. **IAM Roles Setup**

4. **VPN Hub Integration**

5. **Testing & Validation**

6. **Documentation & Cleanup**

## Files Structure
```
├── master-setup.sh              # Complete master node automation
├── wireguard/
│   ├── provisioner.tf
│   ├── variables.tf             # All terraform variables
│   ├── outputs.tf               # Important outputs (VPN IP, etc.)
│   ├── ec2.tf                   # WireGuard Hub instance
│   ├── network.tf               # Network configuration (VPC, Subnet, etc.)
│   └── script/
│       └── setup.sh             # WireGuard hub setup script
│
└── README.md                    # This file
```

### Completed & Working
- [x] **Kubernetes 1.33 installation** - kubeadm, kubectl, kubelet
- [x] **Calico CNI configuration** - Pod network with custom CIDR
- [x] **AWS infrastructure** - Terraform automation for VPC, subnets, security groups
- [x] **Helm integration** - Automated package management
- [x] **AWS CLI integration** - Automated setup and configuration

### Not Working Yet
- [ ] **Karpenter & Spot instance provisioning**
- [ ] **WireGuard setup & Spot instance auto-join**
- [ ] **IAM roles for Karpenter**


## Technical Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| Kubernetes | 1.33 | Container orchestration |
| Karpenter | 1.5.1 | Node auto-scaling |
| Calico | 3.30.2 | Network policy and CNI |
| WireGuard | Latest | VPN connectivity |
| Terraform | 5.0+ | Infrastructure as Code |
| containerd | Latest | Container runtime |
| Helm | 3.x | Package manager |
| AWS CLI | 2.x | AWS integration |

## Network Configuration

| Network Segment | CIDR | Specific IPs | Purpose |
|-----------------|------|--------------|---------|
| On-premises | 192.168.0.0/24 | Master: 192.168.0.200 | Existing network |
| WireGuard VPN | 10.10.0.0/24 | Hub: 10.10.0.1<br>Master: 10.10.0.2<br>Workers: 10.10.0.20-100 | Secure tunnel network |
| Kubernetes Pods | 10.42.0.0/16 | Dynamic allocation | Cluster pod network |
| Kubernetes Services | 10.96.0.0/12 | Dynamic allocation | Service discovery |
| AWS VPC | 172.31.0.0/16 | Subnets: 172.31.1.0/24<br>172.31.2.0/24<br>172.31.3.0/24 | Cloud infrastructure |

## What the Setup Script Does

**master-setup.sh includes:**
- **Interactive prompts** for AWS credentials and cluster configuration
- **System preparation** (swap, kernel modules, sysctl parameters)
- **Container runtime** setup with proper cgroup configuration
- **Kubernetes 1.33** installation and cluster initialization
- **Cluster initialization** with proper network CIDRs:
  - API server: 192.168.0.200:6443
  - Pod network: 10.42.0.0/16
  - Service network: 10.96.0.0/12
- **Calico CNI** deployment with VXLANCrossSubnet encapsulation
- **WireGuard VPN** setup with automatic key generation:
  - Master VPN IP: 10.10.0.2/24
  - Listening port: 51820
  - NAT masquerading configured
- **Helm installation** for package management
- **Karpenter installation**
- **AWS CLI** setup and configuration

**Single command setup:** `./master-setup.sh`


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.