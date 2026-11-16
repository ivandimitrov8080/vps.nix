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
      synapse-registration-shared-secret = { };
      telegram-api-id = {};
      telegram-api-hash = {};
    };
    templates = let ph = config.sops.placeholder; in{
      "radicale.users" = {
        content = ''
          ivan@idimitrov.dev:${ph.ivan-pass}
        '';
        owner = "radicale";
        group = "radicale";
        mode = "0400";
      };
      "acme.env" = {
        content = ''
          CLOUDFLARE_DNS_API_TOKEN=${ph.cloudflare-dns-api-token}
        '';
        owner = "acme";
        group = "root";
        mode = "0400";
      };
      "synapse-reg.yaml" = {
        content = ''
          registration_shared_secret: ${ph.synapse-registration-shared-secret}
        '';
        owner = "matrix-synapse";
        group = "matrix-synapse";
        mode = "0400";
      };
      "mautrix-telegram.env" = {
        content = ''
          MAUTRIX_TELEGRAM_TELEGRAM_API_ID=${ph.telegram-api-id}
          MAUTRIX_TELEGRAM_TELEGRAM_API_HASH=${ph.telegram-api-hash}
        '';
        owner = "mautrix-telegram";
        group = "mautrix-telegram";
        mode = "0400";
      };
    };
  };
}
