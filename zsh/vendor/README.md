# Vendored shell integrations

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
