{... }: {
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
}
