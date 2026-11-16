{
  inputs,
  system ? "x86_64-linux",
}:
let
  pkgs = import inputs.nixpkgs { inherit system; };
in
pkgs.testers.runNixOSTest {
  defaults = ./module.nix;
  name = "integration-test";
  node = {
    pkgsReadOnly = false;
    specialArgs = { inherit inputs; };
  };
  containers = {

    dns = { ... }: { };

    vpsfree = { lib, ... }: {
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
      networking = {
        nat.externalInterface = lib.mkForce "eth1";
        wireguard = {
          interfaces.wg0 = {
            peers = lib.mkForce [
              {
                name = "spoke";
                publicKey = builtins.readFile ./spoke.pub;
                allowedIPs = [ "10.0.0.2/32" ];
              }
            ];
          };
        };
      };
      system.activationScripts = {
        nginxCerts = lib.stringAfter ["var"] ''
          out=/var/lib/acme/idimitrov.dev
          mkdir -p $out
          cp ${./cert/key.pem} $out/key.pem
          cp ${./cert/cert.pem} $out/fullchain.pem
        '';
      };
    };

    spoke = { ... }: {
      environment.etc."systemd/network/wg0.key".source = ./spoke.priv;
      custom.wireguard = {
        enable = true;
        killswitch = true;
        ips = [ "10.0.0.2/32" ];
        privateKeyFile = "/etc/systemd/network/wg0.key";
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
  testScript = builtins.readFile ./script.py;
}
