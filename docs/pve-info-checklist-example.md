# Proxmox VE Information Gathering Checklist for K3s Deployment

## ☐ Step 1: Basic Connection Information

### Manual Input Required:
- [ ] **PVE Hostname/IP**: _____________________
- [ ] **PVE Web Interface Port** (usually 8006): _____________________
- [ ] **Authentication Method** (API Token / Username+Password): _____________________

### Commands to Run:
```bash
# Get PVE version
pveversion
```
**Expected for this project:** Proxmox VE 9.2.10

**Output:**
```
[Paste output here]
```

---

## ☐ Step 2: Node Information

### Commands to Run:
```bash
# Get all nodes in the cluster
pvesh get /nodes --output-format json
```
**Output:**
```json
[Paste output here]
```

```bash
# Get your hostname (for single node setups)
hostname
```
**Output:**
```
[Paste output here]
```

---

## ☐ Step 3: Storage Information

### Commands to Run:
```bash
# Get all storage configurations
pvesh get /storage --output-format json
```
**Output:**
```json
[Paste output here]
```

```bash
# Get storage status with more details
pvesm status
```
**Output:**
```
[Paste output here]
```

```bash
# List content on each storage (we'll check manually)
# Replace <storage-name> with actual storage names from pvesm status output
# pvesm list <storage-name>
```
**Notes:**
```
[We'll identify suitable storage from pvesm status output above]
```

---

## ☐ Step 4: Network Configuration

### Commands to Run:
```bash
# Show network interfaces configuration
cat /etc/network/interfaces
```
**Output:**
```
[Paste output here]
```

```bash
# Show available bridges
ip link show type bridge
```
**Output:**
```
[Paste output here]
```

```bash
# Show IP addresses assigned to interfaces
ip addr show
```
**Output:**
```
[Paste output here]
```

---

## ☐ Step 5: Available Resources

### Commands to Run:
```bash
# Get node status (CPU, Memory, Storage)
pvesh get /nodes/$(hostname)/status --output-format json
```
**Output:**
```json
[Paste output here]
```

```bash
# CPU details
lscpu | grep -E "^CPU\(s\)|^Model name|^Thread|^Core"
```
**Output:**
```
[Paste output here]
```

```bash
# Memory details
free -h
```
**Output:**
```
[Paste output here]
```

---

## ☐ Step 6: Network Planning (To be filled after review)

### K3s Cluster Network Details:
- [ ] **Number of control plane nodes**: _____________________
- [ ] **Number of worker nodes**: _____________________
- [ ] **IP range for K3s VMs** (e.g., 192.168.1.100-110): _____________________
- [ ] **Gateway IP**: _____________________
- [ ] **DNS Server(s)**: _____________________
- [ ] **Network Bridge to use** (e.g., vmbr0): _____________________

---

## ☐ Step 7: VM Template/Image Information

### Commands to Run:
```bash
# Check if cloud-init images exist
ls -lh /var/lib/vz/template/iso/ | grep -i cloud

# Or check in your configured template storage
pvesm list <your-storage-name> --content vztmpl,iso
```
**Output:**
```
[Paste output here]
```

### Template Decision:
- [ ] **Use existing template** (Template ID: _______)
- [ ] **Download Ubuntu Cloud Image** (we'll do this together)
- [ ] **Download Debian Cloud Image** (we'll do this together)

---

## ☐ Step 8: API Token Setup (if not already configured)

### Commands to Run:
```bash
# List existing API tokens
pvesh get /access/users/<username>/token --output-format json

# Example: pvesh get /access/users/root@pam/token --output-format json
```
**Output:**
```json
[Paste output here]
```

### If creating new token:
- [ ] **Token ID**: _____________________
- [ ] **Token Secret**: _____________________ (save this securely!)

---

## ☐ Step 9: SSH Key (for K3s nodes)

### Commands to Run on WSL:
```bash
# Check if you have an SSH key
ls -la ~/.ssh/id_*.pub

# If not, generate one:
ssh-keygen -t ed25519 -C "k3s-cluster"
```
**Output:**
```
[Paste your PUBLIC key content here]
```

---

## ☐ Step 10: Terraform & Tools Verification (WSL)

### Commands to Run on WSL:
```bash
# Check Terraform version
terraform version

# Check if terraform is installed, if not:
# wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
# echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
# sudo apt update && sudo apt install terraform
```
**Output:**
```
[Paste output here]
```

---

## Summary Checklist

Before proceeding to Terraform configuration, ensure you have:

- [ ] PVE connection details (IP, credentials/token)
- [ ] Node information and hostname
- [ ] Storage backend identified (for VM disks and ISOs)
- [ ] Network bridge identified
- [ ] IP addressing scheme planned
- [ ] Available resources confirmed (sufficient CPU/RAM)
- [ ] Cloud-init image or template ready
- [ ] API token created (if using token auth)
- [ ] SSH public key ready
- [ ] Terraform installed on WSL

---

**Once you've completed this checklist, we'll proceed to create the Terraform configuration!**
