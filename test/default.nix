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
      environment.etc."systemd/network/wg0.key".source = ./vpsfree.priv;
      services.nginx.enable = pkgs.lib.mkForce false;
      meta.wireguard.enable = pkgs.lib.mkForce false;
      networking = {
        nat = {
          enable = true;
          externalInterface = "eth1";
          internalInterfaces = [ "wg0" ];
        };
        wireguard = {
          enable = true;
          useNetworkd = true;
          interfaces.wg0 = {
            ips = [ "10.0.0.1/32" ];
            listenPort = 51820;
            privateKeyFile = "/etc/systemd/network/wg0.key";
            peers = [
              {
                name = "spoke";
                publicKey = builtins.readFile ./spoke.pub;
                allowedIPs = [ "10.0.0.2/32" ];
              }
            ];
          };
        };
      };
    };

    spoke = { ... }: {
      environment.etc."systemd/network/wg0.key".source = ./spoke.priv;
      networking = {
        wireguard = {
          enable = true;
          useNetworkd = true;
          interfaces.wg0 = {
            ips = [ "10.0.0.2/32" ];
            privateKeyFile = "/etc/systemd/network/wg0.key";
            peers = [
              {
                name = "vpsfree";
                publicKey = builtins.readFile ./vpsfree.pub;
                allowedIPs = [ "10.0.0.1/32" ];
                endpoint = "192.168.1.4:51820";
                persistentKeepalive = 7;
              }
            ];
          };
        };
      };
    };

    outsider = { ... }: { };
  };
  testScript = builtins.readFile ./test-script.py;
}
