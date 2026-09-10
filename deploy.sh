#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}K3s on Proxmox Deployment Script${NC}"
echo -e "${GREEN}================================${NC}"

# Check if terraform.tfvars exists
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo -e "${RED}Error: terraform/terraform.tfvars not found!${NC}"
    echo "Please copy terraform/terraform.tfvars.example to terraform/terraform.tfvars and fill in your values"
    exit 1
fi

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${YELLOW}Ansible not found. Installing...${NC}"
    sudo apt update
    sudo apt install -y ansible
fi

# Step 1: Initialize Terraform
echo -e "\n${GREEN}Step 1: Initializing Terraform...${NC}"
cd terraform
terraform init

# Step 2: Validate configuration
echo -e "\n${GREEN}Step 2: Validating Terraform configuration...${NC}"
terraform validate

# Step 3: Plan deployment
echo -e "\n${GREEN}Step 3: Planning deployment...${NC}"
terraform plan

# Ask for confirmation
echo -e "\n${YELLOW}Do you want to proceed with the deployment? (yes/no)${NC}"
read -r response
if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${RED}Deployment cancelled.${NC}"
    exit 0
fi

# Step 4: Apply Terraform
echo -e "\n${GREEN}Step 4: Creating VMs with Terraform...${NC}"
terraform apply -auto-approve

# Get the K3s token
echo -e "\n${GREEN}Step 5: Retrieving K3s token...${NC}"
K3S_TOKEN=$(terraform output -raw k3s_token)
export K3S_TOKEN
echo "K3s Token: ${K3S_TOKEN}"

# Wait for VMs to be ready
echo -e "\n${GREEN}Step 6: Waiting for VMs to boot (60 seconds)...${NC}"
sleep 60

# Test SSH connectivity
echo -e "\n${GREEN}Step 7: Testing SSH connectivity...${NC}"
CONTROL_PLANE_IP=$(terraform output -json control_plane_ips | jq -r '.[0]')
CONTROL_PLANE_IPS_JSON=$(terraform output -json control_plane_ips)
WORKER_IPS_JSON=$(terraform output -json worker_ips)
MEDIA_NFS_IPS_JSON=$(terraform output -json media_nfs_ips)
K3S_VERSION=$(terraform output -raw k3s_version)
VM_SSH_USER=$(terraform output -raw vm_ssh_username)
echo "Testing connection to ${CONTROL_PLANE_IP}..."
cd ..

retries=0
max_retries=30

until ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 "${VM_SSH_USER}@${CONTROL_PLANE_IP}" "echo 'SSH OK'" &> /dev/null; do
    retries=$((retries+1))
    if [ $retries -ge $max_retries ]; then
        echo -e "${RED}Failed to connect via SSH after ${max_retries} attempts${NC}"
        echo "Tried key-based SSH as ${VM_SSH_USER}@${CONTROL_PLANE_IP}"
        exit 1
    fi
    echo "Waiting for SSH... (attempt $retries/$max_retries)"
    sleep 10
done

echo -e "${GREEN}SSH connectivity confirmed!${NC}"

echo -e "\n${GREEN}Waiting for SSH on all provisioned VMs...${NC}"
ALL_NODE_IPS_JSON=$(jq -n \
    --argjson control_planes "${CONTROL_PLANE_IPS_JSON}" \
    --argjson workers "${WORKER_IPS_JSON}" \
    --argjson media_nfs "${MEDIA_NFS_IPS_JSON}" \
    '$control_planes + $workers + $media_nfs')

for node_ip in $(echo "${ALL_NODE_IPS_JSON}" | jq -r '.[]'); do
    echo "Testing connection to ${node_ip}..."
    retries=0
    until ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 "${VM_SSH_USER}@${node_ip}" "echo 'SSH OK'" &> /dev/null; do
        retries=$((retries+1))
        if [ $retries -ge $max_retries ]; then
            echo -e "${RED}Failed to connect via SSH after ${max_retries} attempts${NC}"
            echo "Tried key-based SSH as ${VM_SSH_USER}@${node_ip}"
            exit 1
        fi
        echo "Waiting for SSH on ${node_ip}... (attempt $retries/$max_retries)"
        sleep 10
    done
done

echo -e "${GREEN}SSH connectivity confirmed for all provisioned VMs!${NC}"

