{ inputs, pkgs, ... }: {
  imports = [ inputs.configuration.nixosModules.default ];
  networking.interfaces.eth1.ipv4.routes = [
    {
      address = "37.205.13.29";
      prefixLength = 32;
      # Change this when adding new machines cuz ip changes
      via = "192.168.1.5";
      options.scope = "global";
    }
  ];
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
  environment.systemPackages = with pkgs; [
    swaks
    wireguard-tools
    dig
    curl
    inetutils
    nmap
    ripgrep
  ];
  networking.useHostResolvConf = false;
  networking.enableIPv6 = false;
}
