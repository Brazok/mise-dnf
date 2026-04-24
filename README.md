# mise-dnf

A [mise](https://mise.jdx.dev) backend plugin that installs RPM packages into user-space — no `sudo` required.

It downloads packages via `dnf download`, extracts them with `rpm2cpio` + `cpio`, and installs everything under the mise-managed install path. XDG resources (`.desktop` files, shell completions, icons) are automatically symlinked into `~/.local/share/`.

## Requirements

- Linux with a DNF-based distribution (Fedora, RHEL, Rocky, AlmaLinux…)
- `dnf` — package manager
- `rpm2cpio` — included in the `rpm` package
- `cpio` — available on any Linux system

## Installation

```sh
mise plugin add dnf https://github.com/brazok/mise-dnf
```

## Usage

```sh
# Install a package at its latest available version
mise use dnf:curl

# Install a specific version (version-release format from dnf)
mise use dnf:curl@7.88.1-1.fc39

# List available versions for a package
mise ls-remote dnf:curl

# Run a tool installed via the dnf backend
mise exec dnf:curl -- curl --version
```

Once installed, mise sets up `PATH`, `LD_LIBRARY_PATH`, `XDG_DATA_DIRS` and `MANPATH` automatically so the tool is accessible without any manual configuration.

## What gets installed where

RPM packages extract their files preserving the standard directory layout under the mise install path:

```
~/.local/share/mise/installs/dnf-curl/7.88.1-1.fc39/
  usr/
    bin/curl          ← added to PATH
    lib64/libcurl.so  ← added to LD_LIBRARY_PATH
    share/
      man/man1/curl.1 ← added to MANPATH
```

In addition, the following resources are **symlinked into `~/.local/share/`** during installation so the system picks them up automatically:

| RPM content | Symlinked to |
|---|---|
| `usr/share/applications/*.desktop` | `~/.local/share/applications/` |
| `usr/share/bash-completion/completions/*` | `~/.local/share/bash-completion/completions/` |
| `usr/share/zsh/site-functions/*` | `~/.local/share/zsh/site-functions/` |
| `usr/share/fish/vendor_completions.d/*.fish` | `~/.local/share/fish/vendor_completions.d/` |
| `usr/share/icons/**` | `~/.local/share/icons/` |
| `usr/share/pixmaps/**` | `~/.local/share/pixmaps/` |

## Shell completions

**Bash** — completions work automatically if the `bash-completion` package is installed on your system.

**Zsh** — add this once to your `.zshrc` so zsh picks up completions from `~/.local/share/zsh/site-functions/`:

```zsh
fpath=(~/.local/share/zsh/site-functions $fpath)
autoload -Uz compinit && compinit
```

**Fish** — completions are discovered automatically from `~/.local/share/fish/vendor_completions.d/`.

## Limitations

- Linux only (RPM-based distributions).
- Packages with hard-coded absolute library paths (`/usr/lib64/…`) may not work correctly. Self-contained binaries and those with relative RPATHs work fine.
- Dependency resolution is handled by `dnf download --resolve`, which downloads direct dependencies. Packages that rely on system libraries already installed on your machine will work without bundling them.
