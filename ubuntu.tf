#################################################################
# Terraform template that will deploy an VM with Openshift only
#
# Version: 1.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#
# Licensed Materials - Property of IBM
#
# ©Copyright IBM Corp. 2017.
#
#################################################################

#########################################################
# Define the ibmcloud provider
#########################################################
provider "ibm" {
# Empty. 
}

#########################################################
# Define the variables
#########################################################
variable "datacenter" {
  description = "Datacenter where infrastructure resources will be deployed"
}

variable "cpu" {
  description = "CPU"
}

variable "memoria" {
  description = "Memoria"
}

variable "hostname" {
  description = "Nome da máquina"
}

variable "password" {
  description = "Senha para acesso"
}

##############################################################
# Create temp public key for ssh connection
##############################################################
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
}

resource "ibm_compute_ssh_key" "temp_public_key" {
  label      = "Temp Public Key"
  public_key = "${tls_private_key.ssh.public_key_openssh}"
}

##############################################################
# Create Virtual Machine and install OpenShift
##############################################################
resource "ibm_compute_vm_instance" "softlayer_virtual_guest" {
  hostname                 = "${var.hostname}"
  os_reference_code        = "UBUNTU_18_64"
  domain                   = "ibm.cloud"
  datacenter               = "${var.datacenter}"
  network_speed            = 10
  hourly_billing           = true
  private_network_only     = false
  cores                    = "${var.cpu}"
  memory                   = "${var.memoria}"
  disks                    = [100]
  dedicated_acct_host_only = false
  local_disk               = false
  ssh_key_ids              = ["${ibm_compute_ssh_key.temp_public_key.id}"]

  # Specify the ssh connection
  connection {
    user        = "root"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host        = "${self.ipv4_address}"
  }

  # Create the installation script
  provisioner "file" {
    content = <<EOF
#!/bin/bash

# Change root password
echo "root:${var.password}" | chpasswd

# Installing docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

EOF

    destination = "/tmp/installation.sh"
  }

  # Execute the script remotely
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/installation.sh; bash /tmp/installation.sh",
    ]
  }
}

output "ip" {
  value = "${ibm_compute_vm_instance.softlayer_virtual_guest.ipv4_address}"
}


