# Installer

## Modes

The installer must be launched as a normal user. It refuses UID 0, including
invocation through `sudo`. Each privileged operation is routed through one
helper that first explains why administrator access is needed and shows the
command. Non-interactive mode uses `sudo -n` and fails instead of prompting.

With no argument, `install.sh` runs the full-screen single-key wizard. It
shows a review screen and changes nothing until approval. It supports:

```sh
./install.sh non-interactive
./install.sh --non-interactive
```

On Intel macOS the wizard first selects MacPorts or Homebrew as the package
provider. It recommends and defaults to MacPorts and warns that Homebrew on
Intel is Tier 3, has no CI support, and receives no new binary bottles. The wizard also selects the prompt (`powerlevel10k` or `ohmyposh`), editor
(`vim`, `nano`, `fresh`, or `micro`), Fastfetch mode, generated completion,
Mise, and SSH key loading/display/askpass behavior. fzf-tab, the local fzf
checkout, and Oh My Zsh helpers are always enabled and are not prompted.
`q` exits without changes; `a` or `Enter` accepts the review;
`r` restarts the wizard.

Non-interactive mode never reads `/dev/tty`, opens menus, clears the screen,
asks questions, or installs Mise because of an environment override. It uses
non-prompting package operations (`sudo -n` on Ubuntu) and fails when required
credentials are unavailable. Remaining user choices come from
`zsh/home/.zshenv`; the three fixed integration flags are always normalized.
Intel defaults to MacPorts; `DOTFILES_INTEL_PACKAGE_MANAGER=homebrew` selects
Homebrew, and an existing generated preference is reused when the environment
does not override it.
At shell startup, a missing `zsh/home/.zshenv_z4h` is downloaded from the
pinned zsh4humans v5 `.zshenv` source and saved at that path before loading.

## Tools and state

The selected editor may be `vim`, `nano`, `fresh`, or `micro`. macOS installs
non-system editors with its architecture-selected package manager and Linux
uses APT; the configuration is linked to
`~/.config/nano` and its backups are stored in `~/.cache/nano/backups`. Vim is
installed with APT on Linux, while macOS uses its system Vim; its configuration
is linked to `~/.config/vim`. Fastfetch is
disabled, shown at every interactive startup, or shown only in the first
active terminal. Mise and Oh My Posh are installed only when selected.

The latest fzf checkout is always kept in `~/.local/share/fzf`, fast-forwarded
on subsequent installer runs, and its binary is copied to `~/.local/bin/fzf`.
This path supplies the modern fzf actions used by the vendored fzf-git
integration. Startup checks that this binary is at least fzf 0.66 and reruns
the non-interactive updater when it is older.
Mise uses the official installer on macOS and Linux, then prepares activation,
completion, and ASDF compatibility data. The startup helper can invoke the
installer once when a selected tool is missing.

Managed destinations are backed up as `.backup.YYYYMMDDhhmmss`; existing
correct symbolic links are retained. Base packages and fonts are guarded by:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-next/base-packages-v2-<platform>-<provider>.done
```

The marker is written only after success. Git remains a separate idempotent
prerequisite; optional tools are reevaluated on every run.

Fastfetch `first` counts distinct `ttys*` devices on macOS and `pts/*` devices
on Linux. SSH sessions, IDE terminals, and other terminal applications also
contribute to this global approximation and may suppress Fastfetch.

## Platform and logs

Supported hosts are macOS and Ubuntu 26.04. Apple Silicon uses Homebrew, Intel
macOS chooses MacPorts from `/opt/local` or Homebrew from `/usr/local`, and
Ubuntu uses APT. MacPorts is recommended on Intel because Homebrew is Tier 3,
without CI support or new Intel bottles. A missing selected package manager is
installed automatically. Before any MacPorts setup, missing Apple Command Line
Tools are installed headlessly through `softwareupdate`; the installer never
opens the graphical `xcode-select --install` prompt. Interactive runs can still
request the administrator password through `sudo`, while non-interactive runs
use `sudo -n` and fail if authorization is unavailable. A missing Intel
MacPorts installation is downloaded from the official release, checked with
`pkgutil`, Gatekeeper, and the macOS Installer compatibility query, then
installed with one explained privileged command. Required Intel ports include
the explicit `bind9` mapping; a missing port is an error and never triggers a
Homebrew fallback. Installer-initiated MacPorts operations use its global `-N`
mode so dependency and upgrade confirmations do not require repeated input.
Ubuntu uses package names such as `poppler-utils`,
`dnsutils`, `fd-find`, and `command-not-found`.
On macOS the installer uses `/usr/bin/git` supplied by the selected Apple
developer tools and does not install the Homebrew `git` formula or MacPorts
`git` port. Linux still installs Git through APT when necessary.

The Intel provider is persisted as `DOTFILES_INTEL_PACKAGE_MANAGER` so
non-interactive startup repairs retain the approved provider. Users may install
Homebrew manually alongside a MacPorts-primary setup for casks or formulae
missing from MacPorts. In that configuration the custom `z4h-pkgmng` plugin
isolates Homebrew from the normal `PATH` and exposes explicit exceptions.

Installer logs use the z4u palette: cyan 36, yellow 33, green 32, red 31,
bold 1, reset 0, with Unicode icons/borders and an ASCII fallback. External
package-manager output remains visible. The automatic bootstrap reports
success or failure but never blocks Zsh startup.

The cache reset function lists its targets and asks for confirmation. It may
remove z4h/plugin/Zsh/Mise/Oh My Posh/completion caches, compiled checkout
files, fzf state/markers, SSH-agent environment, and the installer marker. It
does not remove history, configuration, backups, Mise/ASDF data,
`.tool-versions`, or a running SSH agent.
