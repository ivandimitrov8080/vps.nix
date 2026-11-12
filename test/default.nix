{
  inputs,
  system ? "x86_64-linux",
}:
let
  pkgs = import inputs.nixpkgs { inherit system; };
in
pkgs.testers.runNixOSTest (
  { config, ... }: {
    defaults = ./test-module.nix;
    name = "integration-test";
    node = {
      pkgsReadOnly = false;
      specialArgs = { inherit inputs; };
    };
    containers = {
      router = _: { };

      vpsfree = _: {
        imports = [
          ../configuration.nix
          ./test-module.nix
        ];
      };

      spoke = { ... }: { };

      dns = { ... }: { };

      outsider = { ... }: { };
    };
    testScript = builtins.readFile ./test-script.py;
    passthru.driverConfigurationFile = config.driverConfigurationFile;
  }
)
