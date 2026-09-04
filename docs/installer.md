# Installer

## Modes

With no argument, `install.sh` runs the full-screen single-key wizard. It
shows a review screen and changes nothing until approval. It supports:

```sh
./install.sh non-interactive
./install.sh --non-interactive
```

The wizard selects the prompt (`powerlevel10k` or `ohmyposh`), editor
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
At shell startup, a missing `zsh/home/.zshenv_z4h` is downloaded from the
pinned zsh4humans v5 `.zshenv` source and saved at that path before loading.

## Tools and state

The selected editor may be `vim`, `nano`, `fresh`, or `micro`. Nano is installed
with Homebrew on macOS and APT on Linux; its configuration is linked to
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
${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-next/base-packages-v1-<platform>.done
```

The marker is written only after success. Git remains a separate idempotent
prerequisite; optional tools are reevaluated on every run.

Fastfetch `first` counts distinct `ttys*` devices on macOS and `pts/*` devices
on Linux. SSH sessions, IDE terminals, and other terminal applications also
contribute to this global approximation and may suppress Fastfetch.

## Platform and logs

Supported hosts are macOS and Ubuntu 26.04. Ubuntu uses package names such as
`poppler-utils`, `dnsutils`, `fd-find`, and `command-not-found`; macOS uses
Homebrew equivalents such as `poppler`, `bind`, and `fd`. Ubuntu additionally
installs `grc` and `python3-pip`; macOS installs GNU core utilities.

Installer logs use the z4u palette: cyan 36, yellow 33, green 32, red 31,
bold 1, reset 0, with Unicode icons/borders and an ASCII fallback. External
package-manager output remains visible. The automatic bootstrap reports
success or failure but never blocks Zsh startup.

The cache reset function lists its targets and asks for confirmation. It may
remove z4h/plugin/Zsh/Mise/Oh My Posh/completion caches, compiled checkout
files, fzf state/markers, SSH-agent environment, and the installer marker. It
does not remove history, configuration, backups, Mise/ASDF data,
`.tool-versions`, or a running SSH agent.
