# プロバイダー設定
provider "azurerm" {
  features {}
  use_cli = true
  subscription_id = "ここに表示されたサブスクリプションIDを入力"
}

# リソースグループ
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# 仮想ネットワーク
resource "azurerm_virtual_network" "vnet" {
  name                = "firewall-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# サブネット - AzureFirewallSubnet（Firewallには専用サブネットが必要）
resource "azurerm_subnet" "firewall_subnet" {
  name                 = "AzureFirewallSubnet" # この名前は固定
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# サブネット - VM用
resource "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# パブリックIP - Firewall用
resource "azurerm_public_ip" "firewall_pip" {
  name                = "firewall-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Azure Firewall
resource "azurerm_firewall" "fw" {
  name                = "rdp-firewall"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall_subnet.id
    public_ip_address_id = azurerm_public_ip.firewall_pip.id
  }
}

# Firewall ネットワークルール - RDP接続用
resource "azurerm_firewall_network_rule_collection" "rdp_rule" {
  name                = "rdp-rule"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = azurerm_resource_group.rg.name
  priority            = 100
  action              = "Allow"

  rule {
    name                  = "allow-rdp"
    source_addresses      = [var.local_ip]
    destination_ports     = ["3389"]
    destination_addresses = ["10.0.2.0/24"]
    protocols             = ["TCP"]
  }
}

# Firewall DNAT ルール - RDP接続用
resource "azurerm_firewall_nat_rule_collection" "rdp_nat" {
  name                = "rdp-nat"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = azurerm_resource_group.rg.name
  priority            = 100
  action              = "Dnat"

  rule {
    name                  = "rdp-nat-rule"
    source_addresses      = [var.local_ip]
    destination_ports     = ["3389"]
    destination_addresses = [azurerm_public_ip.firewall_pip.ip_address]
    translated_port       = "3389"
    translated_address    = azurerm_network_interface.vm_nic.private_ip_address
    protocols             = ["TCP"]
  }
}

# ルートテーブル
resource "azurerm_route_table" "rt" {
  name                = "firewall-route-table"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# デフォルトルート - すべてのトラフィックをFirewallに送信
resource "azurerm_route" "default_route" {
  name                = "default-route"
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name    = azurerm_route_table.rt.name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
}

# ルートテーブルとVMサブネットの関連付け
resource "azurerm_subnet_route_table_association" "vm_subnet_rt" {
  subnet_id      = azurerm_subnet.vm_subnet.id
  route_table_id = azurerm_route_table.rt.id
}

# VM用のNIC
resource "azurerm_network_interface" "vm_nic" {
  name                = "vm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# 仮想マシン（最小スペック）
resource "azurerm_windows_virtual_machine" "vm" {
  name                = "rdp-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

# NSG for VM subnet
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "vm-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-rdp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.local_ip
    destination_address_prefix = "*"
  }
}

# Associate NSG with VM subnet
resource "azurerm_subnet_network_security_group_association" "vm_subnet_nsg" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}