# Vendored shell integrations

## Standalone runtime dependencies

`packages.lock` pins the independent upstream repositories prepared explicitly
by `../helpers/prepare-shell-dependencies.sh`. The generated `packages/` tree
is ignored; preserve this manifest and the local patches as persistent sources.

`patches/powerlevel10k-dotsh-runtime.patch` preserves Powerlevel10k's direct
ZLE widget dispatch optimization for the extracted `dotsh` namespace, including
the pre-redraw handler. Upstream already applies a similar optimization to its
original framework integration.
The patch adds support for the standalone runtime without loading that framework.
Preparation applies the patch idempotently and fails on incompatible source
changes. The upstream license remains in the prepared dependency.

Preparation records the applied patch so a later explicit preparation can
reverse a known prior version before applying its replacement. The historical
`powerlevel10k-runtime-v1.patch` handles checkouts prepared before patch records
were introduced. Original names in patch context or historical input describe
the source being replaced; they do not create runtime aliases. Prepared
third-party repositories retain their own upstream names and provenance.

`patches/fast-syntax-highlighting-offline.patch` replaces the cold-cache theme
download with the identical bundled theme and uses Zsh's `OSTYPE` for the
platform check. Deleting runtime caches never reintroduces a startup download.

## fzf-git.sh

`fzf-git.sh` is vendored from:

- Repository: <https://github.com/junegunn/fzf-git.sh>
- Commit: `d5b0a5dcd1e073b8bfca45338d5dfad3e5642471`
- License: MIT, included in the source header

The maintained local delta is
[`patches/fzf-git-cross-menu.patch`](patches/fzf-git-cross-menu.patch). It adds
the cross-picker `become` bindings and the minimum capture hooks required by
`zsh/helpers/fzf-git.zsh`; the bridge and typed sidecar protocol remain in the
adapter. Editor execution and layout-aware preview rendering are isolated in
`zsh/helpers/fzf-git-action.zsh`.

To update the vendored revision manually:

1. Replace `fzf-git.sh` with the selected upstream revision and retain the
   provenance and MIT license header.
2. Update the commit above.
3. Run `git apply --check zsh/vendor/patches/fzf-git-cross-menu.patch`, then
   `git apply zsh/vendor/patches/fzf-git-cross-menu.patch`.
4. Resolve upstream drift by updating only the patch, then run the static,
   fixture, and real-PTY checks documented in `docs/testing.md`.

Do not add update or download work to shell startup.
