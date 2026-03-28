# How To Create a flake.nix for a Yocto Development Environment

This document explains each section of the `flake.nix` file used in this project.

## Overall Structure

A Nix flake is a self-contained Nix expression with a standardized structure. It always has two top-level attributes: `inputs` (dependencies) and `outputs` (what the flake provides).

```nix
{
  description = "...";
  inputs = { ... };
  outputs = { ... }: { ... };
}
```

---

## 1. Description

```nix
description = "Yocto Project development environment with repo tool and version-safe fallbacks";
```

A human-readable string describing what this flake provides. It is shown by commands like `nix flake show` and `nix flake metadata`.

---

## 2. Inputs

```nix
inputs.nixpkgs.url = "github:NixOS/nixpkgs";
```

Declares the flake's dependencies. Here we depend on **nixpkgs** — the main Nix package repository. The URL `github:NixOS/nixpkgs` points to the default branch of the nixpkgs repo on GitHub.

When you first run `nix develop`, Nix resolves this input and writes the pinned revision to `flake.lock`, ensuring reproducible builds.

---

## 3. Outputs

```nix
outputs = { self, nixpkgs }:
```

The `outputs` function receives:
- `self` — a reference to this flake itself
- `nixpkgs` — the resolved nixpkgs input declared above

Everything inside `outputs` defines what this flake provides to the outside world.

---

## 4. The `let` Block — Local Variables

The `let ... in` block defines local variables used later in the shell definition.

### 4.1 System and Packages

```nix
system = "x86_64-linux";
pkgs = import nixpkgs { inherit system; };
```

- `system` — hardcoded to `x86_64-linux`. This flake currently targets 64-bit Linux only.
- `pkgs` — imports nixpkgs for that system, giving us access to the full package set (e.g. `pkgs.git`, `pkgs.gcc`).

### 4.2 Pseudo Fallback

```nix
pseudoPkg =
  if pkgs ? pseudo then pkgs.pseudo
  else if pkgs ? pseudo-native then pkgs.pseudo-native
  else pkgs.emptyFile;
```

