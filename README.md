# dotfiles-next

> A batteries-included Zsh environment for macOS and Ubuntu 26.04, built around Zsh for Humans.

## ✨ Introduction

`dotfiles-next` is an opinionated collection of shell settings, terminal tools, editor configurations, themes, fonts, and custom Zsh plugins. It provides an interactive installer for personal workstations, an environment-driven non-interactive mode for automation, and a complete Docker image for exploring the setup without changing the host.

The default prompt is **Powerlevel10k**. **Oh My Posh** is available as an explicit alternative and uses [`oh-my-posh/custom.omp.json`](oh-my-posh/custom.omp.json). Zsh for Humans (z4h) bootstraps the shell framework and manages the external Zsh plugins on first startup.

## ✅ Prerequisites

The host installer supports:

- macOS with Homebrew, or Ubuntu 26.04 with APT.
- Zsh already installed and configured as the current user's login shell.
- `curl` and an internet connection.
- `sudo` access on Ubuntu 26.04 when installation is not run as root.
- `bash` on macOS if Homebrew must be installed automatically.

If Zsh is missing, install it with the platform package manager:

```sh
# macOS
brew install zsh

# Ubuntu 26.04
sudo apt-get update
sudo apt-get install -y zsh
```

Check that Zsh is available and is the active login shell before running the installer:

```sh
command -v zsh
printf '%s\n' "$SHELL"
```

If necessary, set Zsh as the login shell and start a new login session:

```sh
chsh -s "$(command -v zsh)"
```

Sign out and back in after `chsh`. If Zsh is missing or is not the current
user's login shell, the installer stops before changing the system and displays
these platform-specific setup instructions.

A terminal with Nerd Font support is strongly recommended because the prompts, tmux status line, and file icons use additional glyphs. The installer installs Fira Code Nerd Font on macOS and the bundled fonts on Ubuntu 26.04.

To use the demo image, install Docker Desktop or Docker Engine with BuildKit. Building the image requires internet access and considerably more time and disk space than the host installation.

For a minimal disposable Ubuntu 26.04 shell intended only for manual installer
testing, build [`Dockerfile.test`](Dockerfile.test) and open its default Zsh
session:

```sh
docker build -f Dockerfile.test -t dotfiles-next-test-shell .
docker run --rm -it dotfiles-next-test-shell
```

The container runs as the passwordless-sudo `demo` user. It includes only Zsh,
sudo, curl, and HTTPS certificates, leaving Git and the dotfiles packages for
the installer under test.

## 🧰 Components

### Core command-line tools

The base package set is installed once per platform. It supplies the commands used by the shell, previews, aliases, and bundled configurations.

| Component | Purpose |
| --- | --- |
| `bat` | Syntax-highlighted file viewing. On Ubuntu 26.04 the packaged command is named `batcat`; the preview helper supports both names. |
| `eza` | Modern, icon-aware replacement for `ls`. |
| `fd` | Fast file discovery. On Ubuntu 26.04 the package is named `fd-find` and exposes `fdfind`; the Docker demo adds an `fd` compatibility link. |
| `ripgrep` | Fast recursive text search. |
| `git` and `git-delta` | Version control plus readable, side-by-side diffs. |
| `fzf` and `fzf-tab` | Fuzzy file selection and interactive Zsh completion. `fzf` is provided through the z4h-managed plugin stack. |
| `chafa`, `mediainfo`, `poppler`, and `file` | Image, media, PDF, and generic file previews inside fzf. |
| `tmux` | Persistent terminal sessions with the included mouse and keyboard configuration. |
| `htop`, `tree`, `wget`, and DNS tools | Process inspection, directory views, downloads, and host/DNS inspection. |
| `stow` | Available for manual dotfile workflows; the installer itself creates explicit symbolic links. |
| Nerd Fonts | Prompt, file, Git, and tmux glyphs. |

Package names differ slightly by platform. Ubuntu 26.04 uses `poppler-utils`, `dnsutils`, `fd-find`, and `command-not-found`, while macOS uses the corresponding Homebrew formulae such as `poppler`, `bind`, and `fd`. Ubuntu 26.04 additionally installs `grc` and `python3-pip`; macOS installs GNU core utilities.

### Shell and optional components

