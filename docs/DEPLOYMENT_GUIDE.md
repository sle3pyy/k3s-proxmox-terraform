# K3s on Proxmox - Complete Deployment Guide

## 📋 Overview

This guide will walk you through deploying a production-ready K3s Kubernetes cluster on Proxmox VE using Terraform and Ansible.

**What you'll get:**
- Proxmox VE 9.2.10 host target
- 1 Control Plane node (2 vCPU, 4GB RAM, 15GB disk)
- 3 Worker nodes (1 vCPU, 2GB RAM, 10GB disk each) - configurable
- Fully configured K3s cluster (v1.34.1+k3s1)
- Kubeconfig for local access
- Automated deployment
- Custom VM IDs starting from 500
- QEMU Guest Agent pre-installed and enabled
- Micro Editor pre-installed for quick file editing

---

## 🚀 Step-by-Step Deployment

### Step 1: Create Project Directory in WSL

Open your WSL terminal in VS Code and run:

```bash
cd ~
mkdir -p k3s-proxmox-terraform
cd k3s-proxmox-terraform
```

### Step 2: Create All Configuration Files

Copy each of the provided files into your project directory:

1. **terraform/main.tf** - Main Terraform configuration
2. **terraform/variables.tf** - Variable definitions
3. **terraform/outputs.tf** - Output definitions
4. **terraform/terraform.tfvars.example** - Example variables
5. **terraform/terraform.tfvars** - Actual variables file
6. **.gitignore** - Git ignore file
7. **README.md** - Documentation
8. **deploy.sh** - Automated deployment script
9. **setup.sh** - Setup script
10. **ansible/inventory.yml** - Ansible inventory
11. **ansible/k3s-install.yml** - K3s installation playbook
12. **ansible/system-utils-install.yml** - System utilities installation playbook
13. **ansible/argocd-install.yml** - ArgoCD installation playbook
14. **docs/pve-info-checklist-example.md** - Proxmox setup checklist template

**Quick way using VS Code:**
1. Create files in VS Code with the exact names above
2. Copy the content from each artifact I provided
3. Save all files

**Or use command line:**

```bash
# Create ansible directory
mkdir -p ansible

# Create directories
mkdir -p terraform ansible docs

# Create empty files
touch terraform/main.tf terraform/variables.tf terraform/outputs.tf terraform/terraform.tfvars.example terraform/terraform.tfvars
touch deploy.sh setup.sh README.md .gitignore
touch ansible/inventory.yml ansible/k3s-install.yml ansible/system-utils-install.yml ansible/argocd-install.yml

# Then edit each file and paste the content
```

### Step 3: Configure Your Variables

```bash
# Copy example to actual file
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Edit with your token secret
nano terraform/terraform.tfvars
```

**IMPORTANT:** Replace `YOUR_TOKEN_SECRET_HERE` with your actual Proxmox API token secret!

```hcl
proxmox_api_url          = "https://YOUR_PROXMOX_HOST_OR_IP:8006/api2/json"
proxmox_api_token_secret = "your-actual-secret-here"
```

`proxmox_api_url` is the Terraform provider base URL. It may not show useful content if opened directly in a browser. To test it manually, request:

```bash
curl -ki \
  -H 'Authorization: PVEAPIToken=root@pam!terraform=YOUR_TOKEN_SECRET_HERE' \
  https://YOUR_PROXMOX_HOST_OR_IP:8006/api2/json/version
```

For a dedicated non-root Terraform user on Proxmox VE 9.x, create a role without the removed `VM.Monitor` privilege:

```bash
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Pool.Audit Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt SDN.Use"
pveum user add terraform-prov@pve --password <password>
pveum aclmod / -user terraform-prov@pve -role TerraformProv
pveum user token add terraform-prov@pve terraform
```

**Optional:** Customize your deployment by editing other variables:

```hcl
# K3s Version
k3s_version = "v1.34.1+k3s1"

# Control Plane Configuration
control_plane_count    = 1
control_plane_cpu      = 2
control_plane_memory   = 4096
control_plane_disk_size = "15G"
vm_network_cidr = "192.168.1.0/24"
control_plane_ip_start = "192.168.1.180"

# Worker Configuration
worker_count     = 3
worker_cpu       = 1
worker_memory    = 2048
worker_disk_size = "10G"
worker_ip_start  = "192.168.1.185"

# Custom VM IDs (avoid conflicts with existing VMs)
vm_id_start = 500  # Default: 500
```

