# Testing

## Required checks

For every change run:

```sh
git diff --check
git status --short
```

For installer changes run `sh -n install.sh` and ShellCheck when available.
Use a disposable HOME and stubbed package managers for installer branches;
never change the host unintentionally.
Cover Intel MacPorts, Intel Homebrew, Apple Silicon Homebrew, and Linux APT.
Assert that the Intel provider override and persisted preference are honored,
and that root
invocation is rejected and that every stubbed `sudo` call is immediately
preceded by its privilege reason. Do not download or install MacPorts during
host-side tests; perform the real package, idempotency, provider, and PTY tests
in a disposable Intel VM.

For modified Zsh files run `/bin/zsh -n` on every file. Static startup checks
do not prove ZLE, fzf-tab, prompt, Fastfetch, or terminal behavior.

For package loader or dependency preparation changes run
`python3 tests/test-shell-packages.py`. It uses disposable HOME directories
and local Git repositories to exercise pinned/latest downloads, lockfile
recording, compilation, offline reuse, nested plugins, failures, concurrent
loaders, and full installer preparation. Run `tests/test-dependency-patch.sh`
with a disposable fake HOME to verify Powerlevel10k patch migration.

For archive preview changes run `python3 tests/test-archive-preview.py` with
`7zz` or `7z` installed. It creates disposable ZIP, 7z, RAR, TAR, compressed
TAR, and single compressed-file fixtures. It covers executable selection,
paths with spaces, renamed archives, encrypted headers, corrupt input,
missing tools, and the 300-line output limit. The installer tests assert the
APT, Homebrew, and MacPorts packages plus marker migration and idempotency.
Also inspect an archive through the actual fzf preview in a writable PTY.

For filesystem icon changes run `python3 tests/test-fzf-icons.py` with the
pinned fzf prepared and eza installed. It verifies eza glyphs, one batched
lookup, exact selected paths with spaces and metacharacters, icon-free search,
hidden-file reload lists, fallback behavior, and fzf-tab group/metadata
preservation. In a writable PTY inspect the actual icons in `Ctrl-T`, `Alt-C`,
and filesystem Tab completion; verify previews, multiple selection,
cancellation, and `Ctrl-H`/`Ctrl-P`. Exercise both fzf-tab generators when a
compiled native module is available.

## Interactive validation

Use a real writable PTY, preferably the Docker demo for Docker-specific work.
Run the standalone runtime check in fresh isolated shells with
`DOTSH_USE_FZF=true` and `DOTSH_USE_FZF=false`. With `false`, exercise the native
Tab/history/editing keys and generated `Shift-Tab` completion while an fzf
binary is available. Assert that fuzzy widgets, styles, Git hooks, previews,
and the fuzzy keybinding reference are absent. Verify that Mise version
completion uses native candidates in this mode.
For temporary macOS tests use:

```text
/Users/michele/Developer/michelemadonna@github/dotfiles-no-zhu/fhome.sh
```

Do not create a repository-local replacement. For fzf bindings capture and
compare the effective values:

```zsh
bindkey '^T'
bindkey '^[c'
print -r -- "$FZF_CTRL_T_OPTS"
print -r -- "$FZF_ALT_C_OPTS"
```

Exercise the actual key sequence for `Ctrl-T`, `Alt-C`, fzf-tab, preview, and
hidden-file toggles. A non-empty option value or non-interactive `zsh -lic`
test is insufficient evidence.

For fzf-git changes, use a disposable repository containing local and remote
branches, tags, commits, modified/untracked paths, stashes, reflogs, and a
linked worktree. In a writable PTY verify every `Ctrl-G` picker, all internal
upstream bindings, Git-aware TAB contexts, cancellation, partial prefixes, and
quoting of paths with spaces or metacharacters. Cover every direct `Alt-B`,
`Alt-T`, `Alt-H`, `Alt-E`, `Alt-F`, and `Alt-W` transition plus at least one
multi-hop chain such as Each-ref → Files → Branches → Hashes. Verify that
Hashes → Files selects files from the chosen commits and that `Alt-W` selects
working-tree files. Execute the generated Git commands; inspecting the buffer
alone is insufficient. Run at least one picker without `DOTSH_FZF_GIT_FILTER`:
filtered mode does not exercise fzf terminal ownership and cannot detect a
stopped background picker. Confirm that `Ctrl-P` updates the shared preview
state and geometry and that the persisted `Ctrl-F` height is applied to both
normal and tmux picker launches. Test `Alt-V` with the configured terminal
editor for both Files and Each-ref; the latter must receive a readable regular
temporary file that is removed after the editor exits. Cycle preview through
right, down, down90, hidden, and right again, verifying that delta
side-by-side is used only for the two lower layouts.

For contextual branch and worktree completion, verify `branch -d/-D`,
`branch --set-upstream-to`, `branch --edit-description`, branch start-points,
`worktree add <path>`, `worktree add -b/-B <name> <path>`, and
`worktree remove/lock/unlock/move`. Plain `branch`/`worktree`, branch rename or
copy destinations, orphan worktree creation, and completed operands must fall
back without modifying the buffer.

## Docker and documentation

Run `docker build --check .` and the affected remote or local build, followed
by a container smoke test. For `Dockerfile.test`, mount `$PWD` at `/workspace`
and verify `/home/demo/.dotfiles` resolves to `/workspace`.

Check README code fences, commands, local links, and consistency with current
source behavior. If a required check cannot run, report it explicitly.
