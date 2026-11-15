{
  networking = {
    nat = {
      enable = true;
      externalInterface = "venet";
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
            name = "nova";
            publicKey = "rZJ7mJl0bmfWeqpUalv69c+TxukpTaxF/SN+RyxklVA=";
            allowedIPs = [ "10.0.0.2/32" ];
          }
          {
            name = "pixel";
            publicKey = "IDe1MPtS46c2iNcE+VrOSUpOVGMXjqFl+XV5Z5U+DDI=";
            allowedIPs = [ "10.0.0.5/32" ];
          }
        ];
      };
    };
  };
}
