output "owasp_juice_shop_fqdn" {
  value = azurerm_container_app.app.latest_revision_fqdn
}