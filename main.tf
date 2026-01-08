// terraform null resource
resource "terraform_data" "name" {

  // always run
  triggers_replace = {
    always_run = timestamp()
  }

  // connect wtih ssh
  connection {
    type     = "ssh"
    host     = var.target_host
    user     = "root"
    password = var.root_password
    port     = var.ssh_port
  }

  provisioner "file" {
    source      = "scripts/log_mgmt.sh"
    destination = "/tmp/account_mgmt.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/account_mgmt.sh",
      "sh /tmp/account_mgmt.sh > /tmp/${var.output_file}",
    ]
  }

  provisioner "local-exec" {
    command     = "sshpass -p '${var.root_password}' scp -o StrictHostKeyChecking=no root@${var.target_host}:/tmp/${var.output_file} ./"
  }

  provisioner "remote-exec" {
    inline = [
      "rm -f /tmp/account_mgmt.sh /tmp/${var.output_file}",
    ]
  }
}
