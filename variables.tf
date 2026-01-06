variable "root_password" {
  description = "This variable is the root password and should be provided at the start of provisioning"
  type        = string
  sensitive   = true
}
