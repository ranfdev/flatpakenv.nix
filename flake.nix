{
  description = "Utilities to build a flatpak package";
  outputs = { self }:
    {
      lib = import ./flatpakenv.nix;
      templates = {
        gtk-rs = {
          path = ./examples/gtk-rs;
          description = "A flake building a flatpak package of a gtk-rs app";
        };
      };
    };
}
