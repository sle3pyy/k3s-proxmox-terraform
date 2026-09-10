variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://YOUR_PROXMOX_HOST_OR_IP:8006/api2/json"
}

variable "proxmox_api_token_id" {
  description = "Proxmox API Token ID (format: user@realm!tokenname)"
  type        = string
  default     = "root@pam!terraform"
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for VM bootstrap access"
  type        = string
  default     = ""

  validation {
    condition = (
      trimspace(var.ssh_public_key) == "" ||
      can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) [A-Za-z0-9+/]+={0,3}( .*)?$", trimspace(var.ssh_public_key)))
    )
    error_message = "ssh_public_key must be empty or a valid OpenSSH public key."
  }
}

variable "ssh_username" {
  description = "Default VM username configured through cloud-init"
  type        = string
  default     = "ubuntu"
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "proxmox"
}

variable "template_id" {
  description = "VM template name for cloning"
  type        = string
  default     = "ubuntu-24.04-cloud-tpl"
}

variable "vm_id_start" {
  description = "Starting VM ID for created VMs"
  type        = number
  default     = 30000
}

variable "storage" {
  description = "Storage pool for VM disks"
  type        = string
  default     = "local-zfs"
}

variable "snippet_storage" {
  description = "Storage for cloud-init drive"
  type        = string
  default     = "usb-storage-01"
}

variable "bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "vm_network_cidr" {
  description = "CIDR block for K3s VM IP addresses"
  type        = string
  default     = "192.168.1.0/24"
}

variable "gateway" {
  description = "Network gateway"
  type        = string
  default     = "192.168.1.1"
}

variable "nameserver" {
  description = "DNS nameserver"
  type        = string
  default     = "192.168.1.1"
}

variable "searchdomain" {
  description = "DNS search domain"
  type        = string
  default     = "local"
}

# Control Plane Configuration
variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 1
}

variable "control_plane_cpu" {
  description = "CPU cores for control plane nodes"
  type        = number
  default     = 2
}

variable "control_plane_memory" {
  description = "Memory in MB for control plane nodes"
  type        = number
  default     = 4096
}

variable "control_plane_disk_size" {
  description = "Disk size for control plane nodes"
  type        = string
  default     = "10G"
}

variable "control_plane_ip_start" {
  description = "Starting IP for control plane nodes"
  type        = string
  default     = "192.168.1.180"
}

# Worker Configuration
variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "worker_cpu" {
  description = "CPU cores for worker nodes"
  type        = number
  default     = 1
}

variable "worker_memory" {
  description = "Memory in MB for worker nodes"
  type        = number
  default     = 2048
}

variable "worker_disk_size" {
  description = "Disk size for worker nodes"
  type        = string
  default     = "10G"
}

variable "worker_ip_start" {
  description = "Starting IP for worker nodes"
  type        = string
  default     = "192.168.1.185"
}

# Media NFS Storage Configuration
variable "media_nfs_enabled" {
  description = "Whether to create a dedicated media NFS VM"
  type        = bool
  default     = true
}

variable "media_nfs_name" {
  description = "Name of the dedicated media NFS VM"
  type        = string
  default     = "media-nfs"
}

variable "media_nfs_cpu" {
  description = "CPU cores for the media NFS VM"
  type        = number
  default     = 1
}

variable "media_nfs_memory" {
  description = "Memory in MB for the media NFS VM"
  type        = number
  default     = 2048
}

variable "media_nfs_disk_size" {
  description = "Disk size for the media NFS VM"
  type        = string
  default     = "200G"
}

variable "media_nfs_ip" {
  description = "Static IP address for the media NFS VM"
  type        = string
  default     = "192.168.1.54"
}

# K3s Configuration
variable "k3s_version" {
  description = "K3s version to install"
  type        = string
  default     = "v1.34.1+k3s1"
}

variable "k3s_token" {
  description = "K3s cluster token (will be auto-generated if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}
