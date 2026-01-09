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

variable "script_files" {
  description = "This variable is an array of paths to script files."
  type        = list(string)
  default = [
    "scripts/01_account_mgmt.sh",
    "scripts/02_file_mgmt.sh",
    "scripts/03_service_mgmt.sh",
    "scripts/04_fetch_mgmt.sh",
    "scripts/05_log_mgmt.sh"
  ]
}

variable "output_dir" {
  description = "This is the local path where the report file will be saved."
  type        = string
  default     = "./outputs"
}
