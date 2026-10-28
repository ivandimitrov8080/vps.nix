# Public wireguard data: which peers exist. Every host keeps its own copy so it
# can be deployed without knowing about the other host repositories.
{
  config,
  ...
}:
{
  meta.wireguard.peers = {
    vpsfree = {
      ip = "10.0.0.1";
      publicKey = "iRSHYRPRELX8lJ2eHdrEAwy5ZW8f5b5fOiIGhHQwKFg=";
      endpoint = "${config.meta.host.publicAddress}:51820";
      persistentKeepalive = 7;
    };
    nova = {
      ip = "10.0.0.2";
      publicKey = "rZJ7mJl0bmfWeqpUalv69c+TxukpTaxF/SN+RyxklVA=";
    };
    spoke2 = {
      ip = "10.0.0.5";
      publicKey = "IDe1MPtS46c2iNcE+VrOSUpOVGMXjqFl+XV5Z5U+DDI=";
    };
  };
}
