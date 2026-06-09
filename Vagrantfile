# ==============================================================================
# Vagrantfile — JPetStore 6
# Stack: MariaDB (db01) → Tomcat (app01) → Nginx (web01)
# Compatible with: VirtualBox
# Plugin required: vagrant plugin install vagrant-hostmanager
# ==============================================================================

# ==============================================================================
# CONFIG — Edit these for each project
# ==============================================================================

# --- Network ---
BASE_IP    = "192.168.56"   # First 3 octets of your private network

# --- Box ---
CENTOS_BOX = "centos/stream9"
UBUNTU_BOX = "ubuntu/jammy64"

# --- VMs ---
# name:      Vagrant identifier     → vagrant up <name>
# hostname:  Hostname inside the VM
# ip:        Last octet of private IP (combined with BASE_IP)
# box:       OS box to use
# memory:    RAM in MB
# provision: Shell script to run on first boot
# gui:       Show VirtualBox GUI window (true/false)

VMS = [
  { name: "db01",  hostname: "db01",  ip: "15", box: CENTOS_BOX, memory: "600", provision: "jpetstore-mysql.sh",  gui: false },
  { name: "app01", hostname: "app01", ip: "12", box: CENTOS_BOX, memory: "800", provision: "jpetstore-tomcat.sh", gui: false },
  { name: "web01", hostname: "web01", ip: "11", box: UBUNTU_BOX, memory: "800", provision: "jpetstore-nginx.sh",            gui: false },
]

# ==============================================================================
# VAGRANTFILE — No need to edit below this line
# ==============================================================================

Vagrant.configure("2") do |config|

  # --- Host Manager Plugin ---
  # Automatically updates /etc/hosts on host machine and all guest VMs
  # so you can use hostnames (e.g. db01, app01) instead of IPs
  config.hostmanager.enabled     = true
  config.hostmanager.manage_host = true

  # --- Loop through each VM definition ---
  VMS.each do |vm|
    config.vm.define vm[:name] do |node|

      node.vm.box      = vm[:box]
      node.vm.hostname = vm[:hostname]

      # Private network IP — BASE_IP + last octet
      # e.g. 192.168.56.15 for db01
      node.vm.network "private_network", ip: "#{BASE_IP}.#{vm[:ip]}"

      # Uncomment to add a public (bridged) network interface
      # node.vm.network "public_network"

      # VirtualBox settings
      node.vm.provider "virtualbox" do |vb|
        vb.memory = vm[:memory]
        vb.gui    = vm[:gui]
        vb.name   = vm[:name]   # readable name in VirtualBox UI
      end

      # Run provisioning script on first boot
      node.vm.provision "shell", path: vm[:provision]

    end
  end

end
