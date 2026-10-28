# Everything host specific about the VPS: its wireguard identity and the DNS
# server it hosts. Shared code lives in configuration.nix's
# meta.{host,wireguard,dns} modules.
_:
{
  ...
}:
{
  imports = [ ./peers.nix ];

  meta = {
    host = {
      stateVersion = "26.05";
      publicAddress = "37.205.13.29";
    };

    wireguard = {
      enable = true;
      self = "vpsfree";
      address = "10.0.0.1/24";
    };

    dns = {
      servers = [ "10.0.0.1" ];
      listen.address = "10.0.0.1";
      dnscrypt.enable = true;
    };
  };
}
