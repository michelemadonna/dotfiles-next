FROM ubuntu:26.04

ARG DEBIAN_FRONTEND=noninteractive
ARG INSTALL_MICRO=0
ARG INSTALL_FRESH=0
ARG INSTALL_MISE=0
ARG INSTALL_FASTFETCH=0
ARG INSTALL_OH_MY_POSH=0

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
      git \
      git-delta \
      grc \
      htop \
      mediainfo \
      poppler-utils \
      python3-pip \
      ripgrep \
      stow \
      sudo \
      tmux \
      tree \
      wget \
      zsh \
    && if [[ "$INSTALL_MICRO" == 1 ]]; then apt-get install -y --no-install-recommends micro; fi \
    && if [[ "$INSTALL_FASTFETCH" == 1 ]]; then apt-get install -y --no-install-recommends fastfetch; fi \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user whose configured login shell is Zsh.
RUN useradd --create-home --shell /bin/zsh demo \
    && printf 'demo ALL=(ALL) NOPASSWD:ALL\n' >/etc/sudoers.d/demo \
    && chmod 0440 /etc/sudoers.d/demo

ENV HOME=/home/demo \
    USER=demo \
    PATH="/home/demo/.local/bin:${PATH}"

USER demo
WORKDIR /home/demo

# The build context is the local dotfiles repository.
COPY --chown=demo:demo . /home/demo/.dotfiles

RUN mkdir -p \
      /home/demo/.config \
      /home/demo/.fonts \
      /home/demo/.local/bin \
      /home/demo/.ssh \
    && chmod 700 /home/demo/.ssh \
    && cp /home/demo/.dotfiles/fonts/* /home/demo/.fonts/ \
    && fc-cache -f \
    && ln -sfn /home/demo/.dotfiles/zsh/.zshenv /home/demo/.zshenv \
    && ln -sfn /home/demo/.dotfiles/ssh/config /home/demo/.ssh/config \
    && ln -sfn /home/demo/.dotfiles/tmux /home/demo/.config/tmux \
    && ln -sfn /home/demo/.dotfiles/ripgrep /home/demo/.config/ripgrep \
    && ln -s /usr/bin/batcat /home/demo/.local/bin/bat \
    && ln -s /usr/bin/fdfind /home/demo/.local/bin/fd \
    && if [[ "$INSTALL_MICRO" == 1 ]]; then ln -sfn /home/demo/.dotfiles/micro /home/demo/.config/micro; fi \
    && if [[ "$INSTALL_FRESH" == 1 ]]; then \
      architecture="$(dpkg --print-architecture)"; \
      download_url="$(curl -fsSL https://api.github.com/repos/sinelaw/fresh/releases/latest \
        | grep 'browser_download_url' \
        | grep "_${architecture}\\.deb" \
        | head -n 1 \
        | cut -d '"' -f 4)"; \
      test -n "$download_url"; \
      curl -fsSL "$download_url" -o /tmp/fresh-editor.deb; \
      sudo apt-get update; \
      sudo apt-get install -y /tmp/fresh-editor.deb; \
      sudo rm -rf /tmp/fresh-editor.deb /var/lib/apt/lists/*; \
      ln -sfn /home/demo/.dotfiles/fresh /home/demo/.config/fresh; \
    fi \
    && if [[ "$INSTALL_MISE" == 1 ]]; then \
      curl -fsSL https://mise.run | sh; \
      ln -sfn /home/demo/.dotfiles/mise /home/demo/.config/mise; \
    fi \
    && if [[ "$INSTALL_FASTFETCH" == 1 ]]; then ln -sfn /home/demo/.dotfiles/fastfetch /home/demo/.config/fastfetch; fi \
    && if [[ "$INSTALL_OH_MY_POSH" == 1 ]]; then \
      curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d /home/demo/.local/bin; \
      ln -sfn /home/demo/.dotfiles/oh-my-posh /home/demo/.config/oh-my-posh; \
    fi

CMD ["zsh", "-l"]
