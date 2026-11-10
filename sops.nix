{ inputs }: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];
  sops.defaultSopsFile = ./secrets/vpsfree.yaml;
  sops.secrets.acme = {
    sopsFile = ./secrets/acme.env;
    format = "dotenv";
    owner = "acme";
    group = "root";
    mode = "0400";
  };
}
