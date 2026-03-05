# export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"
export DOCKER_HOST=$(docker context inspect -f '{{ .Endpoints.docker.Host }}')