| Component | Status | Purpose |
| --- | --- | --- |
| Zsh for Humans | Core | Bootstraps the Zsh environment, manages external plugins, and supplies shell utilities and key bindings. |
| Powerlevel10k | Default | Fast, Git-aware two-line prompt configured by [`powerlevel10k/.p10k.zsh`](powerlevel10k/.p10k.zsh). |
| Oh My Posh | Optional | Alternative prompt using the repository's custom JSON theme. Installed only when `ohmyposh` is selected. |
| Oh My Zsh helpers | Optional, enabled by default | Loads selected libraries and plugins such as `sudo`, `command-not-found`, and the macOS/Homebrew helpers without sourcing the complete `oh-my-zsh.sh`. |
| fzf-tab stack | Optional, enabled by default | Adds fuzzy completion, previews, syntax highlighting, history search, and suggestions. |
| Completion generator | Optional, enabled by default | Generates and caches getopt-style completion for the current command when explicitly requested with `Shift-Tab`. |
| Fastfetch | Optional | Displays a visual overview of the operating system, hardware, memory, disks, shell, terminal, and other system details. It can run at every interactive Zsh startup or only at the first active terminal prompt. |
| Mise | Host interactive installation | Installed automatically in interactive mode, activates language/tool runtimes, and maintains compatibility with `.tool-versions`. It is also preinstalled in the Docker demo. |
| Micro, Fresh, Vim, or Nano | Select one | Configures the requested default editor; Micro is the default. Repository configurations are linked for Micro and Fresh. |

The repository also contains configurations for Git, Ghostty, iTerm2, Fastfetch, Mise, SSH, ripgrep, tmux, Micro, and Fresh. Some are reference configurations and are not all linked by the host installer.

## 🧩 Custom Zsh plugins

The project-specific plugins live in [`zsh/z4h.custom.plugins`](zsh/z4h.custom.plugins) and are loaded from the main Zsh configuration.

| Plugin | What it does |
| --- | --- |
| `z4h-fzf` | Extends fzf-tab, `Ctrl-T`, and `Alt-C` with shared hidden-file state, persistent preview layout, contextual previews, grouped Git refs and recent commits, and command-specific views for Git, Docker, package managers, SSH, processes, manuals, and systemd. |
| `z4h-containers` | Adds Docker and kubectl aliases, caches CLI-generated completion, improves Docker completion contexts, and supplies JSON/YAML kubectl helpers when the required tools are available. |
| `z4h-eza` | Replaces common `ls` forms with an icon-aware `eza` configuration and falls back to `exa` when necessary. Provides `ll` and `lls`. |
| `z4h-gencomp-lazy` | Generates completion from a command's help output on explicit `Shift-Tab`, caches it, loads it immediately, and remembers failed attempts for the current session. It also provides the manual `gencomp` command. |
| `z4h-mise` | Caches Mise activation and completion, avoids duplicate hooks, refreshes immediately after directory changes and successful `mise` commands, throttles unchanged prompts, provides `asdf` compatibility, and synchronizes `mise use` selections to `.tool-versions`. |
| `z4h-oh-my-posh` | Loads Oh My Posh only when selected and caches the generated Zsh initialization until the binary, theme, or plugin changes. |
| `z4h-misc` | Provides compatibility aliases, the optional allafine behavior, and a searchable `Ctrl-K` keybinding reference for Zsh, fzf, tmux, and Micro. |

## 🚀 Installation

The installer checks the platform, installs Git when necessary, clones the repository into `~/.dotfiles`, installs the base packages, and creates the required configuration links.

Download the installer before running it so it can be reviewed locally:

```sh
curl -fsSL \
  https://raw.githubusercontent.com/michelemadonna/dotfiles-next/main/install.sh \
  -o /tmp/dotfiles-next-install.sh
sh /tmp/dotfiles-next-install.sh
```

You can also clone the repository yourself and run:

```sh
./install.sh
```

### Interactive mode

With no arguments, the installer opens a Powerlevel10k-style full-screen
wizard. The first screen introduces the repository and explains the operations
the script can perform. Every question is shown in a colored frame and uses a
single-key menu: press the displayed letter immediately, or press `Enter` to
accept the option marked `(default)`. Press `q` on any question to quit without
changing the system.

The wizard asks for:

- Prompt: `powerlevel10k` or `ohmyposh`.
- Editor: `vim`, `nano`, `fresh`, or `micro`.
- Fastfetch (disabled, shown at every interactive Zsh startup, or shown only at the first active terminal prompt), fzf-tab, generated completion, and selected Oh My Zsh helpers.
- SSH key loading, key display, and forced askpass behavior.

The wizard does not ask whether packages should be installed. After the plan is
approved, the interactive installer installs Mise automatically and prepares
its activation/completion caches and ASDF compatibility data, keeping this work
out of the first Zsh startup.

