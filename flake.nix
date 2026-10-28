{
  inputs = {
    configuration.url = "github:ivandimitrov8080/configuration.nix";
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    metronome.url = "github:ivandimitrov8080/metronome";
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

      host = nixpkgs.lib.nixosSystem {
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
    in
    {
      nixosConfigurations.default = host;

      checks.${system} = {
        default = nixpkgs.legacyPackages.${system}.runCommand "eval-vps" { } ''
          echo ${builtins.unsafeDiscardStringContext host.config.system.build.toplevel.drvPath} > $out
        '';

        # integration test: uses only this flake's inputs, never another host flake
        integration = (import ./test { inherit inputs system; }).integrationTest;
      };
    };
}