# Generate Ansible inventory from Terraform outputs
echo -e "\n${GREEN}Generating Ansible inventory from Terraform outputs...${NC}"
INVENTORY_FILE="ansible/inventory.yml"
{
    echo "all:"
    echo "  vars:"
    echo "    ansible_user: ${VM_SSH_USER}"
    echo "    ansible_ssh_common_args: -o StrictHostKeyChecking=no"
    echo "    k3s_version: ${K3S_VERSION}"
    echo ""
    echo "k3s_cluster:"
    echo "  children:"
    echo "    control_plane:"
    echo "      hosts:"
    echo "${CONTROL_PLANE_IPS_JSON}" | jq -r 'to_entries[] | "        k3s-cp-\(.key + 1):\n          ansible_host: \(.value)"'
    echo ""
    echo "    workers:"
    echo "      hosts:"
    echo "${WORKER_IPS_JSON}" | jq -r 'to_entries[] | "        k3s-worker-\(.key + 1):\n          ansible_host: \(.value)"'
    if [ "$(echo "${MEDIA_NFS_IPS_JSON}" | jq 'length')" -gt 0 ]; then
        echo ""
        echo "media:"
        echo "  children:"
        echo "    media_nfs:"
        echo "      hosts:"
        echo "${MEDIA_NFS_IPS_JSON}" | jq -r 'to_entries[] | "        media-nfs-\(.key + 1):\n          ansible_host: \(.value)"'
    fi
} > "${INVENTORY_FILE}"

# Step 8: Install system utilities using Ansible
echo -e "\n${GREEN}Step 8: Installing system utilities with Ansible...${NC}"
cd ansible
ansible-playbook -i inventory.yml system-utils-install.yml
cd ..

# Step 9: Configure media NFS server if enabled
if [ "$(echo "${MEDIA_NFS_IPS_JSON}" | jq 'length')" -gt 0 ]; then
    echo -e "\n${GREEN}Step 9: Configuring media NFS server with Ansible...${NC}"
    cd ansible
    ansible-playbook -i inventory.yml media-nfs-install.yml
    cd ..
fi

# Step 10: Install K3s using Ansible
echo -e "\n${GREEN}Step 10: Installing K3s cluster with Ansible...${NC}"
cd ansible
ansible-playbook -i inventory.yml k3s-install.yml
cd ..

# Step 11: Optional ArgoCD installation
echo -e "\n${YELLOW}Do you want to install ArgoCD? (yes/no)${NC}"
read -r response
if [[ "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "\n${GREEN}Step 11: Installing ArgoCD with Ansible...${NC}"
    cd ansible
    ansible-playbook -i inventory.yml argocd-install.yml
    cd ..
fi

# Step 12: Display cluster info
echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}================================${NC}"

echo -e "\n${GREEN}Cluster Information:${NC}"
cd terraform
terraform output cluster_info
PROJECT_DIR=$(cd .. && pwd)
KUBECONFIG_PATH="${PROJECT_DIR}/kubeconfig"

echo -e "\n${GREEN}To access your cluster:${NC}"
echo "1. Export kubeconfig:"
echo -e "   ${YELLOW}export KUBECONFIG=${KUBECONFIG_PATH}${NC}"
echo ""
echo "2. Test cluster access:"
echo -e "   ${YELLOW}kubectl get nodes${NC}"
echo ""
echo "3. SSH to control plane:"
echo -e "   ${YELLOW}$(terraform output -raw ssh_command_control_plane)${NC}"
cd ..
echo ""
if [[ "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "\n${GREEN}ArgoCD Information:${NC}"
    echo "To access ArgoCD UI directly:"
    echo -e "   ${YELLOW}http://${CONTROL_PLANE_IP}:30080${NC}"
    echo ""
    echo "Or via port-forward:"
    echo -e "   ${YELLOW}KUBECONFIG=${KUBECONFIG_PATH} kubectl port-forward svc/argocd-server -n argocd 8080:80${NC}"
    echo "Username: admin"
    ARGOCD_PASSWORD=$(KUBECONFIG="${KUBECONFIG_PATH}" kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
    if [ -n "$ARGOCD_PASSWORD" ]; then
        echo "Password: ${ARGOCD_PASSWORD}"
    else
        echo "Password: unable to read automatically"
        echo -e "   ${YELLOW}KUBECONFIG=${KUBECONFIG_PATH} kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d${NC}"
    fi
fi
echo ""
echo -e "${GREEN}Kubeconfig saved to: ${KUBECONFIG_PATH}${NC}"