`deploy.sh` regenerates `ansible/inventory.yml` from Terraform outputs, so Terraform remains the source of truth for worker count and node IPs.

Save and exit (Ctrl+X, Y, Enter in nano)

### Step 4: Make Scripts Executable

```bash
chmod +x setup.sh deploy.sh
```

### Step 5: Run Setup Check

```bash
./setup.sh
```

This will:
- Create necessary directories
- Check prerequisites (Terraform, Ansible, jq)
- Install missing dependencies
- Verify Proxmox connectivity
- Verify SSH key exists

### Step 6: Review Configuration

```bash
# View your configuration
cat terraform/terraform.tfvars

# Ensure token secret is filled in
grep "proxmox_api_token_secret" terraform/terraform.tfvars
```

### Step 7: Deploy the Cluster! 🎉

```bash
./deploy.sh
```

The script will:
1. Initialize Terraform ⏳
2. Validate configuration ✓
3. Show deployment plan 📋
4. Ask for confirmation ❓
5. Create 4 VMs on Proxmox 🖥️
6. Wait for VMs to boot ⏱️
7. Install system utilities 🛠️
8. Install K3s cluster 🚀
9. Optional: Install ArgoCD (GitOps) ⚡
10. Save kubeconfig locally 📝

**Expected duration:** 5-10 minutes

### Step 9: Customizing Your Deployment

#### Change Worker Count

If you want to change the number of worker nodes:

1. **Update Terraform configuration:**
   ```bash
   nano terraform/terraform.tfvars
   ```
   Change `worker_count = 3` to your desired number (e.g., `worker_count = 2`)

2. **Update Ansible inventory:**
   ```bash
   nano ansible/inventory.yml
   ```
   Update the workers section to match your new worker count. For example, for 2 workers:
   ```yaml
   workers:
     hosts:
       k3s-worker-1:
         ansible_host: 192.168.1.185
       k3s-worker-2:
         ansible_host: 192.168.1.186
   ```

3. **Redeploy:**
   ```bash
   ./deploy.sh
   ```

#### Change Resource Allocation

To increase resources for better performance:

```hcl
# In terraform.tfvars
control_plane_cpu = 4
control_plane_memory = 8192
control_plane_disk_size = "30G"

worker_cpu = 2
worker_memory = 4096
worker_disk_size = "20G"
```

#### Change VM IDs

To use custom VM IDs (useful if you have existing VMs):

```hcl
# In terraform.tfvars
vm_id_start = 1000  # VMs will be 1000, 1001, 1002, etc.
```

#### Change IP Addresses

```hcl
# In terraform.tfvars
vm_network_cidr = "192.168.1.0/24"
control_plane_ip_start = "192.168.1.190"
worker_ip_start = "192.168.1.195"
```

#### Change K3s Version

```hcl
# In terraform.tfvars
k3s_version = "v1.34.1+k3s1"  # Change to any valid K3s version
```

### Step 8: Access Your Cluster

```bash
# Set kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# Verify cluster
kubectl get nodes

# Expected output:
# NAME           STATUS   ROLES                  AGE   VERSION
# k3s-cp-1       Ready    control-plane,master   2m    v1.31.3+k3s1
# k3s-worker-1   Ready    <none>                 1m    v1.31.3+k3s1
# k3s-worker-2   Ready    <none>                 1m    v1.31.3+k3s1
# k3s-worker-3   Ready    <none>                 1m    v1.31.3+k3s1

# Check all pods
kubectl get pods -A
```

---

## 🔍 Manual Deployment (Alternative)

If you prefer step-by-step control:

### 1. Initialize Terraform

```bash
cd terraform
terraform init
cd ..
```

### 2. Validate Configuration

```bash
cd terraform
terraform validate
cd ..
```

### 3. Preview Changes

```bash
cd terraform
terraform plan
cd ..
```

Review the plan carefully to ensure everything looks correct.

### 4. Create VMs

```bash
cd terraform
terraform apply
cd ..
```

Type `yes` when prompted.

### 5. Wait for VMs

