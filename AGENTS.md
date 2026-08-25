# AGENTS.md

## Project

`dotfiles-next` is a Zsh for Humans based dotfiles environment for macOS and
Ubuntu 26.04. It includes an interactive/non-interactive installer, custom Zsh
plugins, Powerlevel10k as the default prompt, optional Oh My Posh support, and
a complete Docker demo.

Read `README.md`, `install.sh`, and the relevant source files before changing
behavior. Treat the repository contents as the source of truth.

## Non-negotiable rules

1. Minimize tokens in user-facing responses. Report the outcome, relevant
   validation, and material caveats only.
2. Do not modify existing working behavior outside the requested context.
   Make the smallest change that fully satisfies the request; do not perform
   opportunistic refactors, formatting, renames, or cleanup.
3. Verify assumptions before editing. Reproduce or inspect the current
   behavior, validate the solution after editing, and never claim completion
   without evidence appropriate to the change.
4. Preserve unrelated user changes in a dirty worktree. Never revert or
   overwrite them.
5. Update `README.md` whenever commands, options, defaults, supported
   platforms, installation behavior, Docker usage, or interactive UX changes.

## Repository contracts

- Supported/documented host platforms are macOS and Ubuntu 26.04.
- Powerlevel10k is the default prompt. Oh My Posh is optional; never replace
  or modify Powerlevel10k in order to fix it unless explicitly requested.
- `install.sh` supports interactive mode plus `non-interactive` and
  `--non-interactive`. Preserve their prompt, environment, and idempotency
  contracts.
- Non-interactive installation must not prompt or install Mise. Base package
  installation remains guarded by its versioned, platform-specific state
  marker.
- Docker builds clone the GitHub repository by default. The current directory
  is used only with `--build-arg DOTFILES_SOURCE=local`.
- After selecting either source, the Docker build must run the checkout's
  `install.sh non-interactive`; do not replace the installer with hand-written
  setup logic. Seed the base-package marker only because the base stage has
  already installed those packages.
- Keep expensive Docker downloads, demo repositories, and Mise runtimes before
  the dotfiles source-selection stages so local edits do not invalidate them.
- z4h supplies `fzf`; native fzf bindings provide `Ctrl-T`, `Ctrl-R`, and
  `Alt-C`. Do not reintroduce `unixorn/fzf-zsh-plugin`.
- fzf-tab, `Ctrl-T`, and `Alt-C` share preview and hidden-file state. `Ctrl-P`
  cycles preview right/down/hidden and `Ctrl-H` toggles hidden files.
- Completion generation is explicitly triggered with `Shift-Tab`; do not
  describe or implement it as automatic first-Tab generation.
- Edit persistent repository sources, not generated files or cache artifacts.

## Working method

1. Inspect the exact files and current Git diff relevant to the request.
2. Establish the cause or expected behavior before applying a patch.
3. Apply a minimal, localized change.
4. Run the narrow checks first, then the relevant integration test.
5. Reinspect the final diff and confirm that only intended files changed.

Do not use non-interactive shell startup as proof of ZLE, fzf, prompt, or
terminal behavior. Exercise the exact keys in a real PTY, preferably in the
Docker demo when the issue is Docker-specific.

## Validation

Choose checks proportionate to the modified area:

- All changes: `git diff --check` and final `git status --short`/diff review.
- POSIX installer: `sh -n install.sh`; run ShellCheck when available. Test
  installer branches with a disposable HOME and stubbed package managers
  rather than changing the host.
- Zsh sources: `/bin/zsh -n` on every modified Zsh file. For bindings,
  completion, previews, prompts, or widgets, also test in a real PTY.
- Dockerfile: `docker build --check .`, followed by the affected build mode:
  default remote build or `--build-arg DOTFILES_SOURCE=local`. Use a container
  smoke test when runtime behavior changes.
- README: verify code fences, commands, and local links against current source
  behavior.

If a required validation cannot run, state exactly what was skipped and do not
present the unverified behavior as confirmed.
