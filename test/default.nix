{
  inputs,
  system ? "x86_64-linux",
}:
let
  pkgs = import inputs.nixpkgs { inherit system; };
in
pkgs.testers.runNixOSTest {
  defaults = ./test-module.nix;
  name = "integration-test";
  node = {
    pkgsReadOnly = false;
    specialArgs = { inherit inputs; };
  };
  nodes = {
    router = _: { };

    dns = { ... }: { };

    vpsfree = _: {
      imports = [
        ../configuration.nix
      ];
    };

    spoke = { ... }: {
      meta.wireguard.peers = {
        vpsfree = {
          ip = "10.0.0.1";
          publicKey = builtins.readFile ./vpsfree.pub;
          endpoint = "37.205.13.29:51820";
          persistentKeepalive = 7;
        };
      };
    };

    outsider = { ... }: { };
  };
  testScript = builtins.readFile ./test-script.py;
}
