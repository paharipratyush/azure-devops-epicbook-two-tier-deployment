# 1. Random ID for Unique DB Name
resource "random_id" "id" {
  byte_length = 4
}

# 2. Resource Group (Read existing group instead of creating)
data "azurerm_resource_group" "rg" {
  name = "rg-epicbook"
}

# 3. Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-epicbook"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

# 4. Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-epicbook"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 5. Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-epicbook"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 6. Public IP
resource "azurerm_public_ip" "pip" {
  name                = "pip-epicbook"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 7. Network Interface
resource "azurerm_network_interface" "nic" {
  name                = "nic-epicbook"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# 8. Virtual Machine
resource "azurerm_linux_virtual_machine" "main" {
  name                            = "vm-epicbook-app"
  resource_group_name             = data.azurerm_resource_group.rg.name
  location                        = data.azurerm_resource_group.rg.location
  size                            = var.vm_size
  admin_username                  = var.admin_user
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_user
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    name                 = "osdisk-epicbook"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# 9. MySQL Flexible Server (PaaS)
resource "azurerm_mysql_flexible_server" "db" {
  name                   = "epicbook-db-${random_id.id.hex}"
  resource_group_name    = data.azurerm_resource_group.rg.name
  location               = data.azurerm_resource_group.rg.location
  administrator_login    = var.db_user
  administrator_password = var.db_password
  sku_name               = "B_Standard_B1ms"
  version                = "8.0.21"
}

# Allow access so the App VM (and your local machine for debugging) can reach the DB
resource "azurerm_mysql_flexible_server_firewall_rule" "allow_all" {
  name                = "AllowAllIPs"
  resource_group_name = data.azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.db.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}

# 10. Outputs (REQUIRED FOR MANUAL HANDOFF)
output "app_public_ip" {
  description = "The public IP of the EpicBook App VM"
  value       = azurerm_public_ip.pip.ip_address
}

output "mysql_fqdn" {
  description = "The Endpoint URL of the MySQL Database"
  value       = azurerm_mysql_flexible_server.db.fqdn
}
