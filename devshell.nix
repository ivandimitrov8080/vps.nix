{ inputs, system, ... }:
let
  pkgs = import inputs.nixpkgs { inherit system; };
  testDriver = inputs.self.checks.${system}.default.driver;
  python = pkgs.python3.withPackages (
    pp: with pp; [
      ipython
      ptpython
      colorama
      remote-pdb
      junit-xml
      pydantic
      ovmfvartool
    ]
  );
in
inputs.devenv.lib.mkShell {
  inherit inputs pkgs;
  modules = [
    (
      { pkgs, config, ... }:
      {
        devenv.root = "/home/ivand/src/hosts.nix/vps.nix";
        languages = {
          python = {
            enable = true;
            package = python;
          };
        };
        packages = with pkgs; [
          (pkgs.nixos-test-driver.override {
            enableNspawn = true;
          })
          testDriver
          sops
        ];
        files = {
          "__builtins__.pyi".text = builtins.readFile (
            pkgs.runCommand "__builtins__.pyi" { nativeBuildInputs = config.packages; } ''
              export NIXOS_TEST_DRIVER_CONFIG=${testDriver.config.driverConfigurationFile}
              ${python}/bin/python ${./test/builtins.py} > $out
            ''
          );
        };
      }
    )
  ];
}
