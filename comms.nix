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
  };
}
