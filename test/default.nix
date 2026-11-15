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
      services.nginx.enable = pkgs.lib.mkForce false;
      meta.wireguard.enable = pkgs.lib.mkForce false;
      systemd.network = {
        enable = true;
        netdevs."10-wg0" = {
          netdevConfig = {
            Kind = "wireguard";
            Name = "wg0";
            Description = "Wireguard virtual device (tunnel)";
          };
          wireguardConfig = {
            PrivateKeyFile = "/etc/systemd/network/wg0.key";
            ListenPort = 51820;
          };
          wireguardPeers = [
            {
              PublicKey = builtins.readFile ./spoke.pub;
              AllowedIPs = [ "10.0.0.2/32" ];
            }
          ];
        };
        networks.wg0 = {
          matchConfig.Name = "wg0";
          networkConfig = {
            IPMasquerade = "both";
            Address = "10.0.0.1/24";
          };
        };
      };
      environment.etc."systemd/network/wg0.key" = {
        source = ./vpsfree.priv;
        user = "systemd-network";
        group = "systemd-network";
      };
    };

    spoke = { ... }: {
      environment.etc."systemd/network/wg0.key" = {
        source = ./spoke.priv;
        user = "systemd-network";
        group = "systemd-network";
      };
      systemd.network = {
        netdevs."10-wg0" = {
          netdevConfig = {
            Kind = "wireguard";
            Name = "wg0";
            Description = "Wireguard virtual network device (tunnel)";
          };
          wireguardConfig = {
            PrivateKeyFile = "/etc/systemd/network/wg0.key";
            FirewallMark = 6969;
          };
          wireguardPeers = [
            {
              PublicKey = builtins.readFile ./vpsfree.pub;
              AllowedIPs = [
                "10.0.0.1/32"
              ];
              Endpoint = "192.168.1.4:51820";
              PersistentKeepalive = 7;
            }
          ];
        };
        networks.wg0 = {
          matchConfig.Name = "wg0";
          networkConfig = {
            Address = "10.0.0.2/24";
            DNSDefaultRoute = true;
            DNS = "10.0.0.1";
            Domains = "~.";
          };
          routingPolicyRules = [
            {
              FirewallMark = 6969;
              InvertRule = true;
              Table = 1000;
              Priority = 10;
            }
            {
              To = "192.168.0.0/16";
              Priority = 5;
            }
            {
              To = "172.16.42.0/24";
              Priority = 5;
            }
          ];
          routes = [
            {
              Destination = "0.0.0.0/0";
              Table = 1000;
            }
          ];
        };
      };
    };

    outsider = { ... }: { };
  };
  testScript = builtins.readFile ./test-script.py;
}
