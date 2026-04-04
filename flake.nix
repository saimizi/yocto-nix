{
  description = "Yocto Scarthgap devshell (Nix-safe, locale-safe, BitBake-safe)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          glibcLocales.enableAllLocales = true;
        };
      };

      # lz4c symlink (Yocto expects lz4c)
      lz4WithLz4c = pkgs.runCommand "lz4-with-lz4c" { } ''
        mkdir -p $out/bin
        ln -s ${pkgs.lz4.out}/bin/lz4 $out/bin/lz4c
      '';

      # repo tool (git-repo / repo)
      repoTool =
        if pkgs ? gitRepo then
          pkgs.gitRepo
        else if pkgs ? repo then
          pkgs.repo
        else
          throw "Neither gitRepo nor repo found in nixpkgs";
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        name = "yocto-scarthgap-devshell";

        # --- Locale: make BitBake happy, Nix-style ---
        LANG = "en_US.UTF-8";
        LC_ALL = "en_US.UTF-8";
        LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";

        # Scarthgap: ONLY this is honored, EXTRAWHITE is rejected
        #BB_ENV_PASSTHROUGH_ADDITIONS = "LANG LC_ALL LOCALE_ARCHIVE";

        # Optional: also pass through to tasks
        BB_ENV_PASSTHROUGH_ADDITIONS = "LANG LC_ALL LOCALE_ARCHIVE";

        buildInputs = [
          # Yocto host tools (from docs)
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
          repoTool
          pkgs.glibcLocales
        ];

        shellHook = ''
          echo "Yocto Scarthgap Nix devshell loaded."
          echo "LANG=$LANG"
          echo "LC_ALL=$LC_ALL"
          echo "LOCALE_ARCHIVE=$LOCALE_ARCHIVE"
          echo "BB_ENV_PASSTHROUGH_ADDITIONS=$BB_ENV_PASSTHROUGH_ADDITIONS"
          echo
          echo "Typical flow:"
          echo "  repo init -u <manifest> && repo sync"
          echo "  source oe-init-build-env build-test"
          echo "  bitbake core-image-minimal"
        '';
      };
    };
}
