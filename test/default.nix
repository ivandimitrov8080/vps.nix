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
  containers = {

    dns = { ... }: { };

    vpsfree = _: {
      imports = [
        ../configuration.nix
      ];
    };

    spoke = { ... }: {
    };

    outsider = { ... }: { };
  };
  testScript = builtins.readFile ./test-script.py;
}
