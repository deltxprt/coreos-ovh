// fcos-byol.pkr.hcl
packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "ignition_url" {
  type = string
}

source "qemu" "fcos_openstack" {
  format         = "qcow2"
  qemu_binary    = "qemu-system-x86_64"
  accelerator    = ["kvm"]
  headless       = true

  // Point at your locally checked-out OpenStack image
  iso_url           =  "https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/42.20250705.3.0/x86_64/fedora-coreos-42.20250705.3.0-openstack.x86_64.qcow2.xz"
  iso_checksum      = "sha256:724208ad91016c3e0d03b97f71b9ecb67a65fede4a470199c0c91a9989c2ba89"
  output_path    = "fcos-byol.qcow2"
  disk_interface = "scsi"
}

build {
  name    = "fcos-byol"
  sources = ["source.qemu.fcos_openstack"]

  // Mount + inject the OVH script into /root/.ovh
  provisioner "shell" {
    inline = [
      "sudo modprobe nbd max_part=8",
      "sudo qemu-nbd --connect=/dev/nbd0 {{.SourcePath}}",
      "sleep 2",
      "sudo mkdir -p /mnt/fcos/root/.ovh",
      "cat << 'EOF' | sudo tee /mnt/fcos/root/.ovh/make_image_bootable.sh",
      "#!/bin/bash",
      "set -e",
      "/usr/bin/coreos-installer install /dev/sda --ignition-url \"${var.ignition_url}\" --insecure",
      "EOF",
      "sudo chmod +x /mnt/fcos/root/.ovh/make_image_bootable.sh",
      "sudo umount /mnt/fcos || true",
      "sudo qemu-nbd --disconnect /dev/nbd0"
    ]
  }

  // Compress the resulting QCOW2
  provisioner "shell-local" {
    inline = [
      "xz -T0 -9 fcos-byol.qcow2"
    ]
  }
}
