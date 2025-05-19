# Subscription ID
subscription_id="ca72a60d-fa94-4fb1-b5fc-ae5f7416a474"

# Resource Group
terraform import azurerm_resource_group.rg /subscriptions/$subscription_id/ghdev-rg

# Storage Account
terraform import azurerm_storage_account.storage /subscriptions/$subscription_id/ghdev-rg/providers/Microsoft.Storage/storageAccounts/ghdevstorageaccount

# Storage Container
terraform import azurerm_storage_container.container "/subscriptions/$subscription_id/resourceGroups/ghdev-rg/providers/Microsoft.Storage/storageAccounts/ghdevstorageaccount/blobServices/default/containers/ghdevcontainer"

# Virtual Network
terraform import azurerm_virtual_network.vnet /subscriptions/$subscription_id/ghdev-rg/providers/Microsoft.Network/virtualNetworks/ghdev-vnet

# Subnet
terraform import azurerm_subnet.subnet1 "/subscriptions/$subscription_id/ghdev-rg/providers/Microsoft.Network/virtualNetworks/ghdev-vnet/subnets/subnet1"

# Key Vault
terraform import azurerm_key_vault.kv /subscriptions/$subscription_id/ghdev-rg/providers/Microsoft.KeyVault/vaults/ghdev-keyvault

# Key Vault Secret (Postgres password)
# Use latest secret version
terraform import azurerm_key_vault_secret.postgres_password "https://ghdev-keyvault.vault.azure.net/secrets/postgres-admin-password/83e0f3c0fad34ab3a7450f31c97dddde"