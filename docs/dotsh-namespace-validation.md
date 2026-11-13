# DOTSH namespace validation

Validated on 2026-11-13 in the project fake HOME entered through the root
`fhome.sh`, using the same `/bin/zsh` 5.9 as the extraction measurements.
The live configuration and upstream reference checkout were not changed.

## Changes

- Preferences, widget names, helpers, cache labels and Git picker subprocess
  variables now use `DOTSH`/`dotsh`. No legacy runtime aliases are exported.
- `zsh/dotsh-startup.zsh` replaces the earlier startup filename and remains
  the first source in `.zshrc`. Custom plugins use `zsh/dotsh.custom.plugins`
  and `dotsh-*.plugin.zsh` filenames throughout the installer, tests and docs.
- The obsolete framework/local fzf selector was removed. The prepared local
  fzf binary is used directly.
- The installer imports an older preference namespace while preserving
  values and custom settings. It changes assignment/parameter identifiers,
  leaving unrelated quoted text and embedded names intact. Tests cover an
  unrelated later startup-profile variable and a repeat installation.
- Explicit dependency preparation upgrades a known prior Powerlevel10k patch
  even when the older installation has no patch record; a fixture verifies
  that starting state and idempotency.

Prepared third-party repositories retain their upstream text. Patch context
and the historical predecessor patch must describe the source being replaced;
these references do not create a framework dependency. Repository source
filenames and maintained runtime code contain no retired namespace names.

## Keyboard conventions

`keyboard mac` works independently of the host OS. It names forward Delete
as Fn+Delete and adds Apple-style aliases for Backspace. PC keyboards use
different names for those terminal escape sequences. The default is now `mac`
on Darwin and `pc` elsewhere, with `DOTSH_KEYBOARD=mac|pc` as an override.

Tests covered both platform defaults and overrides, rejected an invalid value,
and checked the initialized PC mapping in a writable PTY: Delete and Backspace
remain distinct. Linux defaults were tested with a simulated `OSTYPE`; no
native Linux or Docker runtime test was performed.

The independent `macos-option-as-alt` style keeps its earlier behavior. Set it
to `no` before `dotsh_init` if characters produced by Option should be inserted
literally; `keyboard pc` does not implicitly change it.

## Verification

Passed: changed shell-source syntax, all 76 runtime autoload bodies, ShellCheck
at error severity, initialized standalone runtime, installer platform and
preference migration tests, package-manager tests, terminal packet tests,
cold highlighting without downloads, keyboard selection, dependency patch
upgrade and repeated explicit dependency preparation.

In a writable PTY, Ctrl-T opened the renamed file picker; preview/hidden-file
toggles and cancellation worked. Git Ref → Commit → File → Branch transitions
crossed the renamed subprocess interface and returned a branch. The resulting
`git switch` ran in a disposable repository and selected the expected branch.
Record generation covered files, branches, tags, remotes, commits, stashes,
reflogs, worktrees and refs; a filtered branch selection also passed.

`git diff --check` passed. The baseline was not edited. Benchmarks are recorded
below as separate runs, without a tolerance or omission of slower results.

## Benchmark results (ms)

| Run | First prompt | First command | Command | Input | Exit | Strict gate |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Target | 53.909 | 197.508 | 8.951 | 7.970 | 68.382 | — |
| [a](benchmarks/dotsh-namespace/namespace-a.benc) | 44.993 | 177.146 | **8.997** | **8.154** | 66.812 | FAIL |
| [b](benchmarks/dotsh-namespace/namespace-b.benc) | 45.226 | 178.019 | **9.086** | **8.018** | 66.702 | FAIL |

Both runs retain all baseline flags: completion, highlighting, autosuggestions and Git prompt remain enabled; `creates_tty=0`. Both fail the strict latency gate. The latest command latency is 9.086 ms against 8.951 ms (+0.135 ms); input is 8.018 ms against 7.970 ms (+0.048 ms). These regressions are reported without a tolerance. The namespace changes pass functional verification; strict performance acceptance remains open, as it was in the earlier repeated migration measurements.

Raw results and comparator logs are preserved in [the benchmark directory](benchmarks/dotsh-namespace/). The root `current-zsh.benc` contains run b.
