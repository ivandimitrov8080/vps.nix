{
  inputs,
  pkgs,
  config,
  ...
}:
{
  imports = [
    inputs.configuration.nixosModules.default
    inputs.sops-nix.nixosModules.sops
    ../sops.nix
  ];
  sops.defaultSopsFile = pkgs.lib.mkForce ./vpsfree.yaml;
  networking.interfaces.eth1.ipv4.routes = [
    {
      address = "37.205.13.29";
      prefixLength = 32;
      # Change this when adding new machines cuz ip changes
      via = "192.168.1.5";
      options.scope = "global";
    }
  ];
  users = {
    users.test = {
      isNormalUser = true;
      password = "test";
      extraGroups = [
        "wheel"
        "adm"
        "mlocate"
        "ssh"
      ];
    };
    groups.ssh = { };
  };
  environment.systemPackages = with pkgs; [
    gnupg
    swaks
    wireguard-tools
    dig
    curl
    inetutils
    nmap
    ripgrep
  ];
  networking.useHostResolvConf = false;
  networking.enableIPv6 = false;
  system.activationScripts.import-test-gpg-key = {
    deps = [ "specialfs" ];
    text = ''
      ${pkgs.sequoia-chameleon-gnupg}/bin/gpg --batch --homedir ${config.sops.gnupg.home} --import ${./gnupg.asc}
    '';
  };
  system.activationScripts.setupSecretsForUsers.deps = pkgs.lib.mkBefore [ "import-test-gpg-key" ];
}
