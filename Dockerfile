FROM ubuntu:26.04

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

# The build context is the local dotfiles repository.
COPY --chown=demo:demo . /home/demo/.dotfiles

# Use the default answers in the template for the non-interactive Docker setup.
# Zsh reads this link from $HOME before ZDOTDIR is configured.
RUN cp /home/demo/.dotfiles/zsh/.zshenv.init /home/demo/.dotfiles/zsh/.zshenv \
    && ln -s .dotfiles/zsh/.zshenv /home/demo/.zshenv

RUN mkdir -p \
      /home/demo/.config \
      /home/demo/.fonts \
      /home/demo/.local/bin \
      /home/demo/.ssh \
    && chmod 700 /home/demo/.ssh \
    && cp /home/demo/.dotfiles/fonts/* /home/demo/.fonts/ \
    && fc-cache -f \
    && ln -sfn /home/demo/.dotfiles/ssh/config /home/demo/.ssh/config \
    && ln -sfn /home/demo/.dotfiles/git /home/demo/.config/git \
    && ln -sfn /home/demo/.dotfiles/tmux /home/demo/.config/tmux \
    && ln -sfn /home/demo/.dotfiles/ripgrep /home/demo/.config/ripgrep \
    && cp /home/demo/.dotfiles/git/examples/local.gitconfig.example /home/demo/.config/git/local.gitconfig \
    && cp /home/demo/.dotfiles/git/examples/gitconfig.personal@github.example /home/demo/.config/git/gitconfig.personal@github \
    && cp /home/demo/.dotfiles/git/examples/gitconfig.work@github.example /home/demo/.config/git/gitconfig.work@github \
    && ln -s /usr/bin/batcat /home/demo/.local/bin/bat \
    && ln -s /usr/bin/fdfind /home/demo/.local/bin/fd \
    && ln -sfn /home/demo/.dotfiles/micro /home/demo/.config/micro \
    && architecture="$(dpkg --print-architecture)" \
    && download_url="$(curl -fsSL https://api.github.com/repos/sinelaw/fresh/releases/latest \
      | grep 'browser_download_url' \
      | grep "_${architecture}\\.deb" \
      | head -n 1 \
      | cut -d '"' -f 4)" \
    && test -n "$download_url" \
    && curl -fsSL "$download_url" -o /tmp/fresh-editor.deb \
    && sudo apt-get update \
    && sudo apt-get install -y /tmp/fresh-editor.deb \
    && sudo rm -rf /tmp/fresh-editor.deb /var/lib/apt/lists/* \
    && ln -sfn /home/demo/.dotfiles/fresh /home/demo/.config/fresh \
    && curl -fsSL https://mise.run | sh \
    && ln -sfn /home/demo/.dotfiles/mise /home/demo/.config/mise \
    && ln -sfn /home/demo/.dotfiles/fastfetch /home/demo/.config/fastfetch \
    && curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d /home/demo/.local/bin \
    && ln -sfn /home/demo/.dotfiles/oh-my-posh /home/demo/.config/oh-my-posh

# Use Zsh for the remaining build-time demo setup. The user's login shell is
# already /bin/zsh; interactive startup is deferred until docker run -it.
SHELL ["/bin/zsh", "-c"]

RUN mkdir -p /home/demo/Developer/personal@github && \
  mkdir -p /home/demo/Developer/work@github && \
  cd /home/demo/Developer && \
  git clone https://github.com/jenkins-docs/simple-java-maven-app.git work@github/simple-java-maven-app && \
  git clone https://github.com/johnpapa/node-hello.git personal@github/simple-node-hello && \
  git clone https://github.com/dbarnett/python-helloworld.git personal@github/python-helloworld && \
  git clone https://github.com/imageio/test_images.git personal@github/test_images && \
  cp /home/demo/.dotfiles/git/examples/gitconfig.personal@github.example /home/demo/.config/git/gitconfig.personal@github && \
  cp /home/demo/.dotfiles/git/examples/gitconfig.work@github.example /home/demo/.config/git/gitconfig.work@github && \
  cp /home/demo/.dotfiles/git/examples/local.gitconfig.example /home/demo/.config/git/local.gitconfig

RUN zsh -i -c 'cd $HOME && \
  mise install java@17.0.2 && mise use -g java@system && \
  mise install python@3.13.6 && mise use -g python@system && \
  mise install node@22.14.0 && mise use -g node@system && \
  cd /home/demo/Developer/personal@github/simple-node-hello && mise use node@22.14.0 && \
  cd /home/demo/Developer/work@github/simple-java-maven-app && mise use java@17.0.2 && \
  cd /home/demo/Developer/personal@github/python-helloworld && mise use python@3.13.6'

CMD ["zsh", "-l"]
