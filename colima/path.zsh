if [[ -S "$HOME/.colima/default/docker.sock" ]]; then
  export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
elif (( $+commands[docker] )); then
  export DOCKER_HOST="$(docker context inspect -f '{{ .Endpoints.docker.Host }}' 2>/dev/null)"
fi
