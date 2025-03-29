variable "resource_group_name" {
  description = "リソースグループ名"
  type        = string
  default     = "azure-firewall-rdp-rg"
}

variable "location" {
  description = "リソースのリージョン"
  type        = string
  default     = "japaneast"
}

variable "local_ip" {
  description = "ローカルPCのパブリックIP（RDP接続元）"
  type        = string
}

variable "admin_username" {
  description = "VMの管理者ユーザー名"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "VMの管理者パスワード"
  type        = string
  sensitive   = true
} 