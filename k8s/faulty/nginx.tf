# provider "helm" {
#   kubernetes {
#     config_path = "~/.kube/config"
#   }
# }

# Create an NGINX ingress controller via Helm
# resource "helm_release" "nginx_ingress" {
#   name       = "nginx-ingress"
#   namespace  = "myapp"
#   repository = "https://kubernetes.github.io/ingress-nginx"
#   chart      = "ingress-nginx"
#   create_namespace = true

#   set {
#     name  = "controller.service.loadBalancerIP"
#     value = azurerm_public_ip.public_ip.ip_address
#   }

#   set {
#     name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
#     value = "MC_ghdev-rg_ghdev-aks_uksouth"
#   }

#   set {
#     name  = "controller.ingressClassResource.name"
#     value = "nginx"
#   }
#   set {
#     name  = "controller.ingressClass"
#     value = "nginx"
#   }
# }