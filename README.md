<!--
- [ ] ability to both open and close the parcels
- [x] ability to open true path
- [/] raycast extension baby (done thru deep links)
- [ ] ability to open/close multiple parcels at once
- [ ] add shell command support (only runs if some env var is set for extra safety)
- [ ] add ability to templateize paths (e.g. `obsdian://open?file=Journal/{{today's date}}`)
  - [ ] the template should be customizable (e.g. `{{date:YYYY-MM-DD}}` or `{{date:DD-MM-YYYY}}`), through the templating crate maybe
-->

# Kozutsumi
Open and close parcels from your terminal.

## Installation

### Homebrew
```sh
brew tap fruit-bird/kozutsumi
brew install kozutsumi
```

Install with additional features:
```sh
brew install kozutsumi --with-json --with-dialoguer
```

### Cargo
```sh
cargo install kozutsumi [--features=json,dialoguer]
```

### Nix
kozutsumi is a flake that ships **prebuilt binaries** built by CI, so pulling it
into a NixOS or nix-darwin config does not build anything locally — it fetches
the release artifact for your system from `nix/sources.json`.

> [!IMPORTANT]
> The repository is private, which needs auth in **two** places on each machine:
> 1. **Flake metadata** (resolving `github:fruit-bird/kozutsumi`): add
>    `access-tokens = github.com=ghp_...` to `nix.conf` (`nix.extraOptions`).
> 2. **The release binary** (fetched by the Nix daemon in a build sandbox): the
>    daemon does *not* use `access-tokens` for this. Point it at a netrc:
>    ```
>    # /etc/nix/nix.conf
>    netrc-file = /etc/nix/netrc
>    # /etc/nix/netrc
>    machine api.github.com login x password ghp_...
>    ```
>    then restart the daemon. CI publishes the binary URL as the authenticated
>    GitHub **API asset endpoint** so this netrc applies; curl drops the token on
>    the redirect to the signed download URL.
>
> If this per-machine auth is more friction than you want, the simpler path is a
> **public repo + Cachix** (no tokens anywhere). See the release-pipeline PR.

Try it without installing:
```sh
nix run github:fruit-bird/kozutsumi -- list
```

Add the flake to your inputs:
```nix
inputs.kozutsumi.url = "github:fruit-bird/kozutsumi";
```

### Install the package
Either add the overlay and use `pkgs.kozutsumi`:
```nix
{ inputs, ... }: {
  nixpkgs.overlays = [ inputs.kozutsumi.overlays.default ];
  environment.systemPackages = [ pkgs.kozutsumi ];
}
```
or reference the package directly: `inputs.kozutsumi.packages.${pkgs.system}.default`.

### Configure declaratively
Define your parcels in Nix instead of editing `kozutsumi.yml` by hand.

**home-manager** (recommended — works under NixOS and nix-darwin). Writes
`~/.config/kozutsumi/kozutsumi.yml` and installs the package:
```nix
{ inputs, ... }: {
  imports = [ inputs.kozutsumi.homeManagerModules.default ];
  programs.kozutsumi = {
    enable = true;
    parcels = {
      work = [ "Slack" "~/work" "https://github.com" ];
      notify = [ "sh:osascript -e 'display notification \"done\"'" ];
    };
  };
}
```

**NixOS / nix-darwin** (system-wide). Writes `/etc/kozutsumi/kozutsumi.yml` and
installs a `kozutsumi` that defaults to it (your own `--config` still overrides):
```nix
{ inputs, ... }: {
  imports = [ inputs.kozutsumi.nixosModules.default ];   # or .darwinModules.default
  programs.kozutsumi = {
    enable = true;
    parcels.work = [ "Slack" "~/work" ];
  };
}
```

Both modules also expose a free-form `settings` option, merged on top of
`parcels`, for anything not expressible as a parcel.

## Usage
```
Usage: kozutsumi [OPTIONS] <COMMAND>

Commands:
  open         Opens a parcel by name
  choose       Opens a parcel by choosing from a list
  list         Lists all available parcels
  completions  Generate shell completions

Options:
  -c, --config <CONFIG>  Override the default config path
```

### Configuration File
You first create a config file at `~/.config/kozutsumi/parcel.yaml` with the following structure:

```yml
anime:
  - Sequel
  - IINA
  - fs:~/Movies/Anime
language-learning:
  - obsidian://open?file=path/to/language-notes-file
  - Anki
  - https://www.duolingo.com
```

> App names are only supported on macOS. For other operating systems, use paths to the executable.

Then you can open a parcel by running:
```sh
kozutsumi open language-learning
```

### Chooser
You can also use a chooser to select the parcel to open:
```sh
kozutsumi choose --chooser=fzf --multi
```

Deep links / URIs are also supported:
```yml
deeplinks:
  - raycast://confetti
  - x-apple.systempreferences:com.apple.preference.displays
  - raycast://extensions/raycast/raycast-focus/start-focus-session
  - spotify://track/0vH25LloTmsmsh5uCuj0JC
```

> This feature requires `fzf` to be installed.

### Tmux Integration
If you use `kozutsumi` through `tmux`, the chooser will open in a small overlay. You can combine this with a keybinding to allow for easier opening of parcels.

Here is an example tmux keybinding to open the chooser with `prefix+o`:
```sh
bind 'o' run-shell "sh -lc 'kozutsumi choose --multi --chooser=fzf'"
```

![tmux-chooser](./images/tmux-chooser.png)

# TODO
- switch from dialoguer to skim for chooser alternative (skim removes the need for pre-req fzf dependency)
- for linux, support the most popular tools for opening apps/files/urls
  - xdg-open
  - gio open
  - gnome-open
  - kde-open
- allow shell command override (override `sh -c` with custom command)
- rofi support for linux