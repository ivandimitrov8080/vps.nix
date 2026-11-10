{ ... }: {
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
      extraConfigFiles = [ "/etc/matrix/synapse-secrets.yaml" ];
    };
    livekit = {
      enable = true;
      keyFile = "/etc/matrix/livekit-keys.yaml";
      settings = {
        port = 7880;
        rtc = {
          port_range_start = 50000;
          port_range_end = 51000;
          use_external_ip = true;
          room.auto_create = false;
        };
      };
    };
    lk-jwt-service = {
      enable = true;
      port = 8090;
      keyFile = "/etc/matrix/livekit-keys.yaml";
      livekitUrl = "wss://rtc.idimitrov.dev/livekit/sfu";
    };
    mautrix-telegram = {
      enable = true;
      environmentFile = "/etc/matrix/mautrix-telegram.env";
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
  systemd.services.lk-jwt-service.environment.LIVEKIT_FULL_ACCESS_HOMESERVERS = "idimitrov.dev";
}
