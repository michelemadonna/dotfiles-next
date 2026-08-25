ARG DOTFILES_SOURCE=remote

FROM ubuntu:26.04 AS base

ARG DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      bat \
      ca-certificates \
      chafa \
      command-not-found \
      curl \
      dnsutils \
      eza \
      fd-find \
      file \
      fontconfig \
      fastfetch \
      git \
      git-delta \
      grc \
      htop \
      mediainfo \
      micro \
      openssh-client \
      poppler-utils \
      python3-pip \
      ripgrep \
      stow \
      sudo \
      tmux \
      tree \
      unzip \
      wget \
      zsh \
      default-jdk-headless nodejs python3 \
    && rm -rf /var/lib/apt/lists/*

# Install the standalone editor before copying the dotfiles so this download
# remains cached when only a repository file changes.
RUN architecture="$(dpkg --print-architecture)" \
    && download_url="$(curl -fsSL https://api.github.com/repos/sinelaw/fresh/releases/latest \
      | grep 'browser_download_url' \
      | grep "_${architecture}\\.deb" \
      | head -n 1 \
      | cut -d '"' -f 4)" \
    && test -n "$download_url" \
    && curl -fsSL "$download_url" -o /tmp/fresh-editor.deb \
    && apt-get update \
    && apt-get install -y /tmp/fresh-editor.deb \
    && rm -rf /tmp/fresh-editor.deb /var/lib/apt/lists/*

# Create a non-root user whose configured login shell is Zsh.
RUN useradd --create-home --shell /bin/zsh demo \
    && printf 'demo ALL=(ALL) NOPASSWD:ALL\n' >/etc/sudoers.d/demo \
    && chmod 0440 /etc/sudoers.d/demo

ENV HOME=/home/demo \
    SHELL=/bin/zsh \
    TERM=xterm-256color \
    USER=demo \
    PATH="/home/demo/.local/bin:${PATH}"

USER demo
WORKDIR /home/demo

# Install optional demo tools before copying the repository. These layers are
# independent from local configuration changes and can be reused by BuildKit.
RUN mkdir -p /home/demo/.local/bin \
    && ln -s /usr/bin/batcat /home/demo/.local/bin/bat \
    && ln -s /usr/bin/fdfind /home/demo/.local/bin/fd \
    && curl -fsSL https://mise.run | sh \
    && curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d /home/demo/.local/bin

RUN mkdir -p /home/demo/Developer/personal@github \
      /home/demo/Developer/work@github \
    && cd /home/demo/Developer \
    && git clone https://github.com/jenkins-docs/simple-java-maven-app.git work@github/simple-java-maven-app \
    && git clone https://github.com/johnpapa/node-hello.git personal@github/simple-node-hello \
    && git clone https://github.com/dbarnett/python-helloworld.git personal@github/python-helloworld \
    && git clone https://github.com/imageio/test_images.git personal@github/test_images

# Download the demo runtimes in a cacheable layer. Their global and per-project
# selections are applied after the configuration has been copied.
RUN mise install java@17.0.2 python@3.13.6 node@22.14.0

# The default source is the Git repository. Override DOTFILES_REPO_URL or
# DOTFILES_REF to test another remote checkout without changing this file.
FROM base AS dotfiles-remote

ARG DOTFILES_REPO_URL=https://github.com/michelemadonna/dotfiles-next.git
ARG DOTFILES_REF=main

RUN git clone --depth 1 --branch "$DOTFILES_REF" \
      "$DOTFILES_REPO_URL" /home/demo/.dotfiles

# Local development is opt-in with --build-arg DOTFILES_SOURCE=local.
FROM base AS dotfiles-local

COPY --chown=demo:demo . /home/demo/.dotfiles

# install.sh accepts an existing checkout only when it contains Git metadata.
RUN git -C /home/demo/.dotfiles init -q

# Select either dotfiles-remote (default) or dotfiles-local while sharing the
# complete configuration sequence below.
FROM dotfiles-${DOTFILES_SOURCE} AS final

# System packages are already installed in the cacheable base stage. Seed the
# installer's versioned marker, then let the repository configure its own
# non-interactive links and defaults.
RUN mkdir -p /home/demo/.local/state/dotfiles-next \
    && touch /home/demo/.local/state/dotfiles-next/base-packages-v1-linux.done \
    && cd /home/demo/.dotfiles \
    && EDITOR=micro \
      Z4H_PROMPT=powerlevel10k \
      Z4H_SHOW_FASTFETCH=false \
      sh ./install.sh non-interactive

RUN mkdir -p \
      /home/demo/.config \
      /home/demo/.fonts \
      /home/demo/.local/bin \
      /home/demo/.ssh \
    && chmod 700 /home/demo/.ssh \
    && cp /home/demo/.dotfiles/fonts/* /home/demo/.fonts/ \
    && fc-cache -f \
    && ln -sfn /home/demo/.dotfiles/ssh/config /home/demo/.ssh/config \
    && ln -sfnT /home/demo/.dotfiles/git /home/demo/.config/git \
    && ln -sfnT /home/demo/.dotfiles/tmux /home/demo/.config/tmux \
    && ln -sfnT /home/demo/.dotfiles/ripgrep /home/demo/.config/ripgrep \
    && cp /home/demo/.dotfiles/git/examples/local.gitconfig.example /home/demo/.config/git/local.gitconfig \
    && cp /home/demo/.dotfiles/git/examples/gitconfig.personal@github.example /home/demo/.config/git/gitconfig.personal@github \
    && cp /home/demo/.dotfiles/git/examples/gitconfig.work@github.example /home/demo/.config/git/gitconfig.work@github \
    && ln -sfnT /home/demo/.dotfiles/micro /home/demo/.config/micro \
    && ln -sfnT /home/demo/.dotfiles/fresh /home/demo/.config/fresh \
    && ln -sfnT /home/demo/.dotfiles/mise /home/demo/.config/mise \
    && ln -sfnT /home/demo/.dotfiles/fastfetch /home/demo/.config/fastfetch \
    && ln -sfnT /home/demo/.dotfiles/oh-my-posh /home/demo/.config/oh-my-posh

RUN cd /home/demo \
    && mise use -g java@system \
    && mise use -g python@system \
    && mise use -g node@system \
    && cd /home/demo/Developer/personal@github/simple-node-hello \
    && mise use node@22.14.0 \
    && cd /home/demo/Developer/work@github/simple-java-maven-app \
    && mise use java@17.0.2 \
    && cd /home/demo/Developer/personal@github/python-helloworld \
    && mise use python@3.13.6

CMD ["zsh", "-l"]
