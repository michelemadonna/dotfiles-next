# Docker

## Complete demo

`Dockerfile` defaults to a remote GitHub checkout. Use
`--build-arg DOTFILES_SOURCE=local` to copy the current repository instead.
Remote images run the checkout's interactive installer at container startup;
local images run `install.sh non-interactive` during the build. Do not replace
these paths with hand-written setup logic.

Keep expensive tools, demo repositories, and Mise runtimes before the
source-selection stages so local source edits remain cache-friendly. The image
uses Ubuntu 26.04, an unprivileged passwordless-sudo `demo` user, and installs
Fresh, Micro, Mise, Fastfetch, Oh My Posh, Java, Node.js, Python, and preview
sample repositories. It seeds the base-package marker because the base stage
already installed those packages.

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
