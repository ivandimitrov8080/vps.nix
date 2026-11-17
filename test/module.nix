{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkBefore mkForce;
in
{
  imports = [
    inputs.configuration.nixosModules.default
    inputs.sops-nix.nixosModules.sops
    ../sops.nix
  ];
  sops.defaultSopsFile = pkgs.lib.mkForce ./vpsfree.yaml;
  security = {
    pki.certificateFiles = [ ./cert/cert.pem ];
    acme = mkForce { };
  };
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
  networking = {
    useHostResolvConf = false;
    enableIPv6 = false;
  };
  system.activationScripts = {
    import-test-gpg-key = {
      deps = [ "specialfs" ];
      text = ''
        ${pkgs.gnupg}/bin/gpg --batch --homedir ${config.sops.gnupg.home} --import ${./gnupg.asc}
      '';
    };
    setupSecretsForUsers.deps = mkBefore [ "import-test-gpg-key" ];
  };
  services.dnscrypt-proxy.settings.offline_mode = true;
  systemd = {
    tmpfiles.rules = [ "d /var/vmail 0750 virtualMail virtualMail -" ];
    services = {
      systemd-resolved.environment.SYSTEMD_LOG_LEVEL = "err";
      dovecot.preStart = mkForce "";
    };
  };
}
