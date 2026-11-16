{
  pkgs,
  config,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  publicIp = config.meta.host.publicAddress;
  listenAddresses = [
    "10.0.0.1"
    publicIp
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
          environmentFile = config.sops.templates."acme.env".path;
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
    in
    {
      defaultListenAddresses = [ "10.0.0.1" ];
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
            '"upstream_response_time":"$upstream_response_time"'
          '}';
          access_log /var/log/nginx/access.json.log json_access;

          proxy_headers_hash_max_size 1024;
          proxy_headers_hash_bucket_size 128;
      '';
      virtualHosts = {
        "idimitrov.dev" = mkTlsHost {
          serverAliases = [ "www.idimitrov.dev" ];
          locations = {
            "/" = {
              root = inputs.webshite.packages.${system}.default;

              extraConfig = ''
                autoindex on;
                ${serveStatic}
              '';
            };
            "= /.well-known/matrix/client".extraConfig = ''
              default_type application/json;
              add_header Access-Control-Allow-Origin "*" always;
              return 200 '{"m.homeserver":{"base_url":"https://matrix.idimitrov.dev"}}';
            '';
            "= /.well-known/matrix/server".extraConfig = ''
              default_type application/json;
              add_header Access-Control-Allow-Origin "*" always;
              return 200 '{"m.server":"matrix.idimitrov.dev:443"}';
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
        "matrix.idimitrov.dev" = mkTlsHost {
          locations = {
            "/_matrix" = {
              proxyPass = "http://127.0.0.1:8008";
              proxyWebsockets = true;
              extraConfig = "client_max_body_size 50M;";
            };
            "/_synapse/client" = {
              proxyPass = "http://127.0.0.1:8008";
              proxyWebsockets = true;
            };
          };
        };
        "rtc.idimitrov.dev" = mkTlsHost {
          locations = {
            "^~ /livekit/jwt/" = {
              proxyPass = "http://127.0.0.1:8090/";
              extraConfig = "proxy_buffering off;";
            };
            "^~ /livekit/sfu/" = {
              proxyPass = "http://127.0.0.1:7880/";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_buffering off;
                proxy_read_timeout 86400s;
                proxy_send_timeout 86400s;
              '';
            };
          };
        };
        "element.idimitrov.dev" = mkTlsHost {
          root = pkgs.element-web;
          locations."/".extraConfig = "try_files $uri $uri/ /index.html;";
        };
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
      };
    };
}
