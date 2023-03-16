{
  description = "A very basic flake";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.flatpakenv.url = "github:ranfdev/flatpakenv.nix";

  outputs = { self, nixpkgs, flake-utils, flatpakenv }: flake-utils.lib.eachDefaultSystem
    (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        flatpakEnv = flatpakenv { inherit pkgs; };
      in
      rec {
        packages.default = flatpakEnv.buildApp {
          appId = "my.best.App";
          sdk = "org.gnome.Sdk";
          runtime = "org.gnome.Platform";
          runtimeVersion = "43";
          sdkExtensions = [
            "org.freedesktop.Sdk.Extension.rust-stable"
            "org.freedesktop.Sdk.Extension.llvm14"
          ];

          modules = [
            {
              name = "libshumate";
              src = pkgs.fetchFromGitLab {
                domain = "gitlab.gnome.org";
                owner = "GNOME";
                repo = "libshumate";
                rev = "1.0.1";
                sha256 = "sha256-fpHMfxnPnGJSfJe4kJ28+704QjjRwYddOZAB17QxXno=";
              };
              buildPhase = flatpakEnv.buildPhase.meson {
                configOpts = [
                  "-Dgir=false"
                  "-Dvapi=false"
                  "-Dgtk_doc=false"
                  "-Dlibsoup3=true"
                ];
              };
            }
            {
              name = "shortwave";
              src = pkgs.fetchFromGitLab {
                domain = "gitlab.gnome.org";
                owner = "World";
                repo = "shortwave";
                rev = "3.2.0";
                sha256 = "sha256-ESZ1yD1IuBar8bv83xMczZbtPtHbWRpe2yMVyr7K5gQ=";
              };
              preBuildPhase = ''
                export PATH="$PATH:/usr/lib/sdk/rust-stable/bin"
              '';
              buildPhase = flatpakEnv.buildPhase.meson { };
            }
          ];
        };
      });
}
