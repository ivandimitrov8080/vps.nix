# Integration test for the vps configuration. It lives in this flake, so it
# uses only this repository's inputs and never another host flake.
#
# The nodes are built from the same shared meta.* modules the real hosts use,
# so this test also covers configuration.nix's wireguard/dns code.
{
  inputs,
  system ? "x86_64-linux",
}:
let
  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [ inputs.configuration.overlays.default ];
  };
  inherit (pkgs) lib;
  inherit (lib) mkForce optional;

  configMod = inputs.configuration.nixosModules.default;
  vpsadminosModule = import ../vpsadminos.nix { inherit inputs; };
  mail = import ../mail.nix;
  nginx = import ../nginx.nix { inherit inputs; };

  # --- test network ------------------------------------------------------
  internetVlan = 10;
  publicVlan = 20;
  internetGw = "192.168.100.1";
  internetCidrPrefix = 24;
  publicGwIp = "37.205.13.1";
  publicCidr = "37.205.13.0";

  # "internet side" addresses
  dnsInternetIp = "192.168.100.53";
  novaInternetIp = "192.168.100.10";
  spoke2InternetIp = "192.168.100.11";
  outsiderInternetIp = "192.168.100.12";

  # wireguard side addresses
  vpsfreeWgIp = "10.0.0.1";
  novaWgIp = "10.0.0.2";
  spoke2WgIp = "10.0.0.3";
  vpsfreeInternetIp = "37.205.13.29";

  # Same shape as ../peers.nix, only with throwaway keys.
  peers = {
    vpsfree = {
      ip = vpsfreeWgIp;
      publicKey = builtins.readFile ./hub.pub;
      endpoint = "${vpsfreeInternetIp}:51820";
      persistentKeepalive = 7;
    };
    nova = {
      ip = novaWgIp;
      publicKey = builtins.readFile ./spoke1.pub;
    };
    spoke2 = {
      ip = spoke2WgIp;
      publicKey = builtins.readFile ./spoke2.pub;
    };
  };

  extraPkgs = with pkgs; [
    wireguard-tools
    dig
    curl
    inetutils
    nmap
    swaks
  ];

  testUser = {
    users = {
      users.test = {
        isNormalUser = true;
        password = "test";
        extraGroups = [
          "wheel"
          "adm"
          "mlocate"
          "ssh"
        ];
      };
      groups.ssh = { };
    };
  };

  # A node on the "internet" VLAN: one static address and a route to the
  # public subnet through the router.
  mkInternetNode =
    {
      address,
      wg ? null,
      extraModules ? [ ],
    }:
    _:
    {
      imports = [ configMod ] ++ optional (wg != null) (wgModule wg) ++ extraModules;
      virtualisation.vlans = [ internetVlan ];
      networking = {
        useNetworkd = mkForce true;
        useDHCP = mkForce false;
        enableIPv6 = mkForce false;
        interfaces.eth1.ipv4 = {
          addresses = [
            {
              inherit address;
              prefixLength = internetCidrPrefix;
            }
          ];
          routes = [
            {
              address = publicCidr;
              prefixLength = 24;
              via = internetGw;
            }
          ];
        };
      };
    }
    // testUser;

  wgModule =
    {
      self,
      ip,
      keyFile,
    }:
    {
      environment.etc."wireguard/wg0.priv".source = keyFile;
      meta.wireguard = {
        enable = true;
        inherit self;
        address = "${ip}/24";
        privateKeyFile = "/etc/wireguard/wg0.priv";
        peers = mkForce peers;
      };
    };

  # A spoken that may only talk DNS to the hub.
  dnsClient = {
    meta.dns = {
      servers = [ vpsfreeWgIp ];
      egress.restrict = true;
    };
  };

  # The authoritative dnscrypt resolver for the test (stands in for the one on
  # the real vps).
  dnsServer = {
    meta.dns = {
      servers = [ dnsInternetIp ];
      listen.address = dnsInternetIp;
      dnscrypt = {
        enable = true;
        settings = {
          offline_mode = true;
          cloaking_rules = "/etc/dnscrypt-proxy/cloaking_rules.txt";
        };
      };
    };
    environment = {
      systemPackages = extraPkgs;
      etc."dnscrypt-proxy/cloaking_rules.txt".text = ''
        *.idimitrov.dev ${vpsfreeInternetIp}
      '';
    };
    networking = {
      nftables.enable = true;
      firewall = {
        allowedTCPPorts = mkForce [ 53 ];
        allowedUDPPorts = mkForce [ 53 ];
      };
    };
  };

  outsiderDns = {
    networking.nameservers = [ dnsInternetIp ];
    services.resolved.enable = true;
    environment.systemPackages = extraPkgs;
  };
