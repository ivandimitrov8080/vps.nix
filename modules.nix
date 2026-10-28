# NixOS modules for the vps. Kept local to this flake (it used to live in
# hosts.nix/src) so vps.nix evaluates on its own.
{
  inputs,
  hostOverlays ? [ ],
}:
let
  system = "x86_64-linux";
  dns = "10.0.0.1";
  peers = [
    {
      PublicKey = "iRSHYRPRELX8lJ2eHdrEAwy5ZW8f5b5fOiIGhHQwKFg=";
      AllowedIPs = [
        "0.0.0.0/0"
        "10.0.0.1/32"
      ];
      Endpoint = "37.205.13.29:51820";
      PersistentKeepalive = 7;
    }
    {
      PublicKey = "rZJ7mJl0bmfWeqpUalv69c+TxukpTaxF/SN+RyxklVA=";
      AllowedIPs = [ "10.0.0.2/32" ];
    }
    {
      PublicKey = "IDe1MPtS46c2iNcE+VrOSUpOVGMXjqFl+XV5Z5U+DDI=";
      AllowedIPs = [ "10.0.0.5/32" ];
    }
  ];
in
{
  default =
    { pkgs, ... }:
    {
      imports = [ inputs.configuration.nixosModules.default ];
      nix.registry = {
        self.flake = inputs.self;
        nixpkgs.flake = inputs.nixpkgs;
        p.flake = inputs.nixpkgs;
      };
      nixpkgs = {
        hostPlatform = system;
        overlays = hostOverlays ++ [
          inputs.configuration.overlays.default
          inputs.emacs-overlay.overlays.default
        ];
      };
      system.stateVersion = pkgs.lib.trivial.release;
      users.defaultUserShell = pkgs.nushell;
    };
  wg = { ... }: {
    meta.wireguard = {
      inherit peers dns;
    };
    networking.nameservers = [ dns ];
    services.resolved = {
      settings = {
        Resolve = {
          FallbackDNS = [ dns ];
        };
      };
    };
  };
}
