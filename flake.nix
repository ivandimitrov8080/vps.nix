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
    # the code shared by all hosts lives in the hosts.nix repo
    # src.url = "github:ivandimitrov8080/hosts.nix?dir=src";
    src = {
      url = "git+file:///home/ivand/src/hosts.nix?dir=src";
      flake = false;
    };
    vpsadminos.url = "github:vpsfreecz/vpsadminos";
    webshite.url = "github:ivandimitrov8080/idimitrov.dev";
  };
  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      docsConfig = self.nixosConfigurations.vps;
      overlays = import (inputs.src + "/overlays.nix") { inherit inputs docsConfig; };
      nixosModules = import (inputs.src + "/modules") { inherit inputs overlays; };
    in
    {
      nixosConfigurations.vps = nixpkgs.lib.nixosSystem {
        modules = with nixosModules; [
          default
          wg
          (import ./vpsadminos.nix { inherit inputs; })
          (import ./mail.nix)
          (import ./nginx.nix { inherit inputs; })
          {
            nixpkgs.hostPlatform = "x86_64-linux";
            imports = [
              inputs.vpsadminos.nixosConfigurations.containerUnstable
            ];
            _module.args.system = "x86_64-linux";
            networking.nftables.ruleset = "";
          }
        ];
      };
    };
}
