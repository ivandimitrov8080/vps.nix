{ inputs, system, ... }:
let
  pkgs = import inputs.nixpkgs { inherit system; };
  testDriver = inputs.self.checks.${system}.default.driver;
in
inputs.devenv.lib.mkShell {
  inherit inputs pkgs;
  modules = [
    (
      { pkgs, ... }:
      {
        devenv.root = "/home/ivand/src/hosts.nix/vps.nix";
        languages = {
          python = {
            enable = true;
            package = pkgs.python3.withPackages (pp: with pp; [ ipython ]);
          };
        };
        packages = [
          (pkgs.nixos-test-driver.override {
            enableNspawn = true;
          })
          testDriver
        ];
        env.NIXOS_TEST_DRIVER_CONFIG = testDriver.driverConfigurationFile;
      }
    )
  ];
}
