#!/bin/sh

set -eu

usage() {
  printf 'Usage: %s [remote|local]\n' "$0" >&2
}

source_mode=${1:-remote}
image_name=${DOCKER_IMAGE:-dotfiles-next-demo}

case $source_mode in
  remote)
    docker build -t "$image_name" .
    ;;
  local)
    docker build \
      --build-arg DOTFILES_SOURCE=local \
      -t "$image_name" .
    ;;
  *)
    usage
    exit 2
    ;;
esac

exec docker run --rm -it "$image_name"
