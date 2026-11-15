{ inputs, pkgs, ... }: {
  imports = [ inputs.configuration.nixosModules.default ];
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
