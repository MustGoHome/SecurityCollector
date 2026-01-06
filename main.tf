// terraform null resource
resource "terraform_data" "name" {

  // always run
  triggers_replace = {
    always_run = timestamp()
  }

  // connect wtih ssh
  connection {
    type     = "ssh"
    host     = "192.168.10.10"
    user     = "root"
    password = var.root_password
    port     = 22
  }

  // remote exec
  provisioner "remote-exec" {
    inline = [
      "echo '--- Execution Time: ${timestamp()} ---' > /tmp/execution_log.txt",
      "uptime >> /tmp/execution_log.txt",
      "echo 'Command executed successfully.'"
    ]
  }

  // local exec
  provisioner "local-exec" {
    command = "sshpass -p '${var.root_password}' scp -o StrictHostKeyChecking=no root@192.168.10.10:/tmp/result.txt ./"
  }
}
