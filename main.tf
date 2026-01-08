// terraform null resource
resource "terraform_data" "name" {

  for_each = toset(var.script_files)

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
    source      = each.value
    destination = "/tmp/${basename(each.value)}"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/${basename(each.value)}",
      "sh /tmp/${basename(each.value)} > /tmp/${basename(each.value)}.out",
    ]
  }

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ${var.output_dir}
      sshpass -p '${var.root_password}' scp -o StrictHostKeyChecking=no \
      root@${var.target_host}:/tmp/${basename(each.value)}.out \
      ${var.output_dir}/${basename(each.value)}.log
    EOT
  }

  provisioner "remote-exec" {
    inline = [
      "rm -f /tmp/${basename(each.value)} /tmp/${basename(each.value)}.out",
    ]
  }
}
