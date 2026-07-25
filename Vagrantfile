Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.hostname = "macgrant-platform"

  config.vm.network "private_network", ip: "192.168.56.10"

  config.vm.provision "shell",
    name: "certificate preflight",
    privileged: false,
    inline: <<~'SHELL'
      set -euo pipefail

      for certificate in \
        /vagrant/.local-certs/macgrant-platform.test.crt \
        /vagrant/.local-certs/macgrant-platform.test.key; do
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

    puppet.facter = {
      "macgrant_domain"  => "macgrant-platform.test",
      "macgrant_vm_ip"   => "192.168.56.10",
      "macgrant_host_ip" => "192.168.56.1"
    }
  end

  # Runs on the HOST after the VM starts
  config.trigger.after [:up, :reload, :resume] do |trigger|
    trigger.name = "Configure Macgrant host DNS"
    trigger.info = "Configuring *.macgrant-platform.test split DNS"

    trigger.run = {
      path: "scripts/configure-host-dns.sh",
      args: [
        "192.168.56.10",
        "192.168.56.1",
        "macgrant-platform.test"
      ]
    }
  end
end
