# Integration test for the vps configuration. It lives in this flake, so it
# uses only this repository's inputs and never another host flake.
{ inputs, system ? "x86_64-linux" }:
let
  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [ inputs.configuration.overlays.default ];
  };
  inherit (pkgs) lib;
  inherit (lib) mkForce;
  configMod = inputs.configuration.nixosModules.default;
  vpsadminosModule = import ../vpsadminos.nix { inherit inputs; };
  mail = import ../mail.nix;
  nginx = import ../nginx.nix { inherit inputs; };
  hubPub = builtins.readFile ./hub.pub;
  spoke1Pub = builtins.readFile ./spoke1.pub;
  spoke2Pub = builtins.readFile ./spoke2.pub;
  peers = [
    {
      PublicKey = hubPub;
      AllowedIPs = [
        "${vpsfreeWgIp}/32"
        "0.0.0.0/0"
      ];
      Endpoint = "${vpsfreeInternetIp}:51820";
    }
    {
      PublicKey = spoke1Pub;
      AllowedIPs = [ "${novaWgIp}/32" ];
    }
    {
      PublicKey = spoke2Pub;
      AllowedIPs = [ "${spoke2WgIp}/32" ];
    }
  ];
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
      users = {
        test = {
          isNormalUser = true;
          password = "test";
          extraGroups = [
            "wheel"
            "adm"
            "mlocate"
            "ssh"
          ];
        };
      };
      groups = {
        ssh = { };
      };
    };
  };
  blockDnsExceptDnscrypt = ''
    table inet filter {
      chain output {
        type filter hook output priority 0; policy accept;

        meta oifname "lo" accept

        # Allow dns to server
        ip daddr ${vpsfreeWgIp} udp dport 53 accept
        ip daddr ${vpsfreeWgIp} tcp dport 53 accept

        # Block DNS to anywhere else
        udp dport 53 drop
        tcp dport 53 drop
        tcp dport 853 drop
      }
    }
  '';
  vpsfreeWgIp = "10.0.0.1";
  novaWgIp = "10.0.0.2";
  spoke2WgIp = "10.0.0.3";
  vpsfreeInternetIp = "37.205.13.29";
  internetVlan = 10;
  publicVlan = 20;
  internetGw = "192.168.100.1";
  internetCidrPrefix = 24;
  # “internet side” IPs
  dnsInternetIp = "192.168.100.53";
  novaInternetIp = "192.168.100.10";
  spoke2InternetIp = "192.168.100.11";
  outsiderInternetIp = "192.168.100.12";
  # “public side” router IP (same subnet as vpsfreeIp)
  publicGwIp = "37.205.13.1";
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
            firewall.enable = false; # we’ll define forward policy ourselves
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
          virtualisation.memorySize = 4096;
          imports = [
            configMod
            vpsadminosModule
            mail
            nginx
          ];
          virtualisation.vlans = [ publicVlan ];
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
          environment.etc."wireguard/wg0.priv".source = ./hub.priv;
          services.dnscrypt-proxy.settings.offline_mode = true;
          meta.wireguard = {
            enable = true;
            address = "${vpsfreeWgIp}/24";
            privateKeyFile = "/etc/wireguard/wg0.priv";
            peers = mkForce peers;
          };
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
        // testUser;
      nova =
        _:
        {
          imports = [
            configMod
          ];
          boot.consoleLogLevel = mkForce 7;
          virtualisation.vlans = [ internetVlan ];
          networking.useNetworkd = mkForce true;
          networking.useDHCP = mkForce false;
          networking.enableIPv6 = mkForce false;
          networking.nameservers = [ vpsfreeWgIp ];
          networking.nftables = {
            enable = true;
            ruleset = mkForce blockDnsExceptDnscrypt;
          };
          networking.interfaces.eth1.ipv4 = {
            addresses = [
              {
                address = novaInternetIp;
                prefixLength = internetCidrPrefix;
              }
            ];
            routes = [
              {
                address = "37.205.13.0";
                prefixLength = 24;
                via = internetGw;
              }
            ];
          };
          services.resolved = {
            enable = true;
            settings.Resolve.FallbackDNS = [ vpsfreeWgIp ];
          };
          environment.etc."wireguard/wg0.priv".source = ./spoke1.priv;
          meta.wireguard = {
            enable = true;
            address = "${novaWgIp}/24";
            privateKeyFile = "/etc/wireguard/wg0.priv";
            peers = mkForce peers;
          };
          environment.systemPackages = extraPkgs;
        }
        // testUser;
      spoke2 =
        _:
        {
          imports = [ configMod ];
          environment.etc."wireguard/wg0.priv".source = ./spoke2.priv;
          virtualisation.vlans = [ internetVlan ];
          networking.useNetworkd = mkForce true;
          networking.useDHCP = mkForce false;
          networking.enableIPv6 = mkForce false;
          networking.interfaces.eth1.ipv4.addresses = [
            {
              address = spoke2InternetIp;
              prefixLength = internetCidrPrefix;
            }
          ];
          networking.interfaces.eth1.ipv4.routes = [
            {
              address = "37.205.13.0";
              prefixLength = 24;
              via = internetGw;
            }
          ];
          services.resolved.enable = true;
          meta.wireguard = {
            enable = true;
            address = "${spoke2WgIp}/24";
            privateKeyFile = "/etc/wireguard/wg0.priv";
            peers = mkForce peers;
          };
          environment.systemPackages = extraPkgs;
        }
        // testUser;
      dns =
        _:
        {
          _module.args.system = system;
          imports = [
            configMod
          ];
          virtualisation.vlans = [ internetVlan ];
          networking.useNetworkd = mkForce true;
          networking.useDHCP = mkForce false;
          networking.enableIPv6 = mkForce false;
          networking.interfaces.eth1.ipv4.addresses = [
            {
              address = dnsInternetIp;
              prefixLength = internetCidrPrefix;
            }
          ];
          networking.interfaces.eth1.ipv4.routes = [
            {
              address = "37.205.13.0";
              prefixLength = 24;
              via = internetGw;
            }
          ];
          meta.dnscrypt.enable = true;
          services.dnscrypt-proxy.settings = {
            offline_mode = true;
            listen_addresses = [ "${dnsInternetIp}:53" ];
            cloaking_rules = "/etc/dnscrypt-proxy/cloaking_rules.txt";
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
              allowedTCPPorts = mkForce [
                53
              ];
              allowedUDPPorts = mkForce [
                53
              ];
            };
          };
        }
        // testUser;
      outsider =
        _:
        {
          virtualisation.vlans = [ internetVlan ];
          networking.interfaces.eth1.ipv4.addresses = [
            {
              address = outsiderInternetIp;
              prefixLength = internetCidrPrefix;
            }
          ];
          networking.interfaces.eth1.ipv4.routes = [
            {
              address = "37.205.13.0";
              prefixLength = 24;
              via = internetGw;
            }
          ];
          environment.systemPackages = extraPkgs;
          networking = {
            useNetworkd = true;
            useDHCP = false;
            enableIPv6 = false;
            nameservers = [
              dnsInternetIp
            ];
          };
          services.resolved.enable = true;
        }
        // testUser;
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