```bash
# Wait for VMs to boot (about 60 seconds)
sleep 60

# Test SSH to control plane
ssh "ubuntu@$(cd terraform && terraform output -json control_plane_ips | jq -r '.[0]')" "echo 'SSH working'"
```

### 6. Get K3s Token

```bash
cd terraform
export K3S_TOKEN=$(terraform output -raw k3s_token)
cd ..
echo "K3s Token: $K3S_TOKEN"
```

### 7. Install System Utilities with Ansible

```bash
cd ansible
ansible-playbook -i inventory.yml system-utils-install.yml
cd ..
```

### 8. Install K3s with Ansible

```bash
cd ansible
ansible-playbook -i inventory.yml k3s-install.yml
cd ..
```

### 9. Optional: Install ArgoCD

```bash
cd ansible
ansible-playbook -i inventory.yml argocd-install.yml
cd ..
```

### 10. Configure Local Access

```bash
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

---

## 🧪 Testing Your Cluster

### Deploy a Test Application

```bash
# Create nginx deployment
kubectl create deployment nginx --image=nginx

# Expose as NodePort service
kubectl expose deployment nginx --port=80 --type=NodePort

# Get the NodePort
kubectl get svc nginx

# Access from your browser
# http://192.168.1.185:<NodePort>
```

### Check Cluster Health

```bash
# Node status
kubectl get nodes -o wide

# All pods
kubectl get pods -A

# Cluster info
kubectl cluster-info

# System components
kubectl get pods -n kube-system
```

---

## 🛠️ Common Operations

### SSH to Nodes

```bash
# Control plane
ssh ubuntu@192.168.1.180

# Workers
ssh ubuntu@192.168.1.185
ssh ubuntu@192.168.1.186
ssh ubuntu@192.168.1.187
```

### View K3s Logs

```bash
# On control plane
ssh ubuntu@192.168.1.180 "sudo journalctl -u k3s -f"

# On worker
ssh ubuntu@192.168.1.185 "sudo journalctl -u k3s-agent -f"
```

### Check K3s Status

```bash
ssh ubuntu@192.168.1.180 "sudo systemctl status k3s"
```

### Get Cluster Token

```bash
cd terraform
terraform output -raw k3s_token
cd ..
```

### Update Kubeconfig

If you need to regenerate kubeconfig:

```bash
CONTROL_PLANE_IP=$(cd terraform && terraform output -json control_plane_ips | jq -r '.[0]')
ssh "ubuntu@${CONTROL_PLANE_IP}" "sudo cat /etc/rancher/k3s/k3s.yaml" | \
  sed "s/127.0.0.1/${CONTROL_PLANE_IP}/" > kubeconfig
chmod 600 kubeconfig
```

---

## 🔧 Troubleshooting

### Issue: VMs not starting

**Check VM status:**
```bash
ssh root@YOUR_PROXMOX_HOST_OR_IP "qm list"
```

**Check specific VM:**
```bash
ssh root@YOUR_PROXMOX_HOST_OR_IP "qm status 100"  # Replace 100 with your VMID
```

**Solution:** Access Proxmox web UI and check console

---

### Issue: Cannot SSH to VMs

**Test connectivity:**
```bash
ping 192.168.1.180
```

**Check cloud-init status:**
```bash
ssh ubuntu@192.168.1.180 "sudo cloud-init status"
```

**Solution:** 
- Ensure VM has fully booted (wait 2-3 minutes)
- Check that SSH key is correct in terraform.tfvars
- Verify network configuration

---

### Issue: Terraform can't connect to Proxmox

**Test API:**
```bash
curl -ki \
  -H 'Authorization: PVEAPIToken=root@pam!terraform=YOUR_TOKEN_SECRET_HERE' \
  https://YOUR_PROXMOX_HOST_OR_IP:8006/api2/json/version
