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
      networking.interfaces.eth1.ipv4.addresses = [
        {
          address = "37.205.13.29";
          prefixLength = 32;
        }
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
        nftables = {
          enable = true;
          ruleset = ''
            table inet killswitch {
              chain output {
                type filter hook output priority 0; policy drop;
                oifname "lo" accept
                oifname "wg0" accept
                meta mark 0x1b39 accept
                ct state established,related accept
              }
            }
          '';
        };
        wireguard = {
          enable = true;
          useNetworkd = true;
          interfaces.wg0 = {
            ips = [ "10.0.0.2/32" ];
            privateKeyFile = "/etc/systemd/network/wg0.key";
            table = "1000";
            fwMark = "0x1b39";
            peers = [
              {
                name = "vpsfree";
                publicKey = builtins.readFile ./vpsfree.pub;
                allowedIPs = [
                  "0.0.0.0/0"
                  "::/0"
                ];
                endpoint = "37.205.13.29:51820";
                persistentKeepalive = 7;
              }
            ];
          };
        };
      };
      systemd.network.networks."40-wg0".routingPolicyRules = [
        {
          FirewallMark = 6969;
          InvertRule = true;
          Table = 1000;
          Priority = 10;
        }
        {
          SuppressPrefixLength = 0;
          Table = "main";
          Priority = 20;
        }
      ];
    };

    outsider = { ... }: {
    };

    service = { ... }: {
      networking.firewall.enable = false;
      services.nginx = {
        enable = true;
        virtualHosts."service" = {
          locations."/" = {
            extraConfig = ''
              default_type text/plain;
              return 200 "$remote_addr\n";
            '';
          };
        };
      };
    };
  };
  testScript = builtins.readFile ./test-script.py;
}
