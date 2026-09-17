variable "vm_name" {
  type    = string
  default = "measlab"
}

variable "os_version" {
  type    = string
  default = "24.04.5"
}

variable "cpus" {
  type    = number
  default = 4
}

variable "memory" {
  type    = number
  default = 4096
}

variable "disk_size" {
  type    = string
  default = "25000"
}

variable "ssh_username" {
  type    = string
  default = "learner"
}

variable "ssh_password" {
  type    = string
  default = "measlab"
}

variable "ssh_timeout" {
  type    = string
  default = "30m"
}

variable "iso_url" {
  type        = string
  description = "URL to the Ubuntu Server Live ISO"
  default     = "https://releases.ubuntu.com/noble/ubuntu-24.04.5-live-server-amd64.iso"
}

variable "iso_checksum" {
  type        = string
  description = "Checksum of the ISO (e.g. sha256:...)"
  default     = "file:https://releases.ubuntu.com/noble/SHA256SUMS"
}

variable "headless" {
  type    = bool
  default = true
}

variable "efi_firmware_code" {
  type        = string
  description = "Path to EFI firmware code file"
  default     = null
}

variable "efi_firmware_vars" {
  type        = string
  description = "Path to EFI firmware vars template file"
  default     = null
}
