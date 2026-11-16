# Docker

## Complete demo

`./docker-demo.sh` builds and runs the remote demo from `main` by default.
Select another branch with `./docker-demo.sh remote feature-branch`. The
explicit branch overrides `DOTFILES_REF`; the environment variable remains
the fallback before `main`. `DOTFILES_REPO_URL` selects the remote repository,
and `DOCKER_IMAGE` selects the image name.

Use `./docker-demo.sh local` for the current working tree. Local mode does not
accept a branch argument and never changes the host checkout's branch.

`Dockerfile` defaults to a remote GitHub checkout. Use
`--build-arg DOTFILES_SOURCE=local` to copy the current repository instead.
Remote images run the checkout's interactive installer at container startup;
local images run `install.sh non-interactive` during the build. Do not replace
these paths with hand-written setup logic.
Local mode includes `zsh/home/.zshenv` and applies its preferences during the
non-interactive install. The installer reads both literal preferences and
defaults written as `${VARIABLE:=value}`, then uses its normal defaults for
preferences that the file does not set.
Prepared contents of `zsh/vendor/packages/` are excluded from the build
context and fetched from the lockfile inside the Linux image, so host-specific
executables such as macOS fzf binaries are never reused in Docker.

Keep expensive tools, demo repositories, and Mise runtimes before the
source-selection stages so local source edits remain cache-friendly. The image
uses Ubuntu 26.04, an unprivileged passwordless-sudo `demo` user, and installs
Fresh, Micro, Mise, Fastfetch, Oh My Posh, Java, Node.js, Python, 7-Zip, and preview
sample repositories. It seeds the base-package marker because the base stage
already installed those packages. The APT package is `7zip`, and the seeded
marker is `base-packages-v4-linux-apt.done`, matching the host installer's
current base-package version and provider.

The demo clones Java/Maven, Node.js, Python, and image repositories under
`/home/demo/Developer`, then selects Java `17.0.2`, Python `3.13.6`, and Node.js
`22.14.0` through Mise for the matching sample projects. The image links the
Zsh, Git, SSH, tmux, ripgrep, editor, prompt, Fastfetch, and Mise
configurations.

## Minimal installer test image

`Dockerfile.test` contains only the minimal Ubuntu/Zsh test environment. The
repository must be mounted from the host:

```sh
docker build -f Dockerfile.test -t dotfiles-next-test-shell .
docker run --rm -it -v "$PWD:/home/demo/.dotfiles" dotfiles-next-test-shell
```

Inside the container:

```text
/home/demo/.dotfiles -> current folder on host
```

Without the bind mount, the image contains no repository and is not a valid
installer test environment.
