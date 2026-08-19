require "yaml"

# data/vagrant.yaml is the single source of truth for the platform domain
# and the host-only network addresses. Hiera reads it for Puppet; this file
# reads it for the VM network, certificate preflight and host DNS trigger.
settings = YAML.load_file(File.join(File.dirname(__FILE__), "data", "vagrant.yaml"))
domain   = settings.fetch("macgrant::domain")
vm_ip    = settings.fetch("macgrant::vm_ip")
host_ip  = settings.fetch("macgrant::host_ip")

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.hostname = "macgrant-platform"

  config.vm.provider "virtualbox" do |vb|
    vb.cpus = 2
    vb.memory = 6144
  end

  config.vm.network "private_network", ip: vm_ip

  config.vm.boot_timeout = 600
  config.vm.provision "grub-autoboot",
    type: "shell",
    path: "scripts/configure-grub-autoboot.sh"

  config.vm.provision "shell",
    name: "certificate preflight",
    privileged: false,
    inline: <<~SHELL
      set -euo pipefail

      for certificate in \
        /vagrant/.local-certs/#{domain}.crt \
        /vagrant/.local-certs/#{domain}.key; do
        if [[ ! -r "$certificate" ]]; then
          echo "Missing required Traefik certificate: $certificate" >&2
          echo "Generate the wildcard certificate as documented in README.md." >&2
          exit 1
        fi
      done
    SHELL

  config.vm.provision "shell", path: "scripts/bootstrap.sh"
  config.vm.provision "shell", path: "scripts/install-puppet-modules.sh"
  config.vm.provision "shell", path: "scripts/install-traefik.sh"

  config.vm.provision :puppet do |puppet|
    puppet.manifests_path    = "puppet/manifests"
    puppet.manifest_file     = "default.pp"
    puppet.module_path       = ["puppet/site", "puppet/modules"]
    puppet.hiera_config_path = "hiera.yaml"
  end

  # Runs on the HOST after the VM starts
  config.trigger.after [:up, :reload, :resume] do |trigger|
    trigger.name = "Configure Macgrant host DNS"
    trigger.info = "Configuring *.#{domain} split DNS"

    trigger.run = {
      path: "scripts/configure-host-dns.sh",
      args: [vm_ip, host_ip, domain]
    }
  end
end
