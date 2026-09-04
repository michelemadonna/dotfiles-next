# dotfiles-next

> A batteries-included Zsh environment for macOS and Ubuntu 26.04, built around Zsh for Humans.

## ✨ Introduction

`dotfiles-next` is an opinionated collection of shell settings, terminal tools, editor configurations, themes, fonts, and custom Zsh plugins. It provides an interactive installer for personal workstations, a deterministic non-interactive mode for automation, and a complete Docker image for exploring the setup without changing the host.

The default prompt is **Powerlevel10k**. **Oh My Posh** is available as an explicit alternative. 
Zsh for Humans (z4h) bootstraps the shell framework and manages the external Zsh plugins on first startup.

---

## 1. ✅ Prerequisites

The host installer supports:

- macOS on Apple Silicon with Homebrew, macOS on Intel with MacPorts or Homebrew, and Ubuntu 26.04 with APT.
- Zsh already installed and configured as the current user's login shell.
- `curl` and an internet connection.
- An Administrator account with `sudo` access. Run the installer as that normal user, never with `sudo` or as root.
- `bash` on macOS if Homebrew must be installed automatically.

When Homebrew must be installed, the approved interactive run asks once for
the administrator password before starting Homebrew's official installer
without its additional confirmation prompt. Non-interactive runs require
existing non-prompting `sudo` authorization and fail before downloading the
installer when it is unavailable.

With MacPorts selected, the installer installs missing Apple Command Line Tools
headlessly through `softwareupdate` before installing or using MacPorts; it does
not open the graphical `xcode-select --install` prompt. The Apple-provided
`/usr/bin/git` is used only to bootstrap and clone the repository; the base
packages then install Git through MacPorts on Intel when selected, or through
Homebrew on Intel and Apple Silicon.

