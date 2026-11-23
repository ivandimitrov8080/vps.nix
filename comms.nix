{ config, pkgs, ... }: {
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
    mautrix.bridges.telegram = {
      type = "telegram";
      package = pkgs.mautrix-telegram.override { withGoolm = true; };
      environmentFiles = [ config.sops.templates."mautrix-telegram.env".path ];
      settings = {
        logging = {
          min_level = "debug";
        };
        backfill = {
          enabled = true;
          max_initial_messages = 100;
          max_catchup_messages = 500;
          unread_hours_threshold = 720;
          threads.max_initial_messages = 50;
        };
        network = {
          sync = {
            update_limit = 100;
            create_limit = 15;
            direct_chats = true;
          };
          takeout = {
            forward_backfill = true;
          };
        };
        homeserver = {
          address = "http://localhost:8008";
          domain = "idimitrov.dev";
        };
        bridge.permissions = {
          "@ivan:idimitrov.dev" = "admin";
        };
      };
    };
    matrix-appservice-irc = {
      enable = true;
      registrationUrl = "localhost";

      settings = {
        homeserver.url = "https://matrix.idimitrov.dev";
        homeserver.domain = "idimitrov.dev";

        ircService.servers."libera.chat" = {
          name = "libera.chat";
          port = 6697;
          ssl = true;
          dynamicChannels = {
            enabled = true;
            aliasTemplate = "#irc_$CHANNEL";
          };
          matrixClients = {
            userTemplate = "@irc_$NICK";
          };
          ircClients = {
            nickTemplate = "$LOCALPART[m]";
            allowNickChanges = true;
          };

          membershipLists = {
            enabled = true;
            global = {
              ircToMatrix = {
                initial = true;
                incremental = true;
              };
              matrixToIrc = {
                initial = true;
                incremental = true;
              };
            };
          };
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
