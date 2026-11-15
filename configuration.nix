{ inputs, ... }:
{
  imports = [
    inputs.configuration.nixosModules.default
    inputs.sops-nix.nixosModules.sops

    ./mail.nix
    ./host.nix
    ./sops.nix
    ./comms.nix
    ./nginx.nix
    ./vpsadminos.nix
  ];
  nixpkgs = {
    hostPlatform = "x86_64-linux";
    overlays = [
      inputs.configuration.overlays.default
    ];
  };
}
