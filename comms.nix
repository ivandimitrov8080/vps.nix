{ config, ... }: {
  # NOTE: only used for End to bridge encryption meaning VPS can't see messages if compromised
  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
  ];
  services = {
    matrix-synapse = {
      enable = true;
      settings = {
        server_name = "idimitrov.dev";
        public_baseurl = "https://matrix.idimitrov.dev";
        experimental_features = {
          msc4143_enabled = true; # MatrixRTC + MSC4519 transports endpoint
          msc4222_enabled = true; # sync v2 state_after
        };
        max_event_delay_duration = "24h";
        rc_message = {
          per_second = 0.5;
          burst_count = 30;
        };
        rc_delayed_event_mgmt = {
          per_second = 1;
          burst_count = 20;
        };
        matrix_rtc.transports = [
          {
            type = "livekit";
            livekit_service_url = "https://rtc.idimitrov.dev/livekit/jwt";
          }
        ];
      };
      extraConfigFiles = [ config.sops.templates."synapse-reg.yaml".path ];
    };
    livekit = {
      enable = true;
      keyFile = config.sops.templates."livekit.yaml".path;
      settings = {
        room.auto_create = false;
        turn = {
          enabled = true;
          domain = "rtc.idimitrov.dev";
          udp_port = 5349;
          tls_port = 5349;
          cert_file = "/run/credentials/livekit.service/turn.crt";
          key_file = "/run/credentials/livekit.service/turn.key";
        };
        rtc = {
          node_ip = "37.205.13.29";
          tcp_port = 7881;
          port_range_start = 50000;
          port_range_end = 51000;
          use_external_ip = false;
        };
      };
    };
    lk-jwt-service = {
      enable = true;
      port = 8090;
      keyFile = config.sops.templates."livekit.yaml".path;
      livekitUrl = "wss://rtc.idimitrov.dev/livekit/sfu";
    };
    mautrix-telegram = {
      enable = true;
      environmentFile = config.sops.templates."mautrix-telegram.env".path;
      settings = {
        homeserver = {
          address = "http://localhost:8008";
          domain = "idimitrov.dev";
        };
        bridge.permissions = {
          "@ivan:idimitrov.dev" = "admin";
        };
      };
    };
  };
  systemd.services.livekit.serviceConfig.LoadCredential = [
    "turn.crt:/var/lib/acme/idimitrov.dev/fullchain.pem"
    "turn.key:/var/lib/acme/idimitrov.dev/key.pem"
  ];
  systemd.services.lk-jwt-service.environment.LIVEKIT_FULL_ACCESS_HOMESERVERS = "idimitrov.dev";
}
