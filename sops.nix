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
    defaultSopsFile = ./secrets/vpsfree.yaml;
    secrets = {
      ivan-pass = {
        neededForUsers = true;
        restartUnits = mailServices;
      };
      security-pass = {
        neededForUsers = true;
        restartUnits = mailServices;
      };
      acme = {
        sopsFile = ./secrets/acme.env;
        format = "dotenv";
        owner = "acme";
        group = "root";
        mode = "0400";
      };
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
    };
  };
}
