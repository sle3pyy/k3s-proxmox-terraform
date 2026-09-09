#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}K3s Proxmox Setup Script${NC}"
echo -e "${GREEN}================================${NC}"

# Create directory structure
echo -e "\n${GREEN}Creating directory structure...${NC}"
mkdir -p ansible terraform

# Create files
echo -e "${GREEN}Creating configuration files...${NC}"

# Copy tfvars example to actual file if it doesn't exist
if [ ! -f "terraform/terraform.tfvars" ]; then
    cp terraform/terraform.tfvars.example terraform/terraform.tfvars
    echo -e "${YELLOW}Created terraform/terraform.tfvars - Please edit it with your token secret!${NC}"
else
    echo -e "${YELLOW}terraform/terraform.tfvars already exists${NC}"
fi

# Make scripts executable
chmod +x deploy.sh 2>/dev/null || true
chmod +x setup.sh 2>/dev/null || true

# Check prerequisites
echo -e "\n${GREEN}Checking prerequisites...${NC}"
PROXMOX_API_URL=$(sed -n 's/^[[:space:]]*proxmox_api_url[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' terraform/terraform.tfvars | head -n 1)
PROXMOX_API_TOKEN_ID=$(sed -n 's/^[[:space:]]*proxmox_api_token_id[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' terraform/terraform.tfvars | head -n 1)
PROXMOX_API_TOKEN_SECRET=$(sed -n 's/^[[:space:]]*proxmox_api_token_secret[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' terraform/terraform.tfvars | head -n 1)
SSH_PUBLIC_KEY_VALUE=$(sed -n 's/^[[:space:]]*ssh_public_key[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' terraform/terraform.tfvars | head -n 1)
PROXMOX_NODE=$(sed -n 's/^[[:space:]]*proxmox_node[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' terraform/terraform.tfvars | head -n 1)

# Check Terraform
if command -v terraform &> /dev/null; then
    echo -e "${GREEN}✓ Terraform installed: $(terraform version -json | jq -r '.terraform_version')${NC}"
else
    echo -e "${YELLOW}✗ Terraform not found. Installing...${NC}"
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install terraform -y
fi

# Check Ansible
if command -v ansible &> /dev/null; then
    echo -e "${GREEN}✓ Ansible installed: $(ansible --version | head -n1)${NC}"
else
    echo -e "${YELLOW}✗ Ansible not found (will be installed during deployment)${NC}"
fi

# Check jq
if command -v jq &> /dev/null; then
    echo -e "${GREEN}✓ jq installed${NC}"
else
    echo -e "${YELLOW}✗ jq not found. Installing...${NC}"
    sudo apt update && sudo apt install jq -y
fi

# Check SSH key
if [ -n "$SSH_PUBLIC_KEY_VALUE" ]; then
    echo -e "${GREEN}✓ SSH public key configured in terraform/terraform.tfvars${NC}"
elif [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    echo -e "${YELLOW}○ SSH public key exists locally but is not configured in terraform/terraform.tfvars${NC}"
    echo "  Add this to ssh_public_key if you want key-based SSH:"
    echo "  $(cat "$HOME/.ssh/id_ed25519.pub")"
else
    echo -e "${YELLOW}✗ No SSH public key configured${NC}"
    echo "  Generate one with: ssh-keygen -t ed25519 -C 'k3s-cluster'"
fi

# Test Proxmox connectivity
echo -e "\n${GREEN}Testing Proxmox connectivity...${NC}"
PVE_HOST=$(printf '%s\n' "$PROXMOX_API_URL" | sed -n 's#^https\?://\([^:/]*\).*#\1#p')
PROXMOX_VERSION_URL="${PROXMOX_API_URL%/}/version"
PROXMOX_NODE_URL="${PROXMOX_API_URL%/}/nodes/${PROXMOX_NODE}/status"
PROXMOX_UI_URL=$(printf '%s\n' "$PROXMOX_API_URL" | sed -n 's#^\(https\?://[^/]*\).*#\1/#p')

if [ -z "$PVE_HOST" ] || [ "$PVE_HOST" = "YOUR_PROXMOX_HOST_OR_IP" ] || [ "$PVE_HOST" = "<YOUR_PROXMOX_HOST>" ]; then
    echo -e "${YELLOW}✗ Proxmox host is not configured in terraform/terraform.tfvars${NC}"
    echo "  Set proxmox_api_url to: https://YOUR_PROXMOX_HOST_OR_IP:8006/api2/json"
elif [ -z "$PROXMOX_API_TOKEN_SECRET" ] || [ "$PROXMOX_API_TOKEN_SECRET" = "YOUR_TOKEN_SECRET_HERE" ]; then
    if curl -kfsS --connect-timeout 5 "$PROXMOX_UI_URL" > /dev/null; then
        echo -e "${YELLOW}✓ Proxmox web UI is reachable, but API token secret is not configured${NC}"
        echo "  Set proxmox_api_token_secret, then rerun setup to validate authenticated API access"
    else
        echo -e "${YELLOW}✗ Cannot reach Proxmox web UI at ${PROXMOX_UI_URL}${NC}"
        echo "  Check the host/IP, port 8006, HTTPS, and that pveproxy is running"
    fi
elif PROXMOX_VERSION_RESPONSE=$(curl -kfsS --connect-timeout 5 \
    -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN_ID}=${PROXMOX_API_TOKEN_SECRET}" \
    "$PROXMOX_VERSION_URL") && \
    printf '%s\n' "$PROXMOX_VERSION_RESPONSE" | jq -e '.data.version' > /dev/null; then
    echo -e "${GREEN}✓ Proxmox API is reachable at ${PROXMOX_VERSION_URL}${NC}"
    echo "  Version: $(printf '%s\n' "$PROXMOX_VERSION_RESPONSE" | jq -r '.data.version')"

    if curl -kfsS --connect-timeout 5 \
        -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN_ID}=${PROXMOX_API_TOKEN_SECRET}" \
        "$PROXMOX_NODE_URL" > /dev/null; then
        echo -e "${GREEN}✓ Proxmox node '${PROXMOX_NODE}' exists${NC}"
    else
        echo -e "${YELLOW}✗ Proxmox node '${PROXMOX_NODE}' was not found or is not readable${NC}"
        echo "  Set proxmox_node to the exact node name shown by: pvesh get /nodes"
    fi
else
    echo -e "${YELLOW}✗ Cannot reach Proxmox API at ${PROXMOX_VERSION_URL}${NC}"
    echo "  Check the API token, permissions, host/IP, port 8006, HTTPS, and that pveproxy is running"
    echo "  Debug with: curl -ki -H 'Authorization: PVEAPIToken=${PROXMOX_API_TOKEN_ID}=<SECRET>' ${PROXMOX_VERSION_URL}"
fi

echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Setup Summary${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Edit terraform/terraform.tfvars and add your Proxmox API token secret"
echo "   nano terraform/terraform.tfvars"
echo ""
echo "2. Review the configuration:"
echo "   cat terraform/terraform.tfvars"
echo ""
echo "3. Run the deployment:"
echo "   ./deploy.sh"
echo ""
echo -e "${GREEN}Files created:${NC}"
ls -lh ./*.sh terraform/*.tf terraform/terraform.tfvars* ansible/*.yml 2>/dev/null || true
