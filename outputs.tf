output "firewall_public_ip" {
  description = "Azure Firewallのパブリックアドレス"
  value       = azurerm_public_ip.firewall_pip.ip_address
}

output "vm_private_ip" {
  description = "VMのプライベートIPアドレス"
  value       = azurerm_network_interface.vm_nic.private_ip_address
} 