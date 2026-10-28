{ inputs }:
{
  pkgs,
  config,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  publicIp = config.meta.host.publicAddress;
  listenAddresses = [
    "10.0.0.1"
    publicIp
  ];
  geoipFiles = [
    "iptoasn-asn-ipv4"
    "iptoasn-country-ipv4"
    "iptoasn-asn-ipv6"
    "iptoasn-country-ipv6"
  ];
in
{
  security = {
    acme = {
      acceptTerms = true;
      defaults.email = "security@idimitrov.dev";
      certs = {
        "idimitrov.dev" = {
          extraDomainNames = [ "*.idimitrov.dev" ];
          dnsProvider = "cloudflare";
          dnsResolver = "1.1.1.1:53";
          group = "nginx";
          environmentFile = "/var/lib/acme/env";
        };
      };
    };
  };
  services.nginx =
    let
      tls = {
        enableACME = false;
        forceSSL = true;
        acmeRoot = null;
        sslCertificate = "/var/lib/acme/idimitrov.dev/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/idimitrov.dev/key.pem";
      };
      mkTlsHost = extra: tls // { inherit listenAddresses; } // extra;
      serveStatic = "try_files ${
        pkgs.lib.strings.concatStringsSep " " (
          map (x: "$uri.${x}") [
            "html"
            "txt"
            "png"
            "jpg"
            "jpeg"
            "iso"
          ]
        )
      } $uri $uri/ =404;";
      geoip2Block = file: body: ''
        geoip2 /var/lib/geoip/${file}.mmdb {
          auto_reload 5m;
          ${body}
        }
      '';
    in
    {
      defaultListenAddresses = [ "10.0.0.1" ];
      additionalModules = with pkgs.nginxModules; [ geoip2 ];
      commonHttpConfig = ''
        log_format json_access escape=json
          '{'
            '"time":"$time_iso8601",'
            '"remote_addr":"$remote_addr",'
            '"x_forwarded_for":"$proxy_add_x_forwarded_for",'
            '"request_method":"$request_method",'
            '"request_uri":"$request_uri",'
            '"query_string":"$query_string",'
            '"status":"$status",'
            '"bytes_sent":"$body_bytes_sent",'
            '"request_time":"$request_time",'
            '"host":"$host",'
            '"server_name":"$server_name",'
            '"scheme":"$scheme",'
            '"protocol":"$server_protocol",'
            '"referer":"$http_referer",'
            '"user_agent":"$http_user_agent",'
            '"upstream_addr":"$upstream_addr",'
            '"upstream_status":"$upstream_status",'
            '"upstream_response_time":"$upstream_response_time",'
            '"asn":"$geoip2_asn",'
            '"as_org":"$geoip2_asorg",'
            '"geoip_country_code":"$geoip2_country_code"'
          '}';
          access_log /var/log/nginx/access.json.log json_access;

          ${geoip2Block "iptoasn-country-ipv4" "$geoip2_country_code  default=-  source=$remote_addr country iso_code;"}
          ${geoip2Block "iptoasn-asn-ipv4" ''
            $geoip2_asn   default=-  autonomous_system_number;
            $geoip2_asorg default=-  autonomous_system_organization;
          ''}
          ${geoip2Block "iptoasn-country-ipv6" "$geoip2_country_code  default=-  source=$remote_addr country iso_code;"}
          ${geoip2Block "iptoasn-asn-ipv6" ''
            $geoip2_asn   default=-  autonomous_system_number;
            $geoip2_asorg default=-  autonomous_system_organization;
          ''}
          proxy_headers_hash_max_size 1024;
          proxy_headers_hash_bucket_size 128;
      '';
      virtualHosts = {
        "idimitrov.dev" = mkTlsHost {
          serverAliases = [ "www.idimitrov.dev" ];
          locations."/" = {
            root = inputs.webshite.packages.${system}.default;

            extraConfig = ''
              autoindex on;
              ${serveStatic}
            '';
          };
        };
        "pic.idimitrov.dev" = mkTlsHost {
          locations."/" = {
            root = "/var/pic";
            extraConfig = ''
              autoindex on;
            '';
          };
        };
        "metronome.idimitrov.dev" = mkTlsHost {
          locations."/" = {
            root = inputs.metronome.packages.${system}.default;

            extraConfig = ''
              autoindex on;
            '';
          };
        };
        "mail.idimitrov.dev" = tls;
        "dav.idimitrov.dev" = tls // {
          locations."/" = {
            proxyPass = "http://127.0.0.1:5232/";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_pass_header Authorization;
            '';
          };
          locations."= /.well-known/caldav".return = "301 https://dav.idimitrov.dev/";
          locations."= /.well-known/carddav".return = "301 https://dav.idimitrov.dev/";
        };
        "rspamd.idimitrov.dev" = tls // {
          locations."/".proxyPass = "http://unix:/run/rspamd/worker-controller.sock:/";
        };
      };
    };
  systemd = {
    services.update-geoip =
      let
        outDir = "/var/lib/geoip";
        url = "https://github.com/sapics/ip-location-db/releases/download/latest";
        exec =
          pkgs.writers.writeNuBin "exec"
            # nu
            ''
              ${pkgs.lib.concatMapStringsSep "\n" (
                file:
                ''http get --raw --max-time 69min $"${url}/${file}.mmdb" | save --raw -f $"${outDir}/${file}.mmdb"''
              ) geoipFiles}
            '';
      in
      {
        description = "Update GEOIP database from https://github.com/sapics/ip-location-db";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ReadWritePaths = [ outDir ];
          ExecStart = "${exec}/bin/exec";
        };
      };
    timers = {
      update-geoip = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 10:00:00";
          Persistent = true;
        };
      };
    };
  };
}
