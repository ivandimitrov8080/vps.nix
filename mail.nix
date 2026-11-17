{
  config,
  lib,
  options,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption optionalAttrs;
  cfg = config.meta.mail;
  hasMailserver = options ? mailserver;
in
{
  options.meta.mail = {
    enable = mkEnableOption "enable mailserver config";
  };
  config = mkIf cfg.enable (
    optionalAttrs hasMailserver {
      mailserver = {
        stateVersion = 3;
        enable = true;
        localDnsResolver = false;
        lmtpSaveToDetailMailbox = false;
        fqdn = "idimitrov.dev";
        domains = [
          "idimitrov.dev"
          "mail.idimitrov.dev"
        ];
        accounts = {
          "ivan@idimitrov.dev" = {
            passwordFile = "/run/secrets/ivan-pass";
            aliases = [ "admin@idimitrov.dev" ];
          };
          "security@idimitrov.dev" = {
            passwordFile = "/run/secrets/security-pass";
          };
        };
        x509 = {
          certificateFile = "/var/lib/acme/idimitrov.dev/fullchain.pem";
          privateKeyFile = "/var/lib/acme/idimitrov.dev/key.pem";
        };
        hierarchySeparator = "/";
      };
      services = {
        postfix.settings = {
          main = {
            smtpd_sasl_auth_enable = lib.mkForce "no";
            inet_protocols = "ipv4";
          };
          master.submissions_inet.args = [
            "-o"
            "smtpd_sasl_auth_enable=yes"
          ];
        };
        rspamd.locals."worker-controller.inc".text = ''
          secure_ip = [ "10.0.0.0/24" ];
        '';
      };
    }
  );
}
