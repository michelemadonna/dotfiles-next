# Standalone migration validation

This report describes the initial standalone extraction, before the subsequent
namespace and startup-file renaming. Its benchmark results are historical and
do not validate later changes; rerun the project benchmark for the current tree.

Validated on 2026-11-13 on Michele's Intel macOS machine, using `/bin/zsh`
5.9, patchlevel `zsh-5.9-0-g73d3173`. Every configuration execution, installer
test and benchmark ran after entering the project through its root `fhome.sh`.
The live configuration and the supplied upstream reference were left
unchanged. This report does not establish Linux/WSL or other-machine runtime
compatibility.

The launcher uses `exec env` so its calling script is replaced by the isolated
shell. This also prevents an older launcher process from resuming at a stale
file offset after the script has been edited during a test session. A fresh
launch, confined output-path checks, shell syntax and clean exit were verified
after this launcher-only fix; it does not change the benchmarked Zsh sources
or environment values.

## Functional verification

- `/bin/zsh -n` on changed Zsh sources and all 76 extracted autoload bodies;
  `/bin/sh -n` on changed shell scripts and the child-Zsh launcher.
- The initialized interactive runtime passed checks for the complete retained
  option set, history settings, event handlers, isolated paths, matching child
  Zsh executable, completion registration and lazy loaders.
- Compiled loading retained the original source filename, invalidated modified
  input and fell back to readable source when compilation was unavailable.
- Installer platform tests and package-manager tests passed. Legacy preference
  migration preserved custom values and was idempotent; automatic tool
  installation was not invoked.
- A fresh highlighting cache used the bundled secondary theme, with blocked
  curl/wget functions recording no attempted startup download.
- Terminal packet tests verified boundary order, metadata invalidation, OSC7
  caching and title refresh after activity. Runtime widget audit found no
  missing handlers or accidental `.zwc` autoload names.
- In a writable PTY, Ctrl-T, Ctrl-R, Alt-C and directory-history pickers opened;
  preview and hidden-file toggles worked, and cancellation restored the prompt.
  Tab completed a file; Shift-Tab generated and displayed completion options.
  Clear-screen bindings preserved the prompt. Ghost text stayed visible while
  typing `.`, `./` and the prefix of `./start_benchmark.sh`.
- The default startup profile, optional Oh My Posh prompt and native
  completion/highlighting fallback were also checked; the measurements below
  use the saved `fast` profile with Powerlevel10k and fzf-tab.

These terminal checks complement the automated tests; static parsing alone
does not establish ZLE behavior. The tests do not claim to exercise every
external tool integration or remote SSH host.

## Benchmark method and acceptance

Only the root `./start_benchmark.sh` was used, with the original target and
benchmark implementation unchanged. Runs used the same machine, Zsh version,
fake HOME and saved preferences. Normal measurements used prepared dependencies
and warm startup/completion caches. Implementation changes between development
runs are recorded in the history below; they are not interchangeable samples
of the final implementation.

The filesystem sandbox initially prevented the benchmark's `/dev/fd` access.
The complete measurements used an authorized writable PTY outside that
sandbox, retaining the launcher's confined HOME, XDG, temporary and SSH-agent
paths. No real-home benchmark was run.

Every complete run retained `creates_tty=0`, `has_compsys=1`,
`has_syntax_highlighting=1`, `has_autosuggestions=1`, and `has_git_prompt=1`.
The strict comparator has no tolerance and fails on any metric above the target.
Results above a threshold remain failures even when the difference is small.
No slower run is discarded and no passing sample is presented as proof of
stable performance parity.

The [benchmark record](benchmarks/standalone/README.md) contains the immutable
target snapshot, every complete development measurement and the final repeated
measurements. The fake-home root `current-zsh.benc` contains the latest run.

## Final measured result

The latest run passes the strict gate.

| Metric | Target ms | Latest ms | Delta ms |
| --- | ---: | ---: | ---: |
| `first_prompt_lag_ms` | 53.909 | 43.426 | -10.483 |
| `first_command_lag_ms` | 197.508 | 173.246 | -24.262 |
| `command_lag_ms` | 8.951 | 8.776 | -0.175 |
| `input_lag_ms` | 7.970 | 7.778 | -0.192 |
| `exit_time_ms` | 68.382 | 63.078 | -5.304 |

All capability flags match the baseline. Earlier repetitions also exceeded the input threshold, including very small differences; those failures are preserved in the record. Stable strict performance parity cannot be claimed from these results. No feature was disabled to obtain a faster measurement.