in
{
  integrationTest = pkgs.testers.runNixOSTest {
    name = "integration-test";
    nodes = {
      router =
        _:
        {
          virtualisation.vlans = [
            internetVlan
            publicVlan
          ];

          networking = {
            useNetworkd = mkForce true;
            useDHCP = mkForce false;
            enableIPv6 = mkForce false;

            # IMPORTANT: interface numbers assume:
            # eth0 = NAT, eth1 = default test LAN, eth2 = vlan 10, eth3 = vlan 20
            interfaces.eth1.ipv4.addresses = [
              {
                address = internetGw;
                prefixLength = internetCidrPrefix;
              }
            ];
            interfaces.eth2.ipv4.addresses = [
              {
                address = publicGwIp;
                prefixLength = 24;
              }
            ];

            nftables.enable = true;
            firewall.enable = false; # we'll define forward policy ourselves
            nftables.ruleset = ''
              table inet filter {
                chain forward {
                  type filter hook forward priority 0; policy drop;
                  ct state established,related accept

                  # mimic “real internet”: never forward RFC1918 WG space
                  ip daddr 10.0.0.0/24 drop

                  # allow internet <-> public
                  iifname "eth1" oifname "eth2" accept
                  iifname "eth2" oifname "eth1" accept
                }
              }
            '';
          };
          boot.kernel.sysctl."net.ipv4.ip_forward" = true;
        }
        // testUser;

      vpsfree =
        _:
        {
          _module.args.system = system;
          virtualisation = {
            memorySize = 4096;
            vlans = [ publicVlan ];
          };
          imports = [
            configMod
            vpsadminosModule
            mail
            nginx
            (wgModule {
              self = "vpsfree";
              ip = vpsfreeWgIp;
              keyFile = ./hub.priv;
            })
            {
              networking = {
                useDHCP = false;
                interfaces = {
                  eth1.ipv4.addresses = [
                    {
                      address = vpsfreeInternetIp;
                      prefixLength = 24;
                    }
                  ];
                  eth1.ipv4.routes = [
                    {
                      address = "192.168.100.0";
                      prefixLength = internetCidrPrefix;
                      via = publicGwIp;
                    }
                  ];
                };
              };
              services.dnscrypt-proxy.settings.offline_mode = true;
              security.acme.defaults = {
                email = mkForce "test@example.com";
                server = mkForce "https://acme-staging-v02.api.letsencrypt.org/directory";
              };
              environment.systemPackages = extraPkgs;
              systemd.tmpfiles.rules = [
                # directory owned by nginx
                "d /var/lib/geoip 0750 nginx nginx -"
                # copy files, owned by nginx (C+ overwrites/updates)
                "C+ /var/lib/geoip/iptoasn-asn-ipv4.mmdb 0640 nginx users - ${./dbip-asn.mmdb}"
                "C+ /var/lib/geoip/iptoasn-country-ipv4.mmdb 0640 nginx users - ${./dbip-country.mmdb}"
                "C+ /var/lib/geoip/iptoasn-asn-ipv6.mmdb 0640 nginx users - ${./dbip-asn.mmdb}"
                "C+ /var/lib/geoip/iptoasn-country-ipv6.mmdb 0640 nginx users - ${./dbip-country.mmdb}"
              ];
            }
          ];
        }
        // testUser;

      nova = mkInternetNode {
        address = novaInternetIp;
        wg = {
          self = "nova";
          ip = novaWgIp;
          keyFile = ./spoke1.priv;
        };
        extraModules = [ dnsClient ];
      };

      spoke2 = mkInternetNode {
        address = spoke2InternetIp;
        wg = {
          self = "spoke2";
          ip = spoke2WgIp;
          keyFile = ./spoke2.priv;
        };
        extraModules = [ { services.resolved.enable = true; } ];
      };

      dns = mkInternetNode {
        address = dnsInternetIp;
        extraModules = [ dnsServer ];
      };

      outsider = mkInternetNode {
        address = outsiderInternetIp;
        extraModules = [ outsiderDns ];
      };
    };

    testScript =
      # py
      ''
        def test_is_subdomain_internal(subdomain, okText):
            cmd = f"curl -H 'Host: {subdomain}.idimitrov.dev' -k https://idimitrov.dev | grep '{okText}'"
            nova.succeed(cmd)
            spoke2.succeed(cmd)
            outsider.fail(cmd)


        def test_is_subdomain_external(subdomain, okText):
            cmd = f"curl -H 'Host: {subdomain}.idimitrov.dev' -k https://idimitrov.dev | grep '{okText}'"
            nova.succeed(cmd)
            spoke2.succeed(cmd)
            outsider.succeed(cmd)


        def test_is_port_internal(port):
            cmd = lambda ip: f"nc -w1 {ip} {port}"
            nova.succeed(cmd('${vpsfreeWgIp}'))
            spoke2.succeed(cmd('${vpsfreeWgIp}'))
            outsider.fail(cmd('${vpsfreeInternetIp}'))


        start_all()
        for m in [router, dns, nova, vpsfree, spoke2, outsider]:
            m.wait_for_unit("default.target")


        for m in [dns, vpsfree]:
            m.wait_for_unit("dnscrypt-proxy.service")

        vpsfree.wait_for_unit("sshd.service")

        vpsfree.wait_until_succeeds("nslookup idimitrov.dev ${vpsfreeWgIp} | grep -F ${vpsfreeWgIp}")
        dns.wait_until_succeeds("nslookup idimitrov.dev ${dnsInternetIp} | grep -F ${vpsfreeInternetIp}")

        nova.succeed("ping -c1 ${vpsfreeWgIp}")
        spoke2.succeed("ping -c1 ${vpsfreeWgIp}")
        vpsfree.succeed("ping -c1 ${novaWgIp}")
        vpsfree.succeed("ping -c1 ${spoke2WgIp}")
        nova.succeed("ping -c1 ${spoke2WgIp}")
        spoke2.succeed("ping -c1 ${novaWgIp}")
        vpsfree.succeed("ip a | grep ${vpsfreeInternetIp}")
        nova.succeed("ping -c1 ${vpsfreeInternetIp}")

        nova.succeed("nslookup idimitrov.dev ${vpsfreeWgIp}")
        nova.fail("nslookup idimitrov.dev ${dnsInternetIp}")
        outsider.succeed("nslookup idimitrov.dev ${dnsInternetIp}")
        outsider.fail("nslookup idimitrov.dev ${vpsfreeWgIp}")


        homeOk = "grep 'Home'"
        nova.succeed("curl http://idimitrov.dev | grep -o '301'")
        nova.succeed(f"curl -k https://idimitrov.dev | {homeOk}")

        outsider.succeed("curl http://idimitrov.dev | grep -o '301'")
        outsider.succeed(f"curl -k https://idimitrov.dev | {homeOk}")

        test_is_subdomain_internal("mail", "Roundcube Webmail")
        test_is_subdomain_internal("dav", "Redirected to /.web")
        test_is_subdomain_internal("rspamd", "Rspamd Web Interface")

        test_is_subdomain_external("metronome", "Metronome")
        test_is_subdomain_external("pic", "Index of /")

        test_is_port_internal(22)
        test_is_port_internal(993) # imaps
        test_is_port_internal(465) # smtps

        vpsfree.succeed("swaks --server localhost --quit-after EHLO --to a --protocol SSMTP | rg AUTH")
        vpsfree.fail("swaks --server localhost --quit-after EHLO --to a --protocol SMTP | rg AUTH")
      '';
  };
}
