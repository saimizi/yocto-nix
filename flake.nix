{
  description = "Yocto Project development environment with repo tool and version-safe fallbacks";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # Fallback for pseudo (Yocto's fakeroot replacement)
      pseudoPkg =
        if pkgs ? pseudo then pkgs.pseudo
        else if pkgs ? pseudo-native then pkgs.pseudo-native
        else pkgs.emptyFile;

      # lz4 with lz4c symlink (Yocto expects lz4c)
      lz4WithLz4c = pkgs.runCommand "lz4-with-lz4c" {} ''
        mkdir -p $out/bin
        ln -s ${pkgs.lz4.out}/bin/lz4 $out/bin/lz4c
      '';

      # repo (Google's manifest tool)
      repoTool =
        if pkgs ? gitRepo then pkgs.gitRepo
        else if pkgs ? repo then pkgs.repo
        else throw "Neither gitRepo nor repo found in nixpkgs";
    in {
      devShells.${system}.default = pkgs.mkShell {
        name = "yocto-devshell";

        buildInputs = [
          # Yocto host tools
          pkgs.git
          pkgs.gawk
          pkgs.wget
          pkgs.curl
          pkgs.diffstat
          pkgs.texinfo
          pkgs.chrpath
          pkgs.cpio
          pkgs.unzip
          pkgs.xz
          pkgs.bzip2
          pkgs.gcc
          pkgs.gcc-unwrapped
          pkgs.gnumake
          pkgs.python3
          pkgs.python3Packages.pip
          pkgs.python3Packages.setuptools
          pkgs.python3Packages.wheel
          pkgs.python3Packages.pyelftools
          pkgs.python3Packages.jinja2
          pkgs.python3Packages.pyyaml
          pkgs.locale
          pkgs.which
          pkgs.file
          pkgs.patch
          pkgs.pkg-config
          pkgs.openssl
          pkgs.libxml2
          pkgs.libxslt
          pkgs.zstd
          pkgs.lz4
          lz4WithLz4c

          # repo tool (native or fallback)
          repoTool

          # pseudo (native or fallback)
          pseudoPkg
        ];

        shellHook = ''
          export LC_ALL=en_US.UTF-8
          export LANG=en_US.UTF-8
          export LANGUAGE=en_US.UTF-8

          echo "Yocto + repo environment loaded."
          echo "Use: repo init -u <manifest> && repo sync"
          echo "Then: source oe-init-build-env"
        '';
      };
    };
}

