{
  inputs = {
    configuration.url = "github:ivandimitrov8080/configuration.nix";
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    metronome.url = "github:ivandimitrov8080/metronome";
    neomacs.url = "github:eval-exec/neomacs";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
    in
    {
      nixosConfigurations.vps = nixpkgs.lib.nixosSystem {
        # meta.host.* reads the flake inputs from here.
        specialArgs = { inherit inputs; };
        modules = [
          inputs.configuration.nixosModules.default
          (import ./host.nix { inherit inputs; })
          (import ./vpsadminos.nix { inherit inputs; })
          (import ./mail.nix)
          (import ./nginx.nix { inherit inputs; })
          {
            imports = [
              inputs.vpsadminos.nixosConfigurations.containerUnstable
            ];
            _module.args.system = system;
          }
        ];
      };
      # integration test: uses only this flake's inputs, never another host flake
      checks.${system}.integration = (import ./test { inherit inputs system; }).integrationTest;
    };
}
