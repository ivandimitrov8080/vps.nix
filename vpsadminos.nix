{ inputs }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib) mkForce;
in
{
  imports = with inputs; [
    simple-nixos-mailserver.nixosModules.default
  ];
  fileSystems."/mnt/export1981" = {
    device = "172.16.128.47:/nas/5490";
    fsType = "nfs";
    options = [ "nofail" ];
  };
  networking.hostName = "vpsfree";
  meta = {
    mail.enable = true;
    bingwp.enable = true;
  };
  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
    nixos.enable = false;
  };
  nix.registry = mkForce { };
  services.nginx.enable = true;
  networking = {
    nftables.enable = true;
    firewall = {
      trustedInterfaces = [ "wg0" ];
      allowedTCPPorts = mkForce [
        25 # smtp auth disabled here
        80 # http
        443 # https
      ];
      allowedUDPPorts = mkForce [
        51820 # wireguard
      ];
    };
  };
  users = {
    users = {
      ivand = lib.mkForce {
        isNormalUser = true;
        hashedPassword = "$2b$05$hPrPcewxj4qjLCRQpKBAu.FKvKZdIVlnyn4uYsWE8lc21Jhvc9jWG";
        extraGroups = [
          "wheel"
          "adm"
          "mlocate"
          "ssh"
        ];
        openssh.authorizedKeys.keys = [
          ''
            ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICcLkzuCoBEg+wq/H+hkrv6pLJ8J5BejaNJVNnymlnlo ivan@idimitrov.dev
          ''
        ];
      };
    };
    groups = {
      ssh = { };
    };
  };
  programs.git.enable = true;
  services = {
    gitDaemon = {
      enable = true;
      listenAddress = "10.0.0.1";
      basePath = "/var/git";
      exportAll = true;
      options = "--enable=receive-pack";
    };
    openssh = {
      enable = true;
      settings.ListenAddress = "10.0.0.1";
    };
    radicale = {
      enable = true;
      settings = {
        server = {
          hosts = [ "127.0.0.1:5232" ];
        };
        auth =
          let
            inherit (lib) concatStrings flip mapAttrsToList;
            htpasswd = pkgs.writeText "radicale.users" (
              concatStrings (
                flip mapAttrsToList config.mailserver.accounts (mail: user: mail + ":" + user.hashedPassword + "\n")
              )
            );
          in
          {
            type = "htpasswd";
            htpasswd_filename = "${htpasswd}";
            htpasswd_encryption = "bcrypt";
          };
        storage = {
          filesystem_folder = "/var/lib/radicale/collections";
        };
      };
    };
    postgresql.enable = true;
    dnscrypt-proxy.settings.cloaking_rules = "/etc/dnscrypt-proxy/cloaking_rules.txt";
  };
  environment = {
    systemPackages = [ pkgs.kitty ];
    etc."dnscrypt-proxy/cloaking_rules.txt".text = ''
      *.idimitrov.dev 10.0.0.1
    '';
  };
}
