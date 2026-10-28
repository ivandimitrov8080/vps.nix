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
      modules = import ./modules.nix { inherit inputs; };
    in
    {
      nixosConfigurations.vps = nixpkgs.lib.nixosSystem {
        modules = [
          modules.default
          modules.wg
          (import ./vpsadminos.nix { inherit inputs; })
          (import ./mail.nix)
          (import ./nginx.nix { inherit inputs; })
          {
            nixpkgs.hostPlatform = system;
            imports = [
              inputs.vpsadminos.nixosConfigurations.containerUnstable
            ];
            _module.args.system = system;
            networking.nftables.ruleset = "";
          }
        ];
      };
      # integration test: uses only this flake's inputs, never another host flake
      checks.${system}.integration = (import ./test { inherit inputs system; }).integrationTest;
    };
}
