variable "root_password" {
  description = "Root user password."
  type        = string
  sensitive   = true
  default     = "centos"
}

variable "target_host" {
  description = "The IPv4 address of the target server"
  type        = string
  default     = "192.168.10.10"
}

variable "ssh_port" {
  description = "The SSH port number of the target server"
  type        = number
  default     = 22
}

variable "output_file" {
  description = "Filename for the retrieved report from the server."
  type        = string
  default     = "report.txt"
}
