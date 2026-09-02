packer {
  required_version = ">= 1.9.0"
  required_plugins {
    qemu = {
      version = ">= 1.0.10"
      source  = "github.com/hashicorp/qemu"
    }
    virtualbox = {
      version = ">= 1.0.5"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

# -----------------------------------------------------------------------------
# Source: VirtualBox ISO (x86_64 -> .ova)
# -----------------------------------------------------------------------------
source "virtualbox-iso" "measlab-x86_64" {
  vm_name              = var.vm_name
  guest_os_type        = "Ubuntu_64"
  iso_url              = var.iso_url
  iso_checksum         = var.iso_checksum
  headless             = var.headless
  cpus                 = var.cpus
  memory               = var.memory
  disk_size            = var.disk_size
  guest_additions_mode = "disable"

  http_directory = "http"

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = var.ssh_timeout

  boot_wait = "5s"
  boot_command = [
    "c<wait>",
    "set gfxpayload=keep<enter><wait>",
    "linux /casper/vmlinuz quiet autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]

  shutdown_command = "echo 'measlab' | sudo -S shutdown -P now"

  vboxmanage = [
    ["modifyvm", "{{ .Name }}", "--natpf1", "portal,tcp,,8080,,8080"],
    ["modifyvm", "{{ .Name }}", "--natpf1", "term_host1,tcp,,7681,,7681"],
    ["modifyvm", "{{ .Name }}", "--natpf1", "term_r1,tcp,,7682,,7682"],
    ["modifyvm", "{{ .Name }}", "--natpf1", "term_r2,tcp,,7683,,7683"],
    ["modifyvm", "{{ .Name }}", "--natpf1", "term_r3,tcp,,7684,,7684"],
    ["modifyvm", "{{ .Name }}", "--natpf1", "ssh,tcp,,2222,,22"]
  ]

  format = "ova"
  output_directory = "output-vbox-x86_64"
}

# -----------------------------------------------------------------------------
# Source: QEMU (ARM64 / Apple Silicon / UTM -> .qcow2)
# -----------------------------------------------------------------------------
source "qemu" "measlab-arm64" {
  vm_name          = "${var.vm_name}.qcow2"
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  headless         = var.headless
  cpus             = var.cpus
  memory           = var.memory
  disk_size        = "${var.disk_size}M"
  accelerator      = "hvf" # use "kvm" on Linux ARM64, "tcg" on x86 emulation
  machine_type     = "virt"
  efi_boot         = true

  http_directory = "http"

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = var.ssh_timeout

  boot_wait = "8s"
  boot_command = [
    "c<wait>",
    "set gfxpayload=keep<enter><wait>",
    "linux /casper/vmlinuz quiet autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]

  shutdown_command = "echo 'measlab' | sudo -S shutdown -P now"

  qemuargs = [
    ["-cpu", "host"],
    ["-netdev", "user,id=net0,hostfwd=tcp::8080-:8080,hostfwd=tcp::7681-:7681,hostfwd=tcp::7682-:7682,hostfwd=tcp::7683-:7683,hostfwd=tcp::7684-:7684,hostfwd=tcp::2222-:22"],
    ["-device", "virtio-net-pci,netdev=net0"]
  ]

  format           = "qcow2"
  output_directory = "output-qemu-arm64"
}

# -----------------------------------------------------------------------------
# Source: QEMU (x86_64 -> .qcow2)
# -----------------------------------------------------------------------------
source "qemu" "measlab-x86_64" {
  vm_name          = "${var.vm_name}.qcow2"
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  headless         = var.headless
  cpus             = var.cpus
  memory           = var.memory
  disk_size        = "${var.disk_size}M"
  accelerator      = "kvm" # "tcg" on macOS without nested KVM

  http_directory = "http"

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = var.ssh_timeout

  boot_wait = "5s"
  boot_command = [
    "c<wait>",
    "set gfxpayload=keep<enter><wait>",
    "linux /casper/vmlinuz quiet autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]

  shutdown_command = "echo 'measlab' | sudo -S shutdown -P now"

  qemuargs = [
    ["-netdev", "user,id=net0,hostfwd=tcp::8080-:8080,hostfwd=tcp::7681-:7681,hostfwd=tcp::7682-:7682,hostfwd=tcp::7683-:7683,hostfwd=tcp::7684-:7684,hostfwd=tcp::2222-:22"],
    ["-device", "virtio-net-pci,netdev=net0"]
  ]

  format           = "qcow2"
  output_directory = "output-qemu-x86_64"
}

# -----------------------------------------------------------------------------
# Build Execution
# -----------------------------------------------------------------------------
build {
  sources = [
    "source.virtualbox-iso.measlab-x86_64",
    "source.qemu.measlab-arm64",
    "source.qemu.measlab-x86_64"
  ]

  # Copy repository files to learner home
  provisioner "shell" {
    inline = [
      "mkdir -p /home/learner/measurement-lab"
    ]
  }

  provisioner "file" {
    source      = "../activities"
    destination = "/home/learner/measurement-lab/"
  }

  provisioner "file" {
    source      = "../configs"
    destination = "/home/learner/measurement-lab/"
  }

  provisioner "file" {
    source      = "../frontend"
    destination = "/home/learner/measurement-lab/"
  }

  provisioner "file" {
    source      = "../scripts"
    destination = "/home/learner/measurement-lab/"
  }

  provisioner "file" {
    source      = "../topology.clab.yml"
    destination = "/home/learner/measurement-lab/topology.clab.yml"
  }

  provisioner "file" {
    source      = "../topology-diagram.svg"
    destination = "/home/learner/measurement-lab/topology-diagram.svg"
  }

  provisioner "file" {
    source      = "../lab.sh"
    destination = "/home/learner/measurement-lab/lab.sh"
  }

  provisioner "file" {
    source      = "../portal.sh"
    destination = "/home/learner/measurement-lab/portal.sh"
  }

  provisioner "file" {
    source      = "../README.md"
    destination = "/home/learner/measurement-lab/README.md"
  }

  # Copy systemd service and issue files
  provisioner "file" {
    source      = "files/measlab-portal.service"
    destination = "/tmp/measlab-portal.service"
  }

  provisioner "file" {
    source      = "files/motd-measlab.sh"
    destination = "/tmp/motd-measlab.sh"
  }

  provisioner "file" {
    source      = "files/issue"
    destination = "/tmp/issue"
  }

  # Execute provisioning scripts
  provisioner "shell" {
    execute_command = "echo 'measlab' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
    scripts = [
      "scripts/provision.sh",
      "scripts/cleanup.sh"
    ]
  }
}
