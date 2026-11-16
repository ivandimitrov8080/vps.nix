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
        restartUnits = mailServices;
      };
      security-pass = {
        restartUnits = mailServices;
      };
      cloudflare-dns-api-token = { };
      synapse-registration-shared-secret = { };
      telegram-api-id = { };
      telegram-api-hash = { };
      livekit-api-key = { };
      livekit-api-secret = { };
    };
    templates =
      let
        ph = config.sops.placeholder;
      in
      {
        "radicale.users" = {
          content = ''
            ivan@idimitrov.dev:${ph.ivan-pass}
          '';
          owner = "radicale";
          group = "radicale";
        };
        "acme.env" = {
          content = ''
            CLOUDFLARE_DNS_API_TOKEN=${ph.cloudflare-dns-api-token}
          '';
          owner = "acme";
          group = "root";
        };
        "synapse-reg.yaml" = {
          content = ''
            registration_shared_secret: ${ph.synapse-registration-shared-secret}
          '';
          owner = "matrix-synapse";
          group = "matrix-synapse";
        };
        "mautrix-telegram.env" = {
          content = ''
            MAUTRIX_TELEGRAM_TELEGRAM_API_ID=${ph.telegram-api-id}
            MAUTRIX_TELEGRAM_TELEGRAM_API_HASH=${ph.telegram-api-hash}
          '';
          owner = "mautrix-telegram";
          group = "mautrix-telegram";
        };
        "livekit.yaml" = {
          content = ''
            API${ph.livekit-api-key}: ${ph.livekit-api-secret}
          '';
        };
      };
  };
}
