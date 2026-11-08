{ ... }: {
  services = {
    matrix-synapse = {
      enable = true;
      settings = {
        server_name = "idimitrov.dev";
        public_baseurl = "https://matrix.idimitrov.dev";
      };
      extraConfigFiles = [ "/etc/matrix/synapse-secrets.yaml" ];
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
}
