# yocto-nix

A Nix flake that provides a reproducible development environment for [Yocto Project](https://www.yoctoproject.org/) builds.

## Prerequisites

- [Nix](https://nixos.org/download/) with flakes enabled

## Usage

Enter the development shell:

```sh
nix develop
```

This drops you into a shell with all Yocto host dependencies available, including:

- Build essentials (gcc, make, patch, etc.)
- Python 3 with pip, setuptools, pyelftools, jinja2, and pyyaml
- Compression tools (xz, bzip2, zstd, lz4/lz4c)
- Google's [repo](https://gerrit.googlesource.com/git-repo/) manifest tool
- Utilities (git, wget, curl, diffstat, texinfo, chrpath, cpio, unzip, etc.)

Once inside the shell, initialize your Yocto sources:

```sh
repo init -u <manifest-url>
repo sync
source oe-init-build-env
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
