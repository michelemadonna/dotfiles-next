# Repository instructions

`dotfiles-next` is a Zsh for Humans environment for macOS and Ubuntu 26.04,
with an interactive/non-interactive installer, custom Zsh plugins,
Powerlevel10k as the default prompt, optional Oh My Posh, and Docker demos.

Read `README.md` and the relevant document in `docs/` before changing
behavior. Treat repository sources as authoritative. Update `README.md` when
commands, options, defaults, supported platforms, installation behavior,
Docker usage, or user-facing UX changes.

## Non-negotiable contracts

- Preserve Powerlevel10k as the default; Oh My Posh is optional.
- Preserve installer modes, prompts, environment contracts, idempotency, and
  non-interactive no-prompt behavior.
- Preserve Docker remote/local source behavior and cache boundaries.
- z4h supplies fzf and native `Ctrl-T`, `Ctrl-R`, and `Alt-C`; do not restore
  `unixorn/fzf-zsh-plugin`.
- fzf-tab, `Ctrl-T`, and `Alt-C` share preview/hidden-file state. `Ctrl-P`
  cycles preview layout and `Ctrl-H` toggles hidden files.
- Completion generation is explicitly triggered with `Shift-Tab`.
- Edit persistent repository sources, never generated files or cache artifacts.
- Keep changes minimal and validate every change.
- Keep changes local by default. Ask for explicit confirmation before every
  commit, push, or pull-request operation (create, update, merge, or close);
  approval for an earlier publication does not apply to later changes.

## Technical references

- [Architecture](docs/architecture.md): component ownership and startup flow.
- [Installer](docs/installer.md): modes, tools, state, links, and contracts.
- [Docker](docs/docker.md): demo images, source modes, and test container.
- [Testing](docs/testing.md): static checks, PTY requirements, and validation.
