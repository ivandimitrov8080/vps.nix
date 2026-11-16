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
          gnupg
        ];
        files = {
          "__builtins__.pyi".text = builtins.readFile (
            pkgs.runCommand "__builtins__.pyi" { nativeBuildInputs = config.packages; } ''
              export NIXOS_TEST_DRIVER_CONFIG=${testDriver.config.driverConfigurationFile}
              ${python}/bin/python ${./dev/builtins.py} > $out
            ''
          );
          "test/vpsfree.yaml" = {
            copyMode = "copy";
            text = builtins.readFile (
              pkgs.runCommand "vpsfree-test.yaml" { nativeBuildInputs = config.packages; } ''
                export GNUPGHOME=$(mktemp -d)
                export HOME=$PWD
                gpg --batch --quiet --import ${./test/gnupg.asc}
                gpg --batch --list-secret-keys
                ${python}/bin/python ${./dev/sops-test.py} ${./secrets/vpsfree.yaml} ${./test/.sops.yaml} > $out
              ''
            );
          };
        };
      }
    )
  ];
}
