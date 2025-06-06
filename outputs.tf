output "rg" {
  value       = "ghdev-rg"
  description = "Resource group name"
}

output "aks_node_resource_group" {
  description = "The node resource group created by AKS. The VNet will be in this group."
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}