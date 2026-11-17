#!/usr/bin/env zsh
# Docker and kubectl aliases with completion generation only when the CLI changes.

typeset -g ZQS_CLI_COMPLETION_DIR="${GENCOMPL_FPATH:-$ZSH_CACHE_DIR/completions}"
fpath=("$ZQS_CLI_COMPLETION_DIR" $fpath)
typeset -gU fpath

_zqs_write_cli_completion() {
  emulate -L zsh
  local tool=$1 cache_file=$2 fallback_file=${3:-}
  local tmp_file="${cache_file}.${$}.tmp"

  if command "$tool" completion zsh >| "$tmp_file" 2>/dev/null; then
    command mv -f "$tmp_file" "$cache_file"
    return 0
  fi

  command rm -f "$tmp_file"
  if [[ -n $fallback_file && -r $fallback_file ]]; then
    command cp "$fallback_file" "$cache_file"
    return $?
  fi
  return 1
}

_zqs_cache_cli_completion() {
  emulate -L zsh
  local tool=$1 cache_file=$2 fallback_file=${3:-}
  local binary=${commands[$tool]:-}
  [[ -n $binary ]] || return 1

  [[ -d ${cache_file:h} ]] || command mkdir -p "${cache_file:h}" || return

  if [[ ! -s $cache_file ]]; then
    _zqs_write_cli_completion "$tool" "$cache_file" "$fallback_file"
  elif [[ $binary -nt $cache_file ]]; then
    _zqs_write_cli_completion "$tool" "$cache_file" "$fallback_file" &!
  fi
}

# Docker aliases from Oh My Zsh's docker plugin.
alias dbl='docker build'
alias dcin='docker container inspect'
alias dcls='docker container ls'
alias dclsa='docker container ls -a'
alias dcprune='docker container prune'
alias dib='docker image build'
alias dii='docker image inspect'
alias dils='docker image ls'
alias dipu='docker image push'
alias dipru='docker image prune -a'
alias dirm='docker image rm'
alias dit='docker image tag'
alias dlo='docker container logs'
alias dnc='docker network create'
alias dncn='docker network connect'
alias dndcn='docker network disconnect'
alias dni='docker network inspect'
alias dnls='docker network ls'
alias dnprune='docker network prune'
alias dnrm='docker network rm'
alias dpo='docker container port'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dpu='docker pull'
alias dr='docker container run'
alias drit='docker container run -it'
alias drm='docker container rm'
alias 'drm!'='docker container rm -f'
alias dsprune='docker system prune'
alias dst='docker container start'
alias drs='docker container restart'
alias dsta='docker stop $(docker ps -q)'
alias dstp='docker container stop'
alias dsts='docker stats'
alias dtop='docker top'
alias dvi='docker volume inspect'
alias dvls='docker volume ls'
alias dvprune='docker volume prune'
alias dxc='docker container exec'
alias dxcit='docker container exec -it'

if (( $+commands[docker] )); then
  _zqs_cache_cli_completion docker "$ZQS_CLI_COMPLETION_DIR/_docker" \
    "$ZSH/plugins/docker/completions/_docker"
  autoload -Uz _docker
  autoload +X _docker
  functions[_zqs_docker_completion]=$functions[_docker]
  _docker() {
    local curcontext=$curcontext
    local docker_context=docker

    if [[ ${words[2]:-} == container && -n ${words[3]:-} ]]; then
      docker_context="docker-container-${words[3]}"
    elif [[ -n ${words[2]:-} ]]; then
      docker_context="docker-${words[2]}"
    fi

    curcontext=${curcontext/:docker:/:${docker_context}:}
    _zqs_docker_completion "$@"
  }
  (( $+functions[compdef] )) && compdef _docker docker dockerd
fi

if (( $+commands[kubectl] )); then
  _zqs_cache_cli_completion kubectl "$ZQS_CLI_COMPLETION_DIR/_kubectl"
  autoload -Uz _kubectl
  (( $+functions[compdef] )) && compdef _kubectl kubectl k

  # Kubectl aliases from Oh My Zsh's kubectl plugin.
  alias k=kubectl
  alias kca='_kca(){ kubectl "$@" --all-namespaces; unset -f _kca; }; _kca'
  alias kaf='kubectl apply -f'
  alias kapk='kubectl apply -k'
  alias keti='kubectl exec -t -i'
  alias kcuc='kubectl config use-context'
  alias kcsc='kubectl config set-context'
  alias kcdc='kubectl config delete-context'
  alias kccc='kubectl config current-context'
  alias kcgc='kubectl config get-contexts'
  alias kdel='kubectl delete'
  alias kdelf='kubectl delete -f'
  alias kdelk='kubectl delete -k'
  alias kge='kubectl get events --sort-by=".lastTimestamp"'
  alias kgew='kubectl get events --sort-by=".lastTimestamp" --watch'
  alias kgp='kubectl get pods'
  alias kgpl='kgp -l'
  alias kgpn='kgp -n'
  alias kgpsl='kubectl get pods --show-labels'
  alias kgpa='kubectl get pods --all-namespaces'
  alias kgpw='kgp --watch'
  alias kgpwide='kgp -o wide'
  alias kep='kubectl edit pods'
  alias kdp='kubectl describe pods'
  alias kdelp='kubectl delete pods'
  alias kgpall='kubectl get pods --all-namespaces -o wide'
  alias kgs='kubectl get svc'
  alias kgsa='kubectl get svc --all-namespaces'
  alias kgsw='kgs --watch'
  alias kgswide='kgs -o wide'
  alias kes='kubectl edit svc'
  alias kds='kubectl describe svc'
  alias kdels='kubectl delete svc'
  alias kgi='kubectl get ingress'
  alias kgia='kubectl get ingress --all-namespaces'
  alias kei='kubectl edit ingress'
  alias kdi='kubectl describe ingress'
  alias kdeli='kubectl delete ingress'
  alias kgns='kubectl get namespaces'
  alias kens='kubectl edit namespace'
  alias kdns='kubectl describe namespace'
  alias kdelns='kubectl delete namespace'
  alias kcn='kubectl config set-context --current --namespace'
  alias kgcm='kubectl get configmaps'
  alias kgcma='kubectl get configmaps --all-namespaces'
  alias kecm='kubectl edit configmap'
  alias kdcm='kubectl describe configmap'
  alias kdelcm='kubectl delete configmap'
  alias kgsec='kubectl get secret'
  alias kgseca='kubectl get secret --all-namespaces'
  alias kdsec='kubectl describe secret'
  alias kdelsec='kubectl delete secret'
  alias kgd='kubectl get deployment'
  alias kgda='kubectl get deployment --all-namespaces'
  alias kgdw='kgd --watch'
  alias kgdwide='kgd -o wide'
  alias ked='kubectl edit deployment'
  alias kdd='kubectl describe deployment'
  alias kdeld='kubectl delete deployment'
  alias ksd='kubectl scale deployment'
  alias krsd='kubectl rollout status deployment'
  alias krrd='kubectl rollout restart deployment'

  kres() {
    kubectl set env "$@" REFRESHED_AT=$(date +%Y%m%d%H%M%S)
  }

  alias kgrs='kubectl get replicaset'
  alias kdrs='kubectl describe replicaset'
  alias kers='kubectl edit replicaset'
  alias krh='kubectl rollout history'
  alias kru='kubectl rollout undo'
  alias kgss='kubectl get statefulset'
  alias kgssa='kubectl get statefulset --all-namespaces'
  alias kgssw='kgss --watch'
  alias kgsswide='kgss -o wide'
  alias kess='kubectl edit statefulset'
  alias kdss='kubectl describe statefulset'
  alias kdelss='kubectl delete statefulset'
  alias ksss='kubectl scale statefulset'
  alias krsss='kubectl rollout status statefulset'
  alias krrss='kubectl rollout restart statefulset'
  alias kpf='kubectl port-forward'
  alias kga='kubectl get all'
  alias kgaa='kubectl get all --all-namespaces'
  alias kl='kubectl logs'
  alias kl1h='kubectl logs --since 1h'
  alias kl1m='kubectl logs --since 1m'
  alias kl1s='kubectl logs --since 1s'
  alias klf='kubectl logs -f'
  alias klf1h='kubectl logs --since 1h -f'
  alias klf1m='kubectl logs --since 1m -f'
  alias klf1s='kubectl logs --since 1s -f'
  alias kcp='kubectl cp'
  alias kgno='kubectl get nodes'
  alias kgnosl='kubectl get nodes --show-labels'
  alias keno='kubectl edit node'
  alias kdno='kubectl describe node'
  alias kdelno='kubectl delete node'
  alias kgpvc='kubectl get pvc'
  alias kgpvca='kubectl get pvc --all-namespaces'
  alias kgpvcw='kgpvc --watch'
  alias kepvc='kubectl edit pvc'
  alias kdpvc='kubectl describe pvc'
  alias kdelpvc='kubectl delete pvc'
  alias kdsa='kubectl describe sa'
  alias kdelsa='kubectl delete sa'
  alias kgds='kubectl get daemonset'
  alias kgdsa='kubectl get daemonset --all-namespaces'
  alias kgdsw='kgds --watch'
  alias keds='kubectl edit daemonset'
  alias kdds='kubectl describe daemonset'
  alias kdelds='kubectl delete daemonset'
  alias kgcj='kubectl get cronjob'
  alias kecj='kubectl edit cronjob'
  alias kdcj='kubectl describe cronjob'
  alias kdelcj='kubectl delete cronjob'
  alias kgj='kubectl get job'
  alias kej='kubectl edit job'
  alias kdj='kubectl describe job'
  alias kdelj='kubectl delete job'

  _zqs_build_kubectl_out_alias() {
    setopt localoptions norcexpandparam
    eval "function $1 { $2 }"
    eval "function _$1 {
      words=(kubectl \"\${words[@]:1}\")
      _kubectl
    }"
    compdef _$1 $1
  }

  _zqs_build_kubectl_out_alias kj  'kubectl "$@" -o json | jq'
  _zqs_build_kubectl_out_alias kjx 'kubectl "$@" -o json | fx'
  _zqs_build_kubectl_out_alias ky  'kubectl "$@" -o yaml | yh'
  unfunction _zqs_build_kubectl_out_alias
fi

unfunction _zqs_cache_cli_completion _zqs_write_cli_completion

zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes
