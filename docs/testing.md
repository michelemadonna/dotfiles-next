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

## Docker and documentation

Run `docker build --check .` and the affected remote or local build, followed
by a container smoke test. For `Dockerfile.test`, mount `$PWD` at `/workspace`
and verify `/home/demo/.dotfiles` resolves to `/workspace`.

Check README code fences, commands, local links, and consistency with current
source behavior. If a required check cannot run, report it explicitly.
