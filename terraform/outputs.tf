output "k3s_token" {
  description = "K3s cluster token"
  value       = local.k3s_token
  sensitive   = true
}

output "control_plane_ips" {
  description = "Control plane node IP addresses"
  value       = local.control_plane_ips
}

output "worker_ips" {
  description = "Worker node IP addresses"
  value       = local.worker_ips
}

output "control_plane_names" {
  description = "Control plane node names"
  value       = [for vm in proxmox_vm_qemu.k3s_control_plane : vm.name]
}

output "worker_names" {
  description = "Worker node names"
  value       = [for vm in proxmox_vm_qemu.k3s_worker : vm.name]
}

output "media_nfs_ips" {
  description = "Media NFS VM IP addresses"
  value       = [for vm in proxmox_vm_qemu.media_nfs : var.media_nfs_ip]
}

output "media_nfs_names" {
  description = "Media NFS VM names"
  value       = [for vm in proxmox_vm_qemu.media_nfs : vm.name]
}

output "ssh_command_control_plane" {
  description = "SSH command for control plane node"
  value       = "ssh ${var.ssh_username}@${local.control_plane_ips[0]}"
}

output "kubeconfig_command" {
  description = "Command to retrieve kubeconfig from control plane"
  value       = "ssh ${var.ssh_username}@${local.control_plane_ips[0]} 'sudo cat /etc/rancher/k3s/k3s.yaml'"
}

output "k3s_version" {
  description = "K3s version"
  value       = var.k3s_version
}

output "vm_ssh_username" {
  description = "Default VM SSH username"
  value       = var.ssh_username
}

output "cluster_info" {
  description = "K3s cluster information"
  value = {
    control_plane = {
      count  = var.control_plane_count
      cpu    = var.control_plane_cpu
      memory = var.control_plane_memory
      ips    = local.control_plane_ips
    }
    workers = {
      count  = var.worker_count
      cpu    = var.worker_cpu
      memory = var.worker_memory
      ips    = local.worker_ips
    }
    media_nfs = {
      enabled = var.media_nfs_enabled
      cpu     = var.media_nfs_cpu
      memory  = var.media_nfs_memory
      disk    = var.media_nfs_disk_size
      ips     = [for vm in proxmox_vm_qemu.media_nfs : var.media_nfs_ip]
    }
    k3s_version = var.k3s_version
  }
}
