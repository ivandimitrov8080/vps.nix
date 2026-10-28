# Everything host specific about the VPS: overlays, wireguard identity and the
# DNS server it hosts. Shared code lives in configuration.nix's
# meta.{host,wireguard,dns} modules.
{ inputs }:
{
  ...
}:
{
  imports = [ ./peers.nix ];

  meta = {
    host.overlays = [ inputs.emacs-overlay.overlays.default ];

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