After the questions, the installer clears the screen and shows the detected
platform, repository and package operations together with every selected
preference. No package, repository, file, backup, or symbolic link is changed
before this summary is accepted. Press `a` or `Enter` to apply the plan, `r` to
restart the wizard, or `q` to quit without changes.

The answers are written to `zsh/.zshenv`, and `~/.zshenv` points to that generated file. Of the available editors, only the selected editor is installed. Mise is always installed in interactive mode, while Fastfetch and Oh My Posh are installed only when enabled.
The Fastfetch `first` mode counts distinct active `ttys*` devices on macOS and
`pts/*` devices on Linux. This is a deliberately global and simple check: SSH
sessions, IDE terminals, and terminals opened by other applications contribute
to the count, so they can prevent Fastfetch from being displayed.
The wizard and installer-owned progress messages always use ANSI colors and
framed output; `NO_COLOR` is intentionally ignored. UTF-8 terminals also get
Unicode borders, status icons, highlighted defaults, and emphasized section
labels, while other locales receive an ASCII fallback. External
package-manager output is passed through unchanged.

### Non-interactive mode

Both spellings are supported:

```sh
./install.sh non-interactive
./install.sh --non-interactive
```

This mode never reads from `/dev/tty`, changes terminal input settings, clears
the screen, opens menus, shows a review screen, or asks questions. It reads its
installation choices from the environment. Installer-owned status messages
still use the same colored frames as interactive mode:

| Variable | Accepted values | Default |
| --- | --- | --- |
| `EDITOR` | `vim`, `nano`, `fresh`, `micro` | `micro`; unsupported values also fall back to `micro` |
| `Z4H_PROMPT` | `powerlevel10k`, `ohmyposh` | `powerlevel10k` |
| `Z4H_SHOW_FASTFETCH` | `true`, `false`, `first` | `false` |

Example:

```sh
EDITOR=fresh \
Z4H_PROMPT=ohmyposh \
Z4H_SHOW_FASTFETCH=true \
./install.sh non-interactive
```

Non-interactive mode uses non-prompting package-manager options, including `sudo -n` on Ubuntu 26.04, and fails if credentials are required. It never installs Mise and does not generate `zsh/.zshenv`; instead, `~/.zshenv` points directly to `zsh/.zshenv.init`, which preserves supported values already present in the environment.

### Paths, state, and repeat runs

| Variable | Purpose | Default |
| --- | --- | --- |
| `HOME` | Installation home directory | Current user's home |
| `DOTFILES_DIR` | Repository checkout and configuration source | `$HOME/.dotfiles` |
| `DOTFILES_REPO_URL` | Repository cloned by the bootstrap installer | This GitHub repository |
| `XDG_STATE_HOME` | Base directory for the installation marker and shell state | `$HOME/.local/state` |

Base packages and fonts are guarded by this platform-specific marker:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-next/base-packages-v1-<platform>.done
```

The marker is created only after the base installation succeeds. Later executions skip that step. Git remains a separate idempotent prerequisite check, while optional components are evaluated on every run.

Existing regular files or directories at managed destinations are moved to a timestamped `.backup.YYYYMMDDhhmmss` path before linking. Existing symbolic links are replaced. The base installer manages:

- `~/.zshenv`
- `~/.ssh/config` → `~/.dotfiles/ssh/config`
- `~/.config/git` → `~/.dotfiles/git`
- `~/.config/tmux`
- `~/.config/ripgrep`
- The selected editor's configuration when using Micro or Fresh
- Fastfetch, Mise, and Oh My Posh configuration when those components are installed

After installation, start a fresh login shell:

```sh
exec zsh -l
```

The first Zsh startup downloads z4h and the enabled external plugins, so it requires an internet connection and can take longer than subsequent starts.

## 🐳 Docker demo

The Dockerfile builds a **complete demonstration and preview environment**, not a small production image. It is based on Ubuntu 26.04 and includes the base tools, optional editors, Fastfetch, Mise, Oh My Posh, OpenSSH client, Java, Python, Node.js, and all repository configurations.

By default, the build clones the `main` branch from this GitHub repository, so
the resulting image does not depend on uncommitted files in the current directory:

```sh
./docker-demo.sh
```

For the default remote source, `docker run -it` starts the repository's
**interactive** installer before entering Zsh. The container therefore requires
a TTY and asks for the prompt, editor, Fastfetch, fzf-tab, completion, Oh My Zsh,
and SSH preferences on every new container. Mise is installed automatically
after the plan is approved.

To test the files from the current directory instead, select the local source
explicitly. This mode runs `install.sh non-interactive` during the build and
starts Zsh directly when the container runs:

```sh
./docker-demo.sh local
```

The script accepts `remote` (the default) or `local`, builds
`dotfiles-next-demo`, and launches it with an interactive TTY. Set
`DOCKER_IMAGE` to use another image name. The equivalent manual commands are
`docker build -t dotfiles-next-demo .` and
`docker run --rm -it dotfiles-next-demo`; add
`--build-arg DOTFILES_SOURCE=local` to the build command for local sources.

Remote builds can target another repository or branch without editing the Dockerfile:

```sh
docker build \
  --build-arg DOTFILES_REPO_URL=https://github.com/example/dotfiles.git \
  --build-arg DOTFILES_REF=feature-branch \
  -t dotfiles-next-demo .
