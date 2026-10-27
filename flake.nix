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
    {
      # hosts.nix passes in its shared tree (src) and the config to take the
      # nixos option docs from, so nothing has to be duplicated here
      mkHost =
        { src, docsConfig }:
        let
          overlays = import (src + "/overlays.nix") { inherit inputs docsConfig; };
          nixosModules = import (src + "/modules") { inherit inputs overlays; };
        in
        nixpkgs.lib.nixosSystem {
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
