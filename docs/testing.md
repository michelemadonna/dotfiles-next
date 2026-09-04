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
Cover Intel MacPorts, Apple Silicon Homebrew, and Linux APT. Assert that root
invocation is rejected and that every stubbed `sudo` call is immediately
preceded by its privilege reason. Do not download or install MacPorts during
host-side tests; perform the real package, idempotency, provider, and PTY tests
in a disposable Intel VM.

For modified Zsh files run `/bin/zsh -n` on every file. Static startup checks
do not prove ZLE, fzf-tab, prompt, Fastfetch, or terminal behavior.

## Interactive validation

Use a real writable PTY, preferably the Docker demo for Docker-specific work.
For temporary macOS tests use:

```text
/Users/michele/Developer/z4u-next/fhome.sh
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
alone is insufficient. Run at least one picker without `Z4H_FZF_GIT_FILTER`:
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
