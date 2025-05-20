output "rg" {
  value       = "ghdev-rg"
  description = "Resource group name"
}

output "dns_nameservers" {
  value       = azurerm_dns_zone.domain_ghdev.name_servers
  description = "DNS nameservers for ghdev.uk DNS zone"
}