{
  inputs = {
    configuration.url = "git://idimitrov.dev/configuration.nix";
    nixpkgs.url = "git://idimitrov.dev/nixpkgs?ref=nixos-unstable";
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    metronome.url = "github:ivandimitrov8080/metronome";
    simple-nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vpsadminos.url = "github:vpsfreecz/vpsadminos";
    webshite.url = "github:ivandimitrov8080/idimitrov.dev";
  };
  outputs =
    inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";

      host = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          inputs.configuration.nixosModules.default
          (import ./host.nix { inherit inputs; })
          (import ./vpsadminos.nix { inherit inputs; })
          (import ./mail.nix)
          (import ./comms.nix)
          (import ./nginx.nix { inherit inputs; })
          {
            imports = [
              inputs.vpsadminos.nixosConfigurations.containerUnstable
            ];
            _module.args.system = system;
            nixpkgs = {
              hostPlatform = system;
              overlays = [
                inputs.emacs-overlay.overlays.default
                inputs.configuration.overlays.default
              ];
            };
          }
        ];
      };
      inherit ((import ./test { inherit inputs system; })) integrationTest;
    in
    {
      nixosConfigurations.default = host;
      nixosConfigurations.vpsfree = host;

      checks.${system} = {
        default = integrationTest;
      };
    };
}