> ⚠️ **Homebrew on Intel Macs:** Since September 2026, Intel macOS is Homebrew Tier 3: it has no CI support and receives no new binary bottles, so formulae may compile from source, take considerably longer, or fail. The installer therefore recommends and defaults to MacPorts, but allows Homebrew as the primary provider. Homebrew can also be installed manually alongside MacPorts, mainly for casks and formulae unavailable in MacPorts. When MacPorts is selected and both managers are installed, the custom `z4h-pkgmng` plugin keeps MacPorts primary and exposes explicit Homebrew exceptions. See [Homebrew's support tiers](https://docs.brew.sh/Support-Tiers) for the current policy and timeline.

If Zsh is missing, install it with the platform package manager:

```sh
# Apple Silicon macOS
brew install zsh

# Intel macOS with MacPorts (recommended)
sudo /opt/local/bin/port install zsh

# Intel macOS with an existing Homebrew installation
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

Sign out and back in after `chsh`. If Zsh is missing or is not the current user's login shell, the installer stops before changing the system and displays these platform-specific setup instructions.

### 1.1. 📺 Terminal

A terminal with Nerd Font support is strongly recommended because the prompts, tmux status line, and file icons use additional glyphs. The installer uses Homebrew's Fira Code Nerd Font cask on Apple Silicon and the bundled fonts on Intel macOS and Ubuntu 26.04.

#### 👻 Ghostty Terminal

[Ghostty](https://github.com/ghostty-org/ghostty) is a modern, open-source terminal emulator that is lightweight, GPU-accelerated, and cross-platform (macOS  and Ubuntu 🐧).

I chose Ghostty because it is:

- **Cross-platform:** It works seamlessly on both macOS and Ubuntu, ensuring a consistent experience.
- **Easy to install:** Available via Homebrew on macOS and Snap on Ubuntu.
- **Simple to configure:** Just apply the configuration file included in this repository to instantly get my personalized setup.

**Advantages of Ghostty:**

- High performance with minimal resource usage.
- Native GPU rendering and advanced Unicode support.
- Extensive customization for fonts, colors, and layouts.
- Shader support for advanced graphical effects and animations.

This repository includes my personal Ghostty configuration, which applies a slightly customized version of the **Argonaut** theme called **Astronaut**. Another color scheme I really like, **Breeze**, is also included.

Install the latest version of Ghostty:

```bash
brew install ghostty
```

> **Note:** The `ghostty@tip` version is the nightly build, which includes the latest features but may be less stable. The `ghostty` version is the latest stable release. For the best experience with shaders and new features, I recommend using `ghostty@tip`.

Next, configure Ghostty. You can either open its default settings and manually set the font to `FiraCode Nerd Font Mono` with a size of `12.0`:

```text
font-family="FiraCode Nerd Font Mono"
font-size=12.0
```

  or simply create a symbolic link `$HOME/.dotfiles/ghossty` -> `$HOME/.config/` to use the config from this repo:

```bash
mkdir -p $HOME/.config
ln -s $HOME/.dotfiles/local/ghostty $HOME/.config/
```

Restart Ghostty for the changes to take effect.

You can extend the Ghostty configuration included in this repository by creating also a `config.local` file inside `$HOME/.dotfiles/local/ghostty`. Any settings you add to `config.local` will override or supplement the defaults, allowing you to personalize your terminal without modifying the main configuration file (useful with mixed envs like macos/linux).

> ⚠️ **Important: Default config path on macOS**  
> On macOS, Ghostty saves its configuration in  
> `$HOME/Library/Application Support/com.mitchellh.ghostty/config`.  
> If you launched Ghostty **before** creating the symlink to your config in `$HOME/.config`, you must remove the old configuration folder to avoid conflicts:
> 
> ```bash
> rm -rf "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
> ```
> 
> Then restart Ghostty to load your new configuration.

> ⚠️ **Mouse Reporting:** by default, Ghostty is configured to transparently report mouse events to terminal applications. You can hold down the Shift key to bypass mouse reporting temporarily

> ⚠️ **Copying Text from Terminal Applications:** in Ghostty, if standard copy doesn't work inside an app like tmux, **hold the Shift key while selecting text with your mouse, then press Cmd + C**. This bypasses the application's mouse handling and lets the OS capture the text.

#### 📺 iTerm2

[iTerm2](https://iterm2.com/) is a powerful and feature-rich terminal emulator for macOS. This repository includes my personal iTerm2 configuration and color schemes (Argonaut, Breeze) for a consistent experience.

**Advantages of iTerm2:**

- Highly customizable with profiles, color schemes, and fonts.

- Advanced features like split panes, search, triggers, and inline images.

- Excellent integration with macOS, including system clipboard and keychain.

- Built-in support for Powerline and Nerd Fonts.

Install iTerm2 with:

```bash
brew install --cask iterm2
```

To apply my custom settings, follow these steps in iTerm2's **Settings**:

- `General` -> `Selection` -> Uncheck `"Command selection: Clicking on command selects it to restrict Find and Filter"`
- `General` -> `Selection` -> Check `"Access: Application in terminal may access clipboard"`
- `Appearance` -> `General` -> `Theme` -> Select `"Minimal"`
- `Pointer` -> `General` -> `Mouse Reporting` -> Check `"^-Click reported to apps, does not open menu"`
- `Advanced` -> `Drawing` -> `Underline OSC 8 hyperlinks` -> `"No"`
- `Profiles` -> `Default` -> `Other Actions...` -> `Duplicate Profile` -> Name it `"Astronaut Alternative Lighter"`

In the new profile:

- `Colors` -> Uncheck `"Modes : Use separate colors for light and dark mode"`
- `Colors` -> `Color Presets` -> `Import...` -> Import `"$HOME/.dotfiles/iTerm2/Color Schemes/Astronaut Alternative Lighter.iTermColors"`
- `Colors` -> `Color Presets` -> Select `"Astronaut Alternative Lighter"`
- `Colors` -> `Minimum Contrast` -> `7`
- `Text` -> `Cursor` -> Check `"Blink"` and `"Animate movement"`
- `Text` -> `Text rendering` -> Check `"Allow blinking text"`
- `Text` -> `Font` -> Select `"Fira Code Nerd Font Mono"`, `"Retina"`, size `12`
- `Terminal` -> `Shell Integration` -> Uncheck `"Show mark indicators"`
- `Keys` -> `General` -> `Key Reporting` -> Check `"Report keys using CSI u"`
- `Keys` -> `General` -> `Key Behaviour` -> Select `"treat Option as Alt for special keys like arrows"`
- `Keys` -> `General` -> `Left Option key` -> Select `"Esc+"`
- Finally, `Profile` -> `"Astronaut Alternative Lighter"` -> `Other Actions...` -> `Set as Default`

> 💡 On macOS, you may also want to adjust `System Settings -> Appearance -> Show Scroll Bars -> Select "When scrolling"`.

> ⚠️ **Mouse Reporting:** by default, iTerm2 is configured to transparently report mouse events to terminal applications, except for right-click actions. You can temporarily enable right-click reporting by holding the Command key while clicking, or enable it permanently in the settings:  

> `General` → `Pointer` → `General` → Check `"Right Click reported to the apps, does not open menu"`. If you want to disable mouse reporting entirely, you can do so in the same settings menu. Alternatively, you can hold down the Option key to bypass mouse reporting temporarily.

> ⚠️ **Copying Text from Terminal Applications :** to copy text from tmux or similar apps, **hold the Option key while selecting text with your mouse, then press Command + C**. 

---

## 2. 🧰 Components

### 2.1. Core command-line tools

The base package set is installed once per platform. It supplies the commands used by the shell, previews, aliases, and bundled configurations.

| Component                                                | Purpose                                                                                                                                                                                 |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 🦇 **bat**                                               | Syntax-highlighted file viewing. On Ubuntu 26.04 the packaged command is named `batcat`; the preview helper supports both names.                                                        |
| 📁 **eza**                                               | Modern, icon-aware replacement for `ls`.                                                                                                                                                |
| ⚡️ **fd**                                                | Fast file discovery. On Ubuntu 26.04 the package is named `fd-find` and exposes `fdfind`; both the host installer and Docker image add an `fd` compatibility link under `~/.local/bin`. |
| 🦸 **ripgrep**                                           | Fast recursive text search.                                                                                                                                                             |
| 🧩 **git-delta**                                         | Readable, side-by-side diffs.                                                                                                                                                           |
| 🔍 **fzf** and **fzf-tab**                               | Fuzzy file selection and interactive Zsh completion. The shell can use z4h's native `fzf` or a release installed from a local Git checkout.                                             |
| 📺 **chafa**, **mediainfo**, **poppler**, and **file**   | Image, media, PDF, and generic file previews inside fzf.                                                                                                                                |
| 🔀 **tmux**                                              | Persistent terminal sessions with the included mouse and keyboard configuration.                                                                                                        |
| 🛠️ **htop**, **tree**, **wget**, and DNS tools          | Process inspection, directory views, downloads, and host/DNS inspection.                                                                                                                |
| 🔤 [Nerd fonts](https://github.com/ryanoasis/nerd-fonts) | Prompt, file, Git, and tmux glyphs.                                                                                                                                                     |

### 2.2. Shell and optional components

| Component                                            | Status                       | Purpose                                                                                                                                                                                                          |
| ---------------------------------------------------- | ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 🐚 **Zsh for Humans**                                | Core                         | Bootstraps the Zsh environment, manages external plugins, and supplies shell utilities and key bindings.                                                                                                         |
| 🚀 **Powerlevel10k**                                 | Default                      | Fast, Git-aware two-line prompt configured by [`powerlevel10k/.p10k.zsh`](powerlevel10k/.p10k.zsh).                                                                                                              |
| 🎨 **Oh My Posh**                                    | Optional                     | Alternative prompt using the repository's custom JSON theme. Installed only when `ohmyposh` is selected.                                                                                                         |
| 🛠️ **Oh My Zsh helpers**                            | Always enabled                 | Loads selected libraries and plugins such as `sudo`, `command-not-found`, and the macOS/Homebrew helpers without sourcing the complete `oh-my-zsh.sh`.                                                           |
| 🔍 **fzf-tab stack**                                 | Always enabled                 | Adds fuzzy completion, previews, syntax highlighting, history search, and suggestions.                                                                                                                           |
| 🧠 **Completion generator**                          | Optional, enabled by default | Generates and caches getopt-style completion for the current command when explicitly requested with `Shift-Tab`.                                                                                                 |
| 🎨 **Fastfetch**                                     | Optional                     | Displays a visual overview of the operating system, hardware, memory, disks, shell, terminal, and other system details. It can run at every interactive Zsh startup or only at the first active terminal prompt. |
| 📦 **Mise**                                          | Optional, enabled by default | Installs and activates language/tool runtimes, and maintains compatibility with `.tool-versions`. It is also preinstalled in the Docker demo.                                                                    |
| ✏️ **Micro**, **Fresh Editor**, **Vim**, or **Nano** | Select one                   | Configures the requested default editor; Micro is the default. macOS uses its architecture-selected package manager except for the system Vim; Ubuntu uses APT. Repository configurations are linked for the selected editor. |

The repository also contains configurations for **Git**, **Ghostty**, **iTerm2**, **Fastfetch**, **Mise**, **SSH**, **ripgrep**, **tmux**, **Micro**, and **Fresh Editor**. Some are reference configurations and are not all linked by the host installer.

### 2.3. Custom Zsh plugins

The project-specific plugins live in [`zsh/z4h.custom.plugins`](zsh/z4h.custom.plugins) and are loaded from the main Zsh configuration.

| Plugin             | What it does                                                                                                                                                                                                                                                                                                 |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `z4h-fzf`          | Extends fzf-tab, `Ctrl-T`, and `Alt-C` with shared hidden-file state, alphabetically ordered filesystem candidates, persistent preview layout, contextual previews, grouped Git refs and recent commits, and command-specific views for Git, Docker, package managers, SSH, processes, manuals, and systemd. It also integrates the vendored `fzf-git.sh` pickers for files, branches, tags, remotes, commits, stashes, reflogs, worktrees, and refs. |
| `z4h-containers`   | Adds Docker and kubectl aliases, caches CLI-generated completion, improves Docker completion contexts, and supplies JSON/YAML kubectl helpers when the required tools are available.                                                                                                                         |
| `z4h-eza`          | Replaces common `ls` forms with an icon-aware `eza` configuration and falls back to `exa` when necessary. Provides `ll` and `lls`.                                                                                                                                                                           |
| `z4h-gencomp-lazy` | Generates completion from a command's help output on explicit `Shift-Tab`, caches it, loads it immediately, and remembers failed attempts for the current session. It also provides the manual `gencomp` command.                                                                                            |
| `z4h-mise`         | Caches Mise activation and completion, avoids duplicate hooks, refreshes immediately after directory changes and successful `mise` commands, throttles unchanged prompts, provides `asdf` compatibility, and synchronizes `mise use` selections to `.tool-versions`.                                         |
| `z4h-pkgmng`       | On Intel macOS with MacPorts selected and both managers installed, keeps MacPorts primary while exposing explicitly selected Homebrew commands, completions, rescans, and an isolated Homebrew shell.                                                                                |
| `z4h-oh-my-posh`   | Loads Oh My Posh only when selected and caches the generated Zsh initialization until the binary, theme, or plugin changes.                                                                                                                                                                                  |
| `z4h-misc`         | Provides compatibility aliases, the optional allafine behavior, and a searchable `Ctrl-K` keybinding reference for Zsh, fzf, tmux, and Micro.                                                                                                                                                                |

---

## 3. 🚀 Installation

The installer checks the platform, installs Git when necessary, clones the repository into `~/.dotfiles`, installs the base packages, and creates the required configuration links.

### Launch the installer

Use an Administrator account, but do not run the installer with `sudo` and do
not start it from a root shell. The installer explains every privileged
operation before invoking `sudo` for that individual command. On Intel macOS,
the wizard asks whether to use the recommended MacPorts backend or Homebrew;
the selected installer may request privileges for its default prefix.

To download and launch the interactive installer:

```sh
curl -fsSL https://raw.githubusercontent.com/michelemadonna/dotfiles-next/main/install.sh -o /tmp/dotfiles-next-install.sh && sh /tmp/dotfiles-next-install.sh
```

To run without prompts, use:

```sh
sh /tmp/dotfiles-next-install.sh non-interactive
```

Non-interactive Intel installations default to MacPorts. Select Homebrew with:

```sh
DOTFILES_INTEL_PACKAGE_MANAGER=homebrew \
  sh /tmp/dotfiles-next-install.sh non-interactive
```

Alternatively, clone the repository and launch the local copy:

```sh
git clone https://github.com/michelemadonna/dotfiles-next.git ~/.dotfiles
sh ~/.dotfiles/install.sh
```

Existing regular files or directories at managed destinations are moved to a timestamped `.backup.YYYYMMDDhhmmss` path before linking. Existing symbolic links are replaced. Repeated non-interactive runs retain existing generated preferences while normalizing the three fixed fzf/Oh My Zsh values; interactive runs write the newly approved choices. Both modes reevaluate optional tools and skip the versioned base-package step when its marker exists.

After installation, start a fresh login shell:

```sh
exec zsh -l
```

The first Zsh startup downloads z4h and the enabled external plugins, so it requires an internet connection and can take longer than subsequent starts.

To remove every cache and persistent state file created by this environment,
run:

```zsh
z4h-reset-zsh-cache
```

Use `--dry-run` to inspect the exact paths, `--yes` to skip confirmation, or `--no-restart` to leave the current shell running. Normally the function restarts Zsh; that startup requires network access to download z4h again.
Because the installer marker is removed, the next installer run executes the base-package step again.

---

## 4. 🔧 Customization

The primary shell configuration is [`zsh/home/.zshrc`](zsh/home/.zshrc).
The installer creates or retain [`zsh/home/.zshenv`](zsh/home/.zshenv), and creates a symlink `~/.zshenv` that points to it.
Shell startup puts `$HOME/.local/bin` at the front of `PATH`; `.zshrc` reapplies
it before z4h initialization so macOS login-shell startup cannot discard it.
Cached Mise activation also preserves the current startup paths.

### Intel macOS package providers

The Intel installer asks which package manager should provide the base tools.
MacPorts is recommended and is the default; Homebrew can be selected despite
its Tier 3 limitations. `DOTFILES_INTEL_PACKAGE_MANAGER=macports|homebrew`
controls non-interactive runs and is persisted in `zsh/home/.zshenv` so later
automatic tool installation keeps the same provider.

When MacPorts is selected, `/opt/local/bin` and `/opt/local/sbin` take
precedence and Homebrew's `/usr/local/bin` and `/usr/local/sbin` are excluded
from the normal shell `PATH`. If Homebrew is also installed manually, the
custom `z4h-pkgmng` plugin is enabled and the following commands manage
explicit Homebrew exceptions:

```zsh
pkg-bootstrap [formula ...]
pkg-rescan [formula ...]
pkg-default <command> <brew|macports>
pkg-which <command>
pkg-list
pkg-clean
brew-bottle-check <formula> [formula ...]
brew-shell
```

`pkg-default` choices persist under `${XDG_STATE_HOME:-$HOME/.local/state}`.
Rescans and upgrades preserve commands explicitly assigned to MacPorts. A
normal `brew install` registers commands from newly installed formulae as
Homebrew defaults, while `brew-shell` provides a temporary full Homebrew
environment. The installer never falls back from a missing MacPorts port to
Homebrew. When Homebrew is selected as the primary provider, `/usr/local` is
used normally and the MacPorts-primary coexistence plugin remains disabled.

`brew-bottle-check` performs a metadata-only preflight for the requested
formulae and their recursive required/recommended dependencies. It reports
whether a normal Homebrew installation currently selects a bottle or a source
archive without downloading or installing either. The check uses only Zsh and
Homebrew; it does not require `jq`, Python, or another parser. Its exit status
is `0` for bottles only, `1` when compilation would be required, and `2` for
invalid input or a Homebrew query error. Formula completion and metadata
preview work through fzf-tab.

The installer manages those symbolic links:

- The ZSH and base tools configurations
  * `~/.zshenv` → `~/.dotfiles/zsh/home/.zshenv`
  * `~/.ssh/config` → `~/.dotfiles/ssh/config`
  * `~/.config/git` → `~/.dotfiles/git`
  * `~/.config/tmux` → `~/.dotfiles/tmux`
  * `~/.config/ripgrep` → `~/.dotfiles/ripgrep`
- The selected editor's configuration when using Micro or Fresh and relative configs
  * `~/.config/micro` → `~/.dotfiles/micro`
  * `~/.config/fresh` → `~/.dotfiles/fresh`
  * `~/.config/nano` → `~/.dotfiles/nano`
  * `~/.config/vim` → `~/.dotfiles/vim`
  * Nano backups → `~/.cache/nano/backups`
- Fastfetch and Mise configuration when those components are installed
  * `~/.config/fastfetch` → `~/.dotfiles/fastfetch`
  * `~/.config/mise` → `~/.dotfiles/mise`
- Powerlevel10K and Oh-My-Posh (if installed) configs are managed using the envs in the `zsh/home/.zshenv` file
  * `POWERLEVEL9K_CONFIG_FILE="$DOTFILES_DIR/powerlevel10k/.p10k.zsh`" 
  * `Z4H_OH_MY_POSH_CONFIG="$DOTFILES_DIR/oh-my-posh/custom.omp.json`"

The envs defined into `zsh/home/.zshenv`:

When `python3` is available, the generated environment also defines `python`
as an alias for `python3`.

* `Z4H_PROMPT` Selects the prompt theme. Supported values are `powerlevel10k`, `ohmyposh`, and `minimal`.
* `DOTFILES_INTEL_PACKAGE_MANAGER` selects `macports` or `homebrew` as the Intel macOS installer and shell provider. It defaults to `macports` and has no effect on Apple Silicon or Linux.
* `Z4H_SHOW_FASTFETCH` Controls when Fastfetch is displayed. Set it to `false` to disable Fastfetch, `true` to display it at every interactive terminal startup, or `first` to display it only in the first active terminal session.
* `Z4H_ENABLE_AUTO_GENCOMP` Enables on-demand generation of Zsh completions for commands that do not already provide them. Completions are generated from the command’s `--help` output.
* `Z4H_SSH_LOAD_KEY` Controls automatic SSH key loading. When enabled, private keys found in `$HOME/.ssh` are loaded into the active SSH agent or platform keychain.
* `Z4H_SSH_SHOW_KEY` Controls whether the SSH keys currently loaded in the agent are displayed during shell startup.
* `Z4H_SSH_ASKPASS_REQUIRE` Controls SSH passphrase prompting. When enabled, SSH is required to use an askpass mechanism whenever a private key needs to be unlocked.
* `Z4H_USE_MISE` Enables Mise integration. When enabled, Mise is installed automatically if necessary and initialized for runtime management, activation, completions, and asdf-compatible plugins.
* `Z4H_USE_FZF_TAB` is always `true`; it remains exported for compatibility.
* `Z4H_ENABLE_OH_MY_ZSH` is always `true`; it remains exported for compatibility.
* `Z4H_USE_FZF_FROM_Z4H` is always `false`; the installer uses the latest fzf binary from its local Git checkout and keeps this variable exported for compatibility.
* `Z4H_MISE_REFRESH_SECONDS` Controls the periodic safety refresh performed by Mise. The default is `5` seconds. Directory changes, `PATH` changes, and successful `mise` commands always trigger an immediate refresh. Set it to `0` to refresh Mise before
  every prompt.
* `POWERLEVEL9K_CONFIG_FILE` the powerlevel10k's config file path.
* `Z4H_OH_MY_POSH_CONFIG` the oh-my-posh's config file path.

Other than env variable configured in `zsh/home/.zshenv` :

- **git** include can automativìcally load a local configuration if the file `$HOME/.config/git/local.gitconfig` is present. 
- **tmux** loads `~/.tmux.conf.local` when that file exists.
- **ssh** can use `$HOME/.ssh/local.sshconfig` for your host-specific settings.

Store machine-specific shell values in `~/.env.zsh`; it is sourced automatically when present. 

---

## 5. 🐳 Docker demo

The Dockerfile builds a **complete demonstration and preview environment**, not a small production image. It is based on Ubuntu 26.04 and includes the base tools, optional editors, Fastfetch, Mise, Oh My Posh, OpenSSH client, Java, Python, Node.js, and all repository configurations.

To use the demo image, install Docker Desktop or Docker Engine with BuildKit. Building the image requires internet access and considerably more time and disk space than the host installation.

By default, the build clones the `main` branch from this GitHub repository, so the resulting image does not depend on uncommitted files in the current directory:

```sh
./docker-demo.sh
```

For the default remote source, `docker run -it` starts the repository's **interactive** installer before entering Zsh. 

To test the files from the current directory instead, select the local source explicitly. This mode runs `install.sh non-interactive` during the build and starts Zsh directly when the container runs:

```sh
./docker-demo.sh local
```

The script accepts `remote` (the default) or `local`, builds `dotfiles-next-demo`, and launches it with an interactive TTY. Set `DOCKER_IMAGE` to use another image name. 
The equivalent manual commands are:

```
docker build -t dotfiles-next-demo .
docker run --rm -it dotfiles-next-demo \
  --build-arg DOTFILES_SOURCE=local #to the build command for local sources.
```

Remote builds can target another repository or branch without editing the Dockerfile:

```sh
docker build \
  --build-arg DOTFILES_REPO_URL=https://github.com/example/dotfiles.git \
  --build-arg DOTFILES_REF=feature-branch \
  -t dotfiles-next-demo .
```

---

## 6. 📁 Repository layout

| Path                                                                | Contents                                                                                      |
| ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| [`install.sh`](install.sh)                                          | Interactive and non-interactive host installer.                                               |
| [`Dockerfile`](Dockerfile) / [`docker-demo.sh`](docker-demo.sh)     | Complete remote/local demonstration image and its launcher.                                   |
| [`Dockerfile.test`](Dockerfile.test)                                | Minimal disposable Ubuntu shell for installer testing.                                        |
| [`AGENTS.md`](AGENTS.md)                                            | Repository-specific instructions, constraints, and validation requirements for coding agents. |
| [`docs/`](docs)                                                     | Technical architecture, installer, Docker, and testing notes for maintainers and agents.      |
| [`zsh`](zsh)                                                        | Zsh startup files, Powerlevel10k configuration, helpers, and custom plugins.                  |
| [`powerlevel10k`](powerlevel10k)                                    | Default Powerlevel10k prompt configuration.                                                   |
| [`git`](git)                                                        | Git defaults plus local, personal, and work include examples.                                 |
| [`tmux`](tmux)                                                      | tmux configuration with an `Alt-A` prefix, mouse support, and top status line.                |
| [`micro`](micro) / [`fresh`](fresh)                                 | Editor settings and bundled Micro plugins.                                                    |
| [`oh-my-posh`](oh-my-posh)                                          | Custom Oh My Posh theme.                                                                      |
| [`fastfetch`](fastfetch) / [`mise`](mise)                           | System-summary and runtime-manager settings.                                                  |
| [`ghostty`](ghostty) / [`iTerm2`](iTerm2)                           | Terminal settings, themes, profiles, and shaders.                                             |
| [`fonts`](fonts)                                                    | Nerd Fonts used by the shell UI.                                                              |
| [`ssh`](ssh) / [`ripgrep`](ripgrep)                                 | SSH client and ripgrep configuration.                                                         |
| [`fhome.sh`](fhome.sh) / [`start_benchmark.sh`](start_benchmark.sh) | Isolated test-shell launcher and Zsh startup benchmark helper.                                |

---

## 7. ⌨️ Useful keys

### 7.1. 🐚 Zsh

| Key                                                           | Action                                                                          |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| <kbd>Ctrl</kbd> + <kbd>R</kbd>                                | Search history (fzf).                                                           |
| <kbd>Esc</kbd> + <kbd>Esc</kbd>                               | Insert `sudo` before the last command.                                          |
| <kbd>Ctrl</kbd> + <kbd>T</kbd>                                | Fuzzy file path completion (fzf).                                               |
| <kbd>Alt</kbd> + <kbd>C</kbd> / <kbd>Esc</kbd> + <kbd>C</kbd> | `cd` into a selected subdirectory (fzf).                                        |
| <kbd>Tab</kbd>                                                | Open autocomplete menu with fzf (fzf-tab).                                      |
| <kbd>Shift</kbd> + <kbd>Tab</kbd>                             | Generate completion for the current command from its help output, then open it. |
| <kbd>Ctrl</kbd> + <kbd>H</kbd>                                | Toggle hidden files in FZF search.                                              |

### 7.2. 🔍 fzf

| Key                                           | Action                                                                                                                      |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| <kbd>↑</kbd> / <kbd>↓</kbd>                   | Move up/down.                                                                                                               |
| <kbd>Tab</kbd>                                | Cycle selection.                                                                                                            |
| <kbd>Ctrl</kbd> + <kbd>Space</kbd>            | Mark/unmark item.                                                                                                           |
| <kbd>Ctrl</kbd> + <kbd>A</kbd>                | Toggle all marked/unmarked.                                                                                                 |
| <kbd>Enter</kbd>                              | Select the current item(s).                                                                                                 |
| <kbd>Ctrl</kbd> + <kbd>P</kbd>                | Cycle preview through right 50% (default), bottom 50%, bottom 90%, and hidden; bottom Git previews use a side-by-side diff. |
| <kbd>Ctrl</kbd> + <kbd>F</kbd>                | Cycle the persistent fzf height: 33%, 50%, 66%, and 99%, keeping the current prompt visible.                                |
| <kbd>Ctrl</kbd> + <kbd>J</kbd> / <kbd>K</kbd> | Scroll preview window down/up.                                                                                              |
| <kbd>></kbd> / <kbd>></kbd>                   | Switch group (fzf-tab).                                                                                                     |
| <kbd>Ctrl</kbd> + <kbd>K</kbd>                | Open the searchable custom keybinding reference.                                                                            |

Inside a Git repository, `Ctrl-G` followed by `F`, `B`, `T`, `R`, `H`, `S`,
`L`, `W`, or `E` opens the corresponding fzf-git picker for files, branches,
tags, remotes, commit hashes, stashes, reflogs, worktrees, or refs. Git-aware
TAB completion is also enabled for branch, checkout, switch, restore, add,
diff, show, log, merge, rebase, cherry-pick, revert, reset, stash, worktree,
remote, fetch, pull, and push. These are the original vendored fzf-git menus,
including their upstream previews and mode-specific actions. Within the compatible files,
commit-files, branches, tags, hashes, and each-ref menus, `Alt-B`, `Alt-T`,
`Alt-H`, `Alt-E`, and `Alt-W` switch directly to branches, tags, hashes, every
ref, and working-tree files. `Alt-F` opens working-tree files except in Hashes,
where it retains the upstream files-of-selected-commits action. `Alt-V` opens
the editor in Files and Each-ref. Existing actions such as `Alt-A`, `Alt-R`,
`Ctrl-O`, and `Ctrl-D` remain available. TAB only advertises transitions valid
for its current Git command; direct `Ctrl-G` pickers expose every mode.
`Ctrl-G Ctrl-E` opens the upstream `for-each-ref` picker covering every ref.
`Ctrl-G` is handled as an explicit prefix, so the second key is not constrained
by z4h's normal multi-key `KEYTIMEOUT`.

TAB starts Each-ref for ambiguous ref contexts such as branch start-points,
checkout, switch, merge, rebase, worktree creation, restore sources, and
refspecs after a remote; Hashes for show, log, reset, cherry-pick, and revert;
and Files for pathspec
contexts. Branch deletion, upstream and description operands use Branches;
worktree removal, locking, unlocking, and moving use Worktrees. Plain
`git branch TAB` and `git worktree TAB` still delegate to normal completion
because Git expects a new branch name or a worktree subcommand there.

fzf-git shares the persisted preview layout and height with the other pickers:
`Ctrl-P` changes the preview while the picker is open, and the height selected
with `Ctrl-F` is applied on the next launch (fzf cannot resize an open picker).
`Ctrl-H` is not needed inside fzf-git: its file picker already includes tracked
and untracked dotfiles from Git status/index data.

The pinned upstream revision requires fzf 0.66 or newer. The installer always
uses (`Z4H_USE_FZF_FROM_Z4H=false`), verifies, and keeps the latest
checkout under `~/.local/share/fzf`; older fzf versions retain separate
compatible pickers and normal fzf-tab fallback. Git 2.42 or newer is required
for the `for-each-ref` picker. Because upstream fzf-git uses newline-delimited
selection output, filenames containing embedded newlines are not supported by
its widgets. `Ctrl-G Ctrl-B` can conflict with a tmux `Ctrl-B` prefix,
`Ctrl-G Ctrl-S` requires terminal flow control not to consume `Ctrl-S`, and
very small `KEYTIMEOUT` values can make two-key sequences difficult to enter.

### 7.3. 🔀 tmux

| Key                                                                                                       | Action                                                |
| --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| <kbd>Alt</kbd> + <kbd>A</kbd>                                                                             | Prefix key (instead of <kbd>Ctrl</kbd>+<kbd>B</kbd>). |
| `Prefix` then <kbd>C</kbd>                                                                                | New window.                                           |
| `Prefix` then <kbd>-</kbd>                                                                                | Horizontal split.                                     |
| `Prefix` then <kbd>\|</kbd>                                                                               | Vertical Split                                        |
| `Prefix` then <kbd>d</kbd>                                                                                | Detach session.                                       |
| `Prefix` then <kbd>+</kbd>                                                                                | Zoom the current pane.                                |
| `Prefix`  then <kbd>↑</kbd> / <kbd>↓</kbd> / <kbd>←</kbd> / <kbd>→</kbd>                                  | Move between panes.                                   |
| `Prefix` then <kbd>Alt</kbd> +<kbd>shift</kbd>  <kbd>↑</kbd> / <kbd>↓</kbd> / <kbd>←</kbd> / <kbd>→</kbd> | Resize panes.                                         |
| `Prefix`  then <kbd>R</kbd>                                                                               | Reload tmux config                                    |
| `Prefix`  then <kbd>Alt</kbd>+<kbd>S</kbd>                                                                | Sync input to all panes                               |
| `Prefix`  then <kbd>Ctrl</kbd>+<kbd>S</kbd>                                                               | Hide status bar                                       |

### 7.4. ✏️ micro

| Key                                                             | Action                       |
| --------------------------------------------------------------- | ---------------------------- |
| <kbd>Ctrl</kbd> + <kbd>O</kbd>                                  | Open file                    |
| <kbd>Ctrl</kbd> + <kbd>S</kbd>                                  | Save                         |
| <kbd>Ctrl</kbd> + <kbd>Q</kbd>                                  | Quit                         |
| <kbd>Ctrl</kbd> + <kbd>F</kbd>                                  | Find                         |
| <kbd>Ctrl</kbd> + <kbd>Z</kbd> / <kbd>Ctrl</kbd> + <kbd>Y</kbd> | Undo / Redo                  |
| <kbd>Ctrl</kbd> + <kbd>X</kbd> / <kbd>C</kbd> / <kbd>V</kbd>    | Cut / Copy / Paste           |
| <kbd>Ctrl</kbd> + <kbd>E</kbd>                                  | Open Command bar             |
| <kbd>Ctrl</kbd> + <kbd>T</kbd>                                  | Add new tab                  |
| <kbd>Alt</kbd> + <kbd>,</kbd> / <kbd>.</kbd>                    | Previous / Next tab          |
| <kbd>Ctrl</kbd> + <kbd>R</kbd>                                  | Toggle the line number ruler |

---

## 8. 🛠️ Optional Components & Configuration

### 8.1. ✏️ Editors

> **Unpopular opinion**
> 
> Using Vim, Emacs, or their modal distributions in 2026 is masochistic nostalgia. They work, of course, but you end up spending more time learning key combinations than actually writing code. Development today is local, on powerful machines with GUIs, mice, and clipboards: VS Code, Zed, Sublime, or Notepad++ do everything instantly, with human-friendly keybindings and built-in LSP. Doom Emacs and LazyVim? Interesting for hobby projects or SSH, but for real work they’re just unnecessary overhead—and on remote machines, you often don’t have the rights to install a full Vim or Emacs distribution. True efficiency isn’t flying across the keyboard—it’s reducing mental friction.

#### 8.1.1. Micro Editor

[**Micro**](https://micro-editor.github.io) is a modern, easy-to-use terminal-based text editor with a clean UI, mouse support, and a powerful plugin system. 
This repository includes my personal Micro configuration to get you started productively.

##### Installation

in vour $HOME/.zshenv file, modify the `EDITOR` variable to set Micro as your default editor:

```bash
export EDITOR=micro
```

and reopen your terminal or start a fresh login shell:

```sh
exec zsh -l
```

micro will be automatically installed at shell startup if it is not already present on your system.
My micro configuration in `$HOME/.dotfiles/micro` will be automatically linked to `$HOME/.config/micro` during the installation process.

If you want to use your own custom micro configuration, remove the symlink or point it to your custom configuration directory.

##### Plugins

You can easily manage plugins directly from within Micro:

- To list installed plugins:  
    <kbd>Ctrl</kbd> + <kbd>E</kbd> then type `plugin list`
- To see available plugins:  
    <kbd>Ctrl</kbd> + <kbd>E</kbd> then type `plugin available`
- To install a plugin:  
    <kbd>Ctrl</kbd> + <kbd>E</kbd> then type `plugin install <plugin-name>`
- To remove a plugin:  
    <kbd>Ctrl</kbd> + <kbd>E</kbd> then type `plugin remove <plugin-name>`

some useful plugins are :

- [filemanager](https://github.com/NicolaiSoeborg/filemanager-plugin) — Tree-based file explorer 
- [fzf](https://github.com/samdmarshall/micro-fzf-plugin) — Fuzzy file finder

##### Basic Usage

1. Press <kbd>Ctrl</kbd> + <kbd>E</kbd> to open the command bar and type `open myfile.txt` to open a file.
2. Press <kbd>Ctrl</kbd> + <kbd>E</kbd> and type `hsplit` to create a horizontal split.
3. In the new split (bottom pane), press <kbd>Ctrl</kbd> + <kbd>E</kbd> and type `term` to open a terminal.

This allows you to edit files and run terminal commands side by side within Micro.

> ⚠️ **macOS Clipboard Alert:** on macOS, you **cannot use <kbd>Command</kbd> + <kbd>C</kbd> to copy text in Micro**—neither for pasting inside Micro nor into other applications. **Always use <kbd>Ctrl</kbd> + <kbd>C</kbd> to copy text within Micro.**. However, you can use <kbd>Command</kbd> + <kbd>V</kbd> to paste text both inside Micro and into other apps.

#### 8.1.2. Fresh editor

[Fresh]([GitHub - sinelaw/fresh: Text editor for your terminal: easy, powerful and fast](https://github.com/sinelaw/fresh)) is a **modern, minimal, terminal-based text editor** that aims to provide a simple, fast, and non-modal editing experience. Unlike Vim or Emacs, it doesn’t rely on complex modes or steep learning curves, making it more approachable for users used to GUI editors like VS Code, Sublime, or Notepad++.

Here are the key points about Fresh:

- **File Management**: open/save/new/close, file explorer, tabs, auto-revert, git file finder
- **Editing**: undo/redo, multi-cursor, block selection, smart indent, comments, clipboard
- **Search & Replace**: incremental search, find in selection, query replace, git grep
- **Navigation**: go to line/bracket, word movement, position history, bookmarks, error navigation
- **Views & Layout**: split panes, line numbers, line wrap, backgrounds, markdown preview
- **Language Server (LSP)**: go to definition, references, hover, code actions, rename, diagnostics, autocompletion
- **Productivity**: command palette, menu bar, keyboard macros, git log, diagnostics panel
- **Plugins & Extensibility**: TypeScript plugins, color highlighter, TODO highlighter, merge conflicts, path complete, keymaps
- **Internationalization**: Multiple language support (see [`locales/`](https://github.com/sinelaw/fresh/blob/master/locales) for available languages), plugin translation system

##### Installation

in vour $HOME/.zshenv file, modify the `EDITOR` variable to set Micro as your default editor:

```bash
export EDITOR=fresh
```

and reopen your terminal or start a fresh login shell:

```sh
exec zsh -l
```

fresh will be automatically installed at shell startup if it is not already present on your system.
My fresh configuration in `$HOME/.dotfiles/fresh` will be automatically linked to `$HOME/.config/fresh` during the installation process.

If you want to use your own custom fresh configuration, remove the symlink or point it to your custom configuration directory.

> **Fresh keymapping on Macos**
> 
> The macOS keymap is designed around these constraints:
> 
> To use completition with <kbd>Ctrl</kbd>+<kbd>Space</kbd>, you need to disable the default macOS shortcut to select the previous input source, which is <kbd>Ctrl</kbd>+<kbd>Space</kbd> by default. This can be done in System Settings > Keyboard > Keyboard Shortcuts ... > Input Sources > Disable "Select the previous input source"
> **Ctrl+Shift combinations don't work.** Some macOS terminals cannot reliably send <kbd>Ctrl</kbd>+<kbd>Shift</kbd> sequences. For example, <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Z</kbd> produces a caron character (ˇ) instead of being recognized as a key chord. The macOS keymap uses <kbd>Ctrl</kbd>+<kbd>Alt</kbd> as an alternative modifier.
> 
> **Some <kbd>Ctrl</kbd> keys are ASCII control characters.** In terminal protocols, <kbd>Ctrl</kbd>+<kbd>J</kbd> is Line Feed (newline), <kbd>Ctrl</kbd>+<kbd>M</kbd> is Carriage Return (Enter), and <kbd>Ctrl</kbd>+<kbd>I</kbd> is Tab. Binding actions to these keys causes erratic behavior. The macOS keymap avoids these collisions.
> 
> **International keyboards use Alt for essential characters.** On German, French, and other ISO layouts, <kbd>Alt</kbd> (Option) combined with letters produces characters like @, [, ], {, and }. The macOS keymap avoids <kbd>Alt</kbd>+letter combinations that would block character input.
> 
> **Unix readline conventions are preserved.** Terminal users expect <kbd>Ctrl</kbd>+<kbd>Y</kbd> to "yank" (paste from the kill ring), <kbd>Ctrl</kbd>+<kbd>K</kbd> to kill to end of line, and <kbd>Ctrl</kbd>+<kbd>U</kbd> to kill to start of line. The macOS keymap respects these conventions rather than overriding them with GUI editor shortcuts.
> 
> Use the **Command Palette** (<kbd>Ctrl</kbd>+<kbd>P</kbd>) or **Show Keybindings** (<kbd>Ctrl</kbd>+<kbd>H</kbd>) to discover the actual key bindings, or view the keymap file directly at `keymaps/macos.json` or `keymaps/macos-gui.json`.

### 8.2. 📦 mise (Universal Runtime Version Manager)

[**mise**](https://github.com/jdx/mise) is a fast, modern CLI tool for managing multiple versions of programming languages and tools (Java, Node.js, Python, kubectl, and more). It uses a `.tool-versions` file to automatically switch versions as you move between directories, making development environments consistent and reproducible.

#### Installation

in vour $HOME/.zshenv file, modify the `Z4H_USE_MISE` variable to enable mise integration:

```bash
export Z4H_USE_MISE=true
```

and reopen your terminal or start a fresh login shell:

```sh
exec zsh -l
```

mise will be automatically installed at shell startup if it is not already present on your system.
My mise configuration in `$HOME/.dotfiles/mise` will be automatically linked to `$HOME/.config/mise` during the installation process.

This will load the customized mise integration (with Powerlevel10k segments support and a more convenient completion for using the various runtimes versions) before your plugins.

If you want to use your own custom mise configuration, remove the symlink or point it to your custom configuration directory.

#### Usage

```bash
# Install a specific version of a runtime
mise install java@21.0.2

# Set the global (user-wide) version
mise use -g java@21.0.2

# Use the system-provided runtime version
mise use -g java@system

# Set a project-specific version
cd /path/to/your/project
mise use java@17.0.2
```

If a `mise.toml` or `.tool-versions` file is present in a project directory, mise will automatically switch to the specified versions when you enter that directory or open it in your editor.

> **Tip:**  
> You can use `mise use -g <runtime>@system` to select the system-installed version of a tool/runtime if available.
> Use `mise install <runtime>@latest` to download and install the latest version of a tool/runtime.

### 8.3. 🎨 Fastfetch

Many users love having a stylish system info summary in their terminal. [**Fastfetch**](https://github.com/fastfetch-cli/fastfetch) is a blazing-fast, highly customizable tool for displaying system information with beautiful ASCII logos and colors.

This repository includes my personal Fastfetch configuration at `$HOME/.dotfiles/fastfetch/config/config.jsonb`.

#### Installation

in vour $HOME/.zshenv file, modify the `Z4H_SHOW_FASTFETCH` variable to enable fastfetch integration:

```bash
export Z4H_SHOW_FASTFETCH=true #shows fastfetch at every new terminal session
or
export Z4H_SHOW_FASTFETCH=first #shows fastfetch only on the first pts/ttys
```

and reopen your terminal or start a fresh login shell:

```sh
exec zsh -l
```

fastfetch will be automatically installed at shell startup if it is not already present on your system.
My fastfetch configuration in `$HOME/.dotfiles/fastfetch` will be automatically linked to `$HOME/.config/fastfetch` during the installation process.
The Fastfetch configuration is set up automatically using `$HOME/.config/fastfetch/config.jsonc`.
If you want to use your own custom fastfetch configuration, remove the symlink or point it to your custom configuration directory.

### 8.4. 🎨 Oh My Posh

[Oh My Posh](https://ohmyposh.dev) is a cross-platform prompt theme engine that brings beautiful, customizable prompts to Zsh, Bash, PowerShell, and more.

#### Installation

in vour $HOME/.zshenv file, modify the `Z4H_PROMPT` variable to enable fastfetch integration:

```bash
export Z4H_PROMPT=ohmyposh
```

and reopen your terminal or start a fresh login shell:

```sh
exec zsh -l
```

oh-my-posh will be automatically installed at shell startup if it is not already present on your system.
The oh-my-posh configuration is set up automatically using `Z4H_OH_MY_POSH_CONFIG="$DOTFILES_DIR/oh-my-posh/custom.omp.json"` in $HOME/.zshenv.
If you want to use your own custom oh-my-posh configuration change the env to use your configuration.

- **Built-in theme:** 
  Set `Z4H_OH_MY_POSH_CONFIG` to the name of any theme included with Oh My Posh (e.g., `paradox`, `jandedobbeleer`, `powerlevel10k`):
  
  ```bash
  export Z4H_OH_MY_POSH_CONFIG="paradox"
  ```

Restart your terminal to apply the changes. 
For more themes and customization options, see the [Oh My Posh theme gallery](https://ohmyposh.dev/themes).

To revert to `powerlevel10K`, simply revert the `Z4H_PROMPT` env variable.

### 8.5. 🔀 tmux

[**tmux**](https://github.com/tmux/tmux) is a terminal multiplexer that lets you manage multiple terminal sessions within a single window. The custom `$HOME/.tmux.conf` included in this repository features an ergonomic <kbd>Alt</kbd> + <kbd>A</kbd> prefix, persistent sessions, a clean status bar, intuitive keybindings, mouse support, and clipboard integration.

#### Example workflow:

1. Start a new session: `tmux`
2. Split window horizontally: <kbd>Alt</kbd>+<kbd>A</kbd> then <kbd>-</kbd>
3. Split vertically: <kbd>Alt</kbd>+<kbd>A</kbd> then <kbd>|</kbd>
4. Move between panes: <kbd>Alt</kbd>+<kbd>A</kbd> then + <kbd>↑</kbd> / <kbd>↓</kbd> / <kbd>←</kbd> / <kbd>→</kbd>
5. Resize panes: <kbd>Alt</kbd>+<kbd>A</kbd> then <kbd>Alt</kbd> + <kbd>Shift</kbd>+<kbd>↑</kbd> / <kbd>↓</kbd> / <kbd>←</kbd> / <kbd>→</kbd>
6. Detach from session: <kbd>Alt</kbd>+<kbd>A</kbd> then <kbd>D</kbd>
7. Reattach to the last session: `tmux attach`
8. Toggle the status bar: <kbd>Alt</kbd> + <kbd>A</kbd> then <kbd>Ctrl</kbd> + <kbd>S</kbd>
9. Sync input to all panes: <kbd>Alt</kbd> + <kbd>A</kbd> then <kbd>Alt</kbd> + <kbd>S</kbd>
   (This enables or disables synchronized input, so your keystrokes are sent to all panes at once—useful for running the same command in multiple panes.)

> 🖱️ **Mouse support** is fully enabled in tmux: you can seamlessly move between panes and windows, resize them, scroll, and interact directly using your mouse. By right-clicking and holding on Ghostty, the **tmux context menu** will open. If you are using iTerm, you also need to hold the <kbd>Command</kbd> key while right-clicking.

### 8.6. 🔍 fzf

[**fzf**](https://github.com/junegunn/fzf) is a fast, interactive fuzzy finder that is deeply integrated into this setup. It powers history search, file completion, and directory navigation, making your command-line interactions incredibly efficient. With the `fzf-tab` plugin, you can press <kbd>Tab</kbd> to trigger an fzf-powered completion menu for almost any command, files, and directories. For example, typing `micro <Tab>` will open a fuzzy search menu to quickly select the file you want to edit. 

#### Common usage examples:

- **Fuzzy history search:** Press <kbd>Ctrl</kbd> + <kbd>R</kbd> to search your shell history.
- **Fuzzy file path completion:** Press <kbd>Ctrl</kbd> + <kbd>T</kbd> to find a file and insert its path.
- **Fuzzy cd into a subdirectory:** Press <kbd>Alt</kbd> + <kbd>C</kbd> to find and `cd` into a directory.
- **Kill a process interactively:** Type `kill` and press <kbd>Tab</kbd> to select a process to kill.
- **Run a Docker container:** Type `docker run` and press <kbd>Tab</kbd> to select a container to run.
- **Checkout a git branch:** Type `git checkout` and press <kbd>Tab</kbd> to select a branch.

## 9. 🔐 SSH Configuration

This repository includes a custom SSH configuration to enhance security and usability. The installer automatically creates a symbolic link `$HOME/.dotfiles/ssh/config` -> `$HOME/.ssh/config`:

The configuration is modular:

- **`config`**: The main SSH config file containing global settings.
- **`local.sshconfig`**: An untracked file (`$HOME/.ssh/local.sshconfig`) that is included by the main config. Use this file for your host-specific settings.

**Why use a local SSH config?**

- **No merge conflicts:** Keep your personal settings safe when pulling updates from this repository to your forked one.
- **Privacy:** Keep sensitive host information out of your public repository.

The default configuration enables connection multiplexing (`ControlMaster`), which significantly speeds up subsequent connections to the same host by reusing the initial TCP connection.

#### Default SSH Configuration

```ssh
Host *                                          #Applies these settings to all SSH connections.
    IgnoreUnknown UseKeychain                   #Ignores unknown options except `UseKeychain` (for compatibility).
    AddKeysToAgent yes                          #Automatically adds private keys to the ssh-agent for easier authentication.
    UseKeychain yes                             #On macOS, stores and loads SSH passphrases from the system keychain.
    IdentityFile ~/.ssh/id_rsa                  #Default private key used for authentication.
    Compression yes                             #Enables compression to speed up data transfer.
    ServerAliveInterval 60                      #Sends a keepalive message every 60 seconds to keep the connection active.
    ServerAliveCountMax 5                       #Disconnects after 5 missed keepalive responses.
    TCPKeepAlive yes                            #Ensures TCP-level keepalive packets are sent.
    ControlMaster auto                          #Enables SSH connection multiplexing, allowing multiple sessions over a single connection.
    ControlPath ~/.ssh/control-%r@%h:%p         #Path for the control socket used by multiplexing.
    ControlPersist 10m                          #Keeps the master connection open for 10 minutes after the last session closes.
    Include ~/.ssh/local.sshconfig              #Allows you to modularize your configuration by including additional settings from another file without changing this one.
```

---

## 10. 🐙 Git Configuration

#### Local Configuration and Multiple Profiles

This setup includes a default `.main.gitconfig`. To extend it without creating merge conflicts when pulling updates from this repository to your forked one, create your own local configuration at `$HOME/.config/git/local.gitconfig`.

**Why use a local Git config?**

- **No merge conflicts:** Keep your personal settings safe when pulling updates from this repository to your forked one.
- **Privacy:** Keep your name and email out of your public dotfiles.
- **Multiple accounts:** Easily manage different Git identities (e.g., work vs. personal) using conditional includes based on the project directory.

This links the git config files from this repo into `$HOME/.config/git`. You can then create `$HOME/.config/git/local.gitconfig` to define your user details and include other files conditionally, as shown in the original prompt's examples.

**Example `local.gitconfig`:**

```ini
[user]
    name = myname
    email = mayname@email.xxx

[includeIf "gitdir:~/Developer/personal@github/"]
    path = ./gitconfig.personal@github
[includeIf "gitdir:~/Developer/work@github/"]
    path = ./gitconfig.work@github
```

**Example of an included config (e.g., `gitconfig.work@github`):**

```ini
[user]
    name = myworkname
    email = myworkname@email.xxx
```

With this setup, Git will automatically use the correct user and email for each project, based on its directory. This is especially useful if you contribute to both personal and work repositories from the same machine.

> **Note:**  
> I use the `$HOME/Developer` folder as my main projects directory because on macOS this folder has a custom "fancy" icon, making it easily recognizable in Finder. 
> On Ubuntu, the default folder is `$HOME/Develop`, but I usually rename it to `$HOME/Developer` to keep the same configuration and directory structure across both operating systems.

---

For a minimal disposable Ubuntu 26.04 shell intended only for manual installer
testing, build [`Dockerfile.test`](Dockerfile.test) and open its default Zsh
session:

```sh
docker build -f Dockerfile.test -t dotfiles-next-test-shell .
docker run --rm -it \
  -v "$PWD:/home/demo/.dotfiles" \
  dotfiles-next-test-shell
```

The container runs as the passwordless-sudo `demo` user. It includes only Zsh,
sudo, curl, and HTTPS certificates, leaving Git and the dotfiles packages for
the installer under test. The current host directory is mounted at
`/workspace`, and `/home/demo/.dotfiles` is a symbolic link to that mount. The
bind mount is required: without it, the image contains no dotfiles repository
to test.

---

## 📜 License

Released under the [MIT License](LICENSE).
