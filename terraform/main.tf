terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true
  pm_log_enable       = true
  pm_log_file         = "terraform-plugin-proxmox.log"
  pm_log_levels = {
    _default    = "debug"
    _capturelog = ""
  }
}

# Generate random token for K3s cluster
resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

locals {
  k3s_token                = var.k3s_token != "" ? var.k3s_token : random_password.k3s_token.result
  vm_network_prefix_length = tonumber(split("/", var.vm_network_cidr)[1])

  vm_network_base_octets = [for octet in split(".", split("/", var.vm_network_cidr)[0]) : tonumber(octet)]
  control_plane_start_octets = [
    for octet in split(".", var.control_plane_ip_start) : tonumber(octet)
  ]
  worker_start_octets = [
    for octet in split(".", var.worker_ip_start) : tonumber(octet)
  ]

  vm_network_base_number = (
    local.vm_network_base_octets[0] * 16777216 +
    local.vm_network_base_octets[1] * 65536 +
    local.vm_network_base_octets[2] * 256 +
    local.vm_network_base_octets[3]
  )
  control_plane_start_number = (
    local.control_plane_start_octets[0] * 16777216 +
    local.control_plane_start_octets[1] * 65536 +
    local.control_plane_start_octets[2] * 256 +
    local.control_plane_start_octets[3]
  )
  worker_start_number = (
    local.worker_start_octets[0] * 16777216 +
    local.worker_start_octets[1] * 65536 +
    local.worker_start_octets[2] * 256 +
    local.worker_start_octets[3]
  )

  control_plane_start_host = local.control_plane_start_number - local.vm_network_base_number
  worker_start_host        = local.worker_start_number - local.vm_network_base_number
  control_plane_ips = [
    for i in range(var.control_plane_count) :
    cidrhost(var.vm_network_cidr, local.control_plane_start_host + i)
  ]
  worker_ips = [
    for i in range(var.worker_count) :
    cidrhost(var.vm_network_cidr, local.worker_start_host + i)
  ]
}

# Control Plane Nodes
resource "proxmox_vm_qemu" "k3s_control_plane" {
  count = var.control_plane_count

  name        = "k3s-cp-${count.index + 1}"
  target_node = var.proxmox_node
  clone       = var.template_id
  full_clone  = true
  vmid        = var.vm_id_start + count.index

  agent   = 1
  os_type = "cloud-init"
  memory  = var.control_plane_memory

  cpu {
    type    = "host"
    cores   = var.control_plane_cpu
    sockets = 1
  }
  scsihw   = "virtio-scsi-single"
  bootdisk = "scsi0"

  onboot  = true
  startup = "order=1"

  disks {
    scsi {
      scsi0 {
        disk {
          storage = var.storage
          size    = var.control_plane_disk_size
        }
      }
    }
    # CloudInit drive
    ide {
      ide2 {
        cloudinit {
          storage = var.storage
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.bridge
  }

  # Serial port for console access
  serial {
    id   = 0
    type = "socket"
  }

  ipconfig0 = "ip=${local.control_plane_ips[count.index]}/${local.vm_network_prefix_length},gw=${var.gateway}"

  nameserver   = var.nameserver
  searchdomain = var.searchdomain

  ciuser     = var.ssh_username
  cipassword = var.ssh_password
  sshkeys    = var.ssh_public_key
  cicustom   = var.enable_ssh_password_auth ? "vendor=${var.snippet_storage}:snippets/${var.ssh_password_cloud_init_snippet}" : null

  lifecycle {
    ignore_changes = [
      network,
      ciuser,
      sshkeys,
    ]
  }
}

# Worker Nodes
resource "proxmox_vm_qemu" "k3s_worker" {
  count = var.worker_count

  name        = "k3s-worker-${count.index + 1}"
  target_node = var.proxmox_node
  clone       = var.template_id
  full_clone  = true
  vmid        = var.vm_id_start + var.control_plane_count + count.index

  agent   = 1
  os_type = "cloud-init"
  memory  = var.worker_memory

  cpu {
    type    = "host"
    cores   = var.worker_cpu
    sockets = 1
  }
  scsihw   = "virtio-scsi-single"
  bootdisk = "scsi0"

  onboot  = true
  startup = "order=2"

  disks {
    scsi {
      scsi0 {
        disk {
          storage = var.storage
          size    = var.worker_disk_size
        }
      }
    }
    # CloudInit drive
    ide {
      ide2 {
        cloudinit {
          storage = var.storage
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.bridge
  }

  # Serial port for console access
  serial {
    id   = 0
    type = "socket"
  }

  ipconfig0 = "ip=${local.worker_ips[count.index]}/${local.vm_network_prefix_length},gw=${var.gateway}"

  nameserver   = var.nameserver
  searchdomain = var.searchdomain

  ciuser     = var.ssh_username
  cipassword = var.ssh_password
  sshkeys    = var.ssh_public_key
  cicustom   = var.enable_ssh_password_auth ? "vendor=${var.snippet_storage}:snippets/${var.ssh_password_cloud_init_snippet}" : null

  lifecycle {
    ignore_changes = [
      network,
      ciuser,
      sshkeys,
    ]
  }

  depends_on = [proxmox_vm_qemu.k3s_control_plane]
}
