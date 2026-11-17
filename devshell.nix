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
      { pkgs, ... }:
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
          ruff
        ];
        files =
          let
            withTypes =
              drv:
              drv.overrideAttrs (old: {
                buildCommand = ''
                  ${old.buildCommand}
                  mkdir -p $out
                  cp "$NIX_BUILD_TOP/testScriptWithTypes" $out/testScriptWithTypes
                  test_len=$(cat $out/test-script | wc -l)
                  types_len=$(cat $out/testScriptWithTypes | wc -l)
                  only_types_len=$((types_len - test_len))
                  head -n $only_types_len $out/testScriptWithTypes > $out/types
                '';
              });
            driver = withTypes inputs.self.checks.${system}.default.driver;
          in
          {
            "__builtins__.pyi".text = ''
              # ruff: noqa
              ${builtins.readFile "${driver}/types"}
            '';
          };
      }
    )
  ];
}
