{
  inputs = {
    configuration.url = "git://idimitrov.dev/configuration.nix";
    nixpkgs.url = "git://idimitrov.dev/nixpkgs?ref=nixos-unstable";
    vpsadminos = {
      url = "github:vpsfreecz/vpsadminos";
      inputs.nixpkgsUnstable.follows = "nixpkgs";
    };
    simple-nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    metronome = {
      url = "github:ivandimitrov8080/metronome";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    webshite = {
      url = "github:ivandimitrov8080/idimitrov.dev";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";
      host = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          inputs.vpsadminos.nixosConfigurations.containerUnstable
          ./configuration.nix
        ];
      };
    in
    {
      nixosConfigurations.default = host;
      nixosConfigurations.vpsfree = host;

      checks.${system}.default = import ./test { inherit inputs; };
      devShells.${system}.default = import ./devshell.nix { inherit inputs system; };
    };
}
