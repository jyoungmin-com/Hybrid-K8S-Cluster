# VARIABLES
echo "Enter Project Name:"
read project
export PROJECT_NAME=$project

echo "Enter AWS REGION:"
read region
export AWS_REGION=$region

echo "Enter AWS Access Key:"
read accesskey
export AWS_ACCESS_KEY=$accesskey

echo "Enter AWS Secret Access Key:"
read secretkey
export AWS_SECRET_ACCESS_KEY=$secretkey

echo "NEW EC2 Key Pair Name:"
read keypair

#--------------------------------------------------------------------------------

# Set variables

# UUID
cat /proc/sys/kernel/random/uuid | awk -F- '{print $1}' >$HOME/master_uuid.txt
export CLUSTER_UUID=$(cat $HOME/master_uuid.txt)


# Others
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CLUSTER_NAME=$(hostname)

#--------------------------------------------------------------------------------

# FORMULAS

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

#--------------------------------------------------------------------------------

print_line "Hybrid K8S Cluster - $PROJECT_NAME($CLUSTER_NAME, $CLUSTER_UUID)"

#--------------------------------------------------------------------------------

# Insllation
source ./script/installation.sh

#--------------------------------------------------------------------------------

# AWS CLI & S3
source $SCRIPT_DIR/scripts/awscli.sh

# WireGuard
source $SCRIPT_DIR/scripts/wireguard.sh

# Linux kernel, Swap, Network, Containerd
source $SCRIPT_DIR/scripts/linux.sh

# Kubernetes
source $SCRIPT_DIR/scripts/k8s.sh

# Karpenter
source $SCRIPT_DIR/scripts/karpenter.sh