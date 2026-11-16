{ config, ... }:
let
  mailServices = [
    "radicale.service"
    "dovecot.service"
    "postfix.service"
  ];
in
{
  sops = {
    gnupg = {
      home = "/root/.gnupg";
      sshKeyPaths = [ ];
    };
    age.sshKeyPaths = [ ];
    defaultSopsFile = ./secrets/vpsfree.yaml;
    secrets = {
      ivand-pass.neededForUsers = true;
      ivan-pass = {
        neededForUsers = true;
        restartUnits = mailServices;
      };
      security-pass = {
        neededForUsers = true;
        restartUnits = mailServices;
      };
      cloudflare-dns-api-token = { };
    };
    templates = {
      "radicale.users" = {
        content = ''
          ivan@idimitrov.dev:${config.sops.placeholder.ivan-pass}
        '';
        owner = "radicale";
        group = "radicale";
        mode = "0400";
      };
      "acme.env" = {
        content = ''
          CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder.cloudflare-dns-api-token}
        '';
        owner = "acme";
        group = "root";
        mode = "0400";
      };
    };
  };
}
