{ pkgs }:

let
  concat = pkgs.lib.foldr (a: b: a + b) "";
in
rec {
  buildPhase = {
    meson = { configOpts ? [ ] }: ''
      echo "Mutable build dir at $FLATPAKNIX_BUILD_DIR/$FLATPAKNIX_MOD_NAME"
      meson ${pkgs.lib.foldr (a: b: a + " " + b) "" configOpts} --prefix=/app $FLATPAKNIX_BUILD_DIR/$FLATPAKNIX_MOD_NAME
      ninja -C $FLATPAKNIX_BUILD_DIR/$FLATPAKNIX_MOD_NAME
      ninja -C $FLATPAKNIX_BUILD_DIR/$FLATPAKNIX_MOD_NAME install
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
          echo '${preBuildPhase}'
          echo '${buildPhase}'
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
      cacheBuildDir = ''~/.cache/flatpakenv.nix/${appId}'';
      modulesDrvs = map
        (desc:
          if pkgs.lib.isDerivation desc
          then desc
          else (buildModule desc))
        modules;
      modulesBuildPhase = pkgs.writeShellScript ''modulesBuildPhase'' ''
        FLATPAKNIX_BUILD_DIR=${cacheBuildDir}
        ${concat (map (mod: ''
          FLATPAKNIX_MOD_NAME=$(basename "${mod}")
          prevpwd=`pwd`
          mutsrcdir=`mktemp -d`
          cp -r result/build/files/build-deps/$FLATPAKNIX_MOD_NAME/src/. $mutsrcdir
          chmod -R +rwx $mutsrcdir

          pushd $mutsrcdir/
          source /$prevpwd/result/build/files/build-deps/$FLATPAKNIX_MOD_NAME/buildPhase.sh
          popd
        '') modulesDrvs)}
      '';
      flatpakFrameworkBuild = pkgs.writeShellScript ''flatpak-build'' ''
        FLATPAKNIX_BUILD_DIR=${cacheBuildDir}
        sdkref="${sdk}/${arch}/${runtimeVersion}"
        runtimeref="${runtime}/${arch}/${runtimeVersion}"
        flatpak install $sdkref $runtimeref ${builtins.concatStringsSep " " sdkExtensions}

        mkdir -p $FLATPAKNIX_BUILD_DIR/flatpak

        flatpak build-init ${builtins.concatStringsSep " " (map (ext: "--sdk-extension=${ext}") sdkExtensions)} $FLATPAKNIX_BUILD_DIR/flatpak ${appId} $sdkref $runtimeref
        flatpak --share=network build $FLATPAKNIX_BUILD_DIR/flatpak bash result/build/files/modulesBuildPhase.sh
        flatpak build-finish $FLATPAKNIX_BUILD_DIR/flatpak
        flatpak build-export outrepo $FLATPAKNIX_BUILD_DIR/flatpak
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
