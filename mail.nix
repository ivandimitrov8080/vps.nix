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
            hashedPassword = "$2b$05$vJqQ.9lIoTig62sNKmBSVOJK0BQ6jq.dVZZxFEI3.9yQpb23Xgake";
            aliases = [ "admin@idimitrov.dev" ];
          };
          "security@idimitrov.dev" = {
            hashedPassword = "$2b$05$vJqQ.9lIoTig62sNKmBSVOJK0BQ6jq.dVZZxFEI3.9yQpb23Xgake";
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
        roundcube = rec {
          enable = true;
          hostName = "mail.idimitrov.dev";
          extraConfig = ''
            $config['imap_host'] = 'ssl://${hostName}:993';
            $config['smtp_host'] = "ssl://${hostName}:465";
            $config['smtp_user'] = "%u";
            $config['smtp_pass'] = "%p";
          '';
        };
        rspamd.locals."worker-controller.inc".text = ''
          secure_ip = [ "10.0.0.0/24" ];
        '';
        postgresql.enable = true;
      };
    }
  );
}
