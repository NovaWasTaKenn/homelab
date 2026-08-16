{
  description = "Homelab env";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nvimConfigs = {
      url = "github:NovaWasTakenn/nvimConfigs/main";
      inputs.nixpkgs.follows = "nixpkgs"; # Suis le nixpkgs défini précédemment ou alors nixpkgs alias nix unstable ????
    };
    molecule-proxmox = {
      url = "github:NovaWasTakenn/molecule-proxmox/main";
      inputs.nixpkgs.follows = "nixpkgs"; # Suis le nixpkgs défini précédemment ou alors nixpkgs alias nix unstable ????
    };
  };

  outputs = inputs @ {...}: let
    system = "x86_64-linux";
    pkgs = import inputs.nixpkgs {
      config = {
        allowUnfree = true;
      };
      system = system;
      overlays = [
        (final: prev: {
          workNvim = inputs.nvimConfigs.packages.${system}.workNvim;
        })
      ];
    };
  in {
    # importing package example
    # packages."x86_64-linux".default =
    #   pkgs.callPackage (import ./default.nix) {};

    devShells."x86_64-linux".default = pkgs.mkShell {
      packages = with pkgs; [
        terraform
        ansible
        cloud-init
        python312
        python312Packages.proxmoxer
        molecule
        inputs.molecule-proxmox.packages.${system}.molecule-proxmox
        podman
        podman-compose
        proxmox-auto-install-assistant
        xorriso
        sops
        age
      ];

      shellHook = ''
        echo 'Welcome'
        set -a
        source '/home/quentin/Repos/homelab/config.env'
        set +a
        alias tf="terraform"
      '';
      #ENV_VAR = "";
    };
  };
}