```

The container runs as the unprivileged `demo` user with Zsh as its login shell. The image prepares the base-package marker because all required packages are already installed in the cacheable base stage. It also:

- Runs the remote checkout's interactive installer at container startup, or the local checkout's non-interactive installer during the build.
- Prepares Mise activation/completion caches during a local build; a remote
  container prepares them through the interactive installer.
- Installs Fresh, Micro, Mise, Fastfetch, and Oh My Posh.
- Links the Zsh, Git, SSH, tmux, ripgrep, editor, prompt, and runtime configurations.
- Clones Java/Maven, Node.js, Python, and image repositories under `/home/demo/Developer` for testing completions and previews.
- Installs Java `17.0.2`, Python `3.13.6`, and Node.js `22.14.0` through Mise and assigns them to the matching sample projects.

The default prompt inside the image remains Powerlevel10k because the Docker setup uses the defaults from `zsh/.zshenv.init`. Oh My Posh is installed so the alternative prompt can also be tested.

## 📁 Repository layout

| Path | Contents |
| --- | --- |
| [`AGENTS.md`](AGENTS.md) | Repository-specific instructions, constraints, and validation requirements for coding agents. |
| [`zsh`](zsh) | Zsh startup files, Powerlevel10k configuration, helpers, and custom plugins. |
| [`git`](git) | Git defaults plus local, personal, and work include examples. |
| [`tmux`](tmux) | tmux configuration with an `Alt-A` prefix, mouse support, and top status line. |
| [`micro`](micro) / [`fresh`](fresh) | Editor settings and bundled Micro plugins. |
| [`oh-my-posh`](oh-my-posh) | Custom Oh My Posh theme. |
| [`fastfetch`](fastfetch) / [`mise`](mise) | System-summary and runtime-manager settings. |
| [`ghostty`](ghostty) / [`iTerm2`](iTerm2) | Terminal settings, themes, profiles, and shaders. |
| [`fonts`](fonts) | Nerd Fonts used by the shell UI. |
| [`ssh`](ssh) / [`ripgrep`](ripgrep) | SSH client and ripgrep configuration. |

## ⌨️ Useful keys

| Key | Action |
| --- | --- |
| `Tab` | Open normal or fzf-tab completion. |
| `Shift-Tab` | Generate completion for the current command from its help output, then open it. |
| `Ctrl-H` | Toggle hidden files in fzf-tab, `Ctrl-T`, and `Alt-C`. |
| `Ctrl-P` | Cycle the fzf-tab preview between right, bottom, and hidden layouts. |
| `Ctrl-T` | Select files with fzf and insert them into the command line. |
| `Alt-C` | Select a directory with fzf and change into it. |
| `Ctrl-K` | Open the searchable custom keybinding reference. |
| `Up` / `Down` | Traverse command history chronologically. |

## 🔧 Customization

The main defaults live in [`zsh/.zshenv.init`](zsh/.zshenv.init), while interactive installations generate `zsh/.zshenv`. The primary shell configuration is [`zsh/home/.zshrc`](zsh/home/.zshrc).

Store machine-specific shell values in `~/.env.zsh`; it is sourced automatically when present. Git include templates are available in [`git/examples`](git/examples), and tmux loads `~/.tmux.conf.local` when that file exists.

`Z4H_MISE_REFRESH_SECONDS` controls Mise's periodic safety refresh (default: `5`). Directory changes, `PATH` changes, and successful `mise` commands still refresh immediately. Set it to `0` to run Mise's refresh hook before every prompt.

## 📜 License

Released under the [MIT License](LICENSE).