[Pseudo](https://git.yoctoproject.org/pseudo/) is Yocto's fakeroot replacement — it lets builds simulate root permissions without actual root access.

The `?` operator checks if an attribute exists in a set. This chain tries three options:
1. `pkgs.pseudo` — the preferred package name
2. `pkgs.pseudo-native` — an alternative name used in some nixpkgs versions
3. `pkgs.emptyFile` — a no-op fallback if neither exists (the shell still works, but pseudo won't be available)

### 4.3 lz4 with lz4c Symlink

```nix
lz4WithLz4c = pkgs.runCommand "lz4-with-lz4c" {} ''
  mkdir -p $out/bin
  ln -s ${pkgs.lz4.out}/bin/lz4 $out/bin/lz4c
'';
```

Yocto expects the `lz4c` command, but the nixpkgs `lz4` package only provides `lz4`.

Key details:
- `pkgs.runCommand` creates a minimal derivation that runs a shell script at build time. Its first argument (`"lz4-with-lz4c"`) is the **derivation name** — it only determines the name portion of the Nix store path (e.g. `/nix/store/<hash>-lz4-with-lz4c/`) and has no effect on behavior.
- `pkgs.lz4.out` explicitly selects the `out` output of the lz4 package. This is necessary because `pkgs.lz4` defaults to the `dev` output, which contains headers and pkg-config files but **not** the binary.
- The script creates a symlink `lz4c -> lz4` so both commands are available.

Note the two different variable syntaxes in the shell script:
- `$out` is a **shell variable** automatically set by Nix at build time. It points to the derivation's output path in the Nix store (e.g. `/nix/store/<hash>-lz4-with-lz4c/`). The build script is expected to place its output files there.
- `${pkgs.lz4.out}` is **Nix string interpolation**, resolved at evaluation time *before* the shell script ever runs. Nix substitutes it with the actual store path of the lz4 package.

So by the time the shell executes, the script has already been expanded to something like:
```bash
mkdir -p $out/bin
ln -s /nix/store/c35qp0iabz0x3sn7n6frcl8gzy61n1jb-lz4-1.10.0/bin/lz4 $out/bin/lz4c
```

### 4.4 Repo Tool Fallback

```nix
repoTool =
  if pkgs ? gitRepo then pkgs.gitRepo
  else if pkgs ? repo then pkgs.repo
  else throw "Neither gitRepo nor repo found in nixpkgs";
```

Google's [repo](https://gerrit.googlesource.com/git-repo/) tool manages multi-repository projects via XML manifests. Yocto projects commonly use it to sync layers.

The package name varies across nixpkgs versions:
1. `pkgs.gitRepo` — the current name in nixpkgs
2. `pkgs.repo` — an older name
3. `throw` — aborts the evaluation with an error if neither is found, rather than silently continuing without it

---

## 5. Development Shell

```nix
devShells.${system}.default = pkgs.mkShell {
  name = "yocto-devshell";
  buildInputs = [ ... ];
  shellHook = ''...'';
};
```

This is the core of the flake — the development shell activated by `nix develop`.

- `devShells.${system}.default` — registers this as the default dev shell for x86_64-linux
- `pkgs.mkShell` — a special Nix function that creates a shell environment (not a buildable package)

### 5.1 buildInputs — Packages Available in the Shell

All packages listed in `buildInputs` are added to `PATH` (for binaries) and made available for linking (for libraries).

| Package | Purpose |
|---|---|
| `git` | Version control |
| `gawk` | Text processing (used by BitBake) |
| `wget`, `curl` | Downloading source tarballs |
| `diffstat` | Summarize diff output (used by patch reporting) |
| `texinfo` | Documentation generation |
| `chrpath` | Edit RPATH in ELF binaries |
| `cpio` | Archive tool (used for initramfs) |
| `unzip`, `xz`, `bzip2`, `zstd`, `lz4` | Compression/decompression |
| `lz4WithLz4c` | Provides the `lz4c` command (see section 4.3) |
| `gcc`, `gcc-unwrapped` | C/C++ compiler. `gcc-unwrapped` provides the raw compiler without Nix wrapper scripts |
| `gnumake` | Build system |
| `python3` + packages | Python interpreter and libraries required by BitBake and various Yocto scripts |
| `locale` | Locale data (glibc locale archive) |
| `which` | Locate commands on PATH |
| `file` | Detect file types |
| `patch` | Apply patch files |
| `pkg-config` | Library discovery for C builds |
| `openssl` | Cryptography library |
| `libxml2`, `libxslt` | XML parsing and transformation |
| `repoTool` | Google repo (see section 4.4) |
| `pseudoPkg` | Fakeroot replacement (see section 4.2) |

### 5.2 shellHook — Runs on Shell Entry

```nix
shellHook = ''
  export LC_ALL=en_US.UTF-8
  export LANG=en_US.UTF-8
  export LANGUAGE=en_US.UTF-8

  echo "Yocto + repo environment loaded."
  echo "Use: repo init -u <manifest> && repo sync"
  echo "Then: source oe-init-build-env"
'';
```

This bash snippet runs every time you enter the shell via `nix develop`:
- Sets locale environment variables to UTF-8, which Yocto/BitBake requires
- Prints a reminder of the typical workflow

---

## Glossary

| Term | Meaning |
|---|---|
| **Flake** | A Nix project with a standardized `flake.nix` entry point and a `flake.lock` for pinned dependencies |
| **Derivation** | A build recipe in Nix — describes how to produce an output from inputs |
| **`mkShell`** | A Nix function that creates a development shell environment (a derivation that isn't meant to be "built" into a package) |
| **`buildInputs`** | Packages whose `bin/` directories are added to `PATH` and whose libraries are available for linking |
| **`shellHook`** | A bash script that runs automatically when entering the development shell |
| **`runCommand`** | A minimal derivation helper that runs a shell script at build time to produce an output |
| **Output (`out`, `dev`, `lib`)** | Nix packages can have multiple outputs to separate binaries, headers, and libraries |

---

## Appendix

### A.1 How to Add a New Package

#### Step 1: Search for the Package

**Option A: Web search**

Visit [search.nixos.org/packages](https://search.nixos.org/packages) and type the package name. The results show the Nix attribute name (e.g. `gitRepo`), version, and description.

**Option B: Command line**

```sh
nix search nixpkgs <keyword>
```

For example, to find lz4-related packages:

```sh
nix search nixpkgs lz4
```

Output looks like:

```
* legacyPackages.x86_64-linux.lz4 (1.10.0)
  Extremely fast compression algorithm
```

The part after the last `.` (e.g. `lz4`) is the attribute name you use in `flake.nix` as `pkgs.lz4`.

#### Step 2: Check the Package Outputs

Some packages split their files across multiple outputs (`out`, `dev`, `lib`, `man`). The default output may not contain what you need.

```sh
# Check which outputs a package has
nix eval nixpkgs#<package>.outputs --json
```

For example:

```sh
nix eval nixpkgs#lz4.outputs --json
# ["dev","lib","man","out"]
```

If the default output doesn't contain the binary you need, explicitly select the correct output (e.g. `pkgs.lz4.out`).

#### Step 3: Verify the Package Provides the Expected Binary

```sh
# List binaries in a package
ls $(nix build nixpkgs#<package> --print-out-paths --no-link)/bin/
```

For example:

```sh
ls $(nix build nixpkgs#lz4 --print-out-paths --no-link)/bin/
# lz4  lz4cat  unlz4
```

If the binary you need is missing (like `lz4c`), you may need to create a wrapper derivation with a symlink (see section 4.3).

#### Step 4: Add It to flake.nix

**Simple case** — the package exists in nixpkgs and the default output has the binary:

Add `pkgs.<package>` to the `buildInputs` list:

```nix
buildInputs = [
  # ... existing packages ...
  pkgs.new-package
];
```

**When you need a specific output:**

```nix
buildInputs = [
  pkgs.somePackage.out  # explicitly use the "out" output
];
```

**When you need a missing command alias:**

Create a wrapper derivation in the `let` block and add it to `buildInputs`:

```nix
let
  myWrapper = pkgs.runCommand "my-wrapper" {} ''
    mkdir -p $out/bin
    ln -s ${pkgs.somePackage.out}/bin/actual-name $out/bin/expected-name
  '';
in {
  devShells.${system}.default = pkgs.mkShell {
    buildInputs = [
      pkgs.somePackage
      myWrapper
    ];
  };
}
```

#### Step 5: Test

```sh
nix develop --command which <binary-name>
```
