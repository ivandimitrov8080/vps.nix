{ inputs, ... }: {
  nixpkgs = {
    hostPlatform = "x86_64-linux";
    overlays = [
      inputs.configuration.overlays.default
    ];
  };
}
