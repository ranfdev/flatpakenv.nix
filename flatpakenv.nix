{ pkgs }:

let
  concat = pkgs.lib.foldr (a: b: a + b) "";
in
rec {
  buildPhase = {
    meson = { configOpts ? [ ] }: ''
      meson ${pkgs.lib.foldr (a: b: a + " " + b) "" configOpts} --prefix=/app build
      ninja -C build
      ninja -C build install
    '';
  };
  buildModule =
    { name
    , src
    , preBuildPhase ? ""
    , buildPhase
    }:
    pkgs.stdenvNoCC.mkDerivation {
      name = name;
      src = src;
      phases = [ "buildPhase" ];
      preferLocalBuild = true;
      allowSubstitutes = false;
      buildPhase = ''
        mkdir $out 
        ln -s $src $out/src
        touch $out/buildPhase.sh
        {
          echo "${preBuildPhase}"
          echo "${buildPhase}"
        } > $out/buildPhase.sh
      '';
    };
  buildApp =
    { appId
    , sdk
    , runtime
    , sdkExtensions ? [ ]
    , runtimeVersion
    , arch ? "x86_64"
    , modules ? [ ]
    }:
    let
      modulesDrvs = map
        (desc:
          if pkgs.lib.isDerivation desc
          then desc
          else (buildModule desc))
        modules;
      modulesBuildPhase = pkgs.writeShellScript ''modulesBuildPhase'' ''
        ${concat (map (mod: ''
          bname=$(basename "${mod}")
          cd /app/build-deps/$bname/src
          bash /app/build-deps/$bname/buildPhase.sh
        '') modulesDrvs)}
      '';
      flatpakFrameworkBuild = pkgs.writeShellScript ''flatpak-build'' ''
        sdkref="${sdk}/${arch}/${runtimeVersion}"
        runtimeref="${runtime}/${arch}/${runtimeVersion}"
        flatpak install $sdkref $runtimeref ${builtins.concatStringsSep " " sdkExtensions}

        flatpak build-init ${builtins.concatStringsSep " " (map (ext: "--sdk-extension=${ext}") sdkExtensions)} ./build ${appId} $sdkref $runtimeref
        cp -r result/build/files/. ./build/files/
        chmod -R +rwx result/build/files/
        flatpak --share=network build ./build bash ./build/files/modulesBuildPhase.sh
        rm -rf ./build/files/build-deps/
        flatpak build-finish ./build
        flatpak build-export outrepo ./build
        flatpak build-bundle outrepo ${appId}.flatpak ${appId}
      '';
    in
    pkgs.stdenv.mkDerivation {
      name = appId;
      src = ./.;
      phases = [ "buildPhase" ];
      buildPhase = ''
        mkdir -p $out/build/files/build-deps

        ${concat (map (mod: ''
          bname=$(basename "${mod}")
          mkdir -p $out/build/files/build-deps/
          cp -r ${mod} $out/build/files/build-deps/$bname
        '') modulesDrvs)}
        cp ${modulesBuildPhase} $out/build/files/modulesBuildPhase.sh
        cp ${flatpakFrameworkBuild} $out/flatpak-build.sh
      '';
    };
}