```

**Solution:**
- Verify API token secret is correct
- Check Proxmox API is accessible
- Ensure token has correct permissions

---

### Issue: K3s installation fails

**Check logs:**
```bash
ssh ubuntu@192.168.1.180 "sudo journalctl -u k3s -n 100"
```

**Manual installation:**
```bash
ssh ubuntu@192.168.1.180
curl -sfL https://get.k3s.io | sh -
sudo systemctl status k3s
```

---

### Issue: Nodes not joining cluster

**Check worker logs:**
```bash
ssh ubuntu@192.168.1.185 "sudo journalctl -u k3s-agent -n 100"
```

**Verify connectivity:**
```bash
ssh ubuntu@192.168.1.185 "curl -k https://192.168.1.180:6443"
```

**Solution:** Ensure control plane is fully ready before workers join

---

### Issue: Worker nodes not getting IP addresses

**Check network configuration:**
```bash
# Verify all VMs use network device ID 0
grep -A 3 "network {" terraform/main.tf
```

**Solution:** Ensure all VMs have `network { id = 0 }` in main.tf to ensure CloudInit properly configures network interfaces.

---

### Issue: Provider compatibility errors

This project uses telmate/proxmox provider v3.0.2-rc10 which has breaking changes:

- Use `cpu` block instead of `cpu` argument
- Network blocks require explicit `id` field
- CloudInit requires explicit `ide2 cloudinit` drive
- Serial port requires explicit configuration
- Proxmox VE 9.x roles should use `Sys.Audit`; do not add the removed `VM.Monitor` privilege

**Solution:** Ensure your terraform/main.tf uses the latest configuration format.

**Version context:** This project targets Proxmox VE 9.2.10. Do not confuse the Proxmox VE host version with the Terraform provider version pinned in `terraform/main.tf`.

---

## 🗑️ Cleanup / Destroy

### Option 1: Terraform Destroy (Recommended)

```bash
# Destroy all resources
cd terraform
terraform destroy

# Or with auto-approve
terraform destroy -auto-approve
cd ..
```

### Option 2: Manual Cleanup

```bash
# Connect to Proxmox
ssh root@YOUR_PROXMOX_HOST_OR_IP

# List VMs
qm list | grep k3s

# Stop and destroy each VM
qm stop <VMID>
qm destroy <VMID>
```

---

## 📝 Post-Deployment Tasks

### 1. Change Default Password

```bash
# SSH to each node and change password
ssh ubuntu@192.168.1.180 "sudo passwd ubuntu"
```

### 2. Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### 3. Install Cert-Manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

### 4. Install Longhorn (Storage)

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace
```

### 5. Traefik Ingress Controller (Enabled by Default)

Traefik is now enabled by default in K3s and provides:
- Built-in ingress controller for routing HTTP/HTTPS traffic
- Automatic SSL certificate management
- Load balancing capabilities
- Service discovery

To verify Traefik is running:
```bash
kubectl get pods -n kube-system | grep traefik
```

### 6. Install Nginx Ingress (Alternative)

If you prefer Nginx Ingress instead of Traefik:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
```

---

## 🎯 Next Steps

1. **Access ArgoCD** (if installed): Open the NodePort URL printed by deploy.sh
2. **Learn kubectl basics**: [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
3. **Deploy your first app**: Follow the test application example above
4. **Setup monitoring**: Install Prometheus and Grafana
5. **Configure backups**: Setup Velero for cluster backups
6. **Secure your cluster**: Implement Network Policies and RBAC

---

## 📚 Useful Resources

- [K3s Documentation](https://docs.k3s.io/)
- [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Helm Documentation](https://helm.sh/docs/)
- [Proxmox VE Wiki](https://pve.proxmox.com/wiki/Main_Page)

---

## ✅ Deployment Checklist

- [ ] All files created in project directory
- [ ] terraform/terraform.tfvars configured with API token secret
- [ ] Scripts made executable (chmod +x)
- [ ] Prerequisites installed (Terraform, Ansible, jq)
- [ ] SSH key exists and is correct
- [ ] Proxmox is accessible
- [ ] Template `ubuntu-24.04-cloud-tpl` exists on Proxmox
- [ ] IP range 192.168.1.180-187 is available
- [ ] Sufficient resources (5 vCPU, 10GB RAM)
- [ ] VM ID range 500-503 is available (or custom vm_id_start configured)
- [ ] Ansible inventory matches worker_count in terraform.tfvars
- [ ] ./deploy.sh executed successfully
- [ ] kubectl get nodes shows all nodes Ready
- [ ] Test application deployed and working
- [ ] ArgoCD installed (optional)

---

**Congratulations! You now have a fully functional K3s cluster! 🎉**
