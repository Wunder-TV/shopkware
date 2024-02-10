#!/bin/bash
set -e

SSH_CONNECT="$SSH_USER@$SSH_HOST"

# TODO -  insert Github Variables:
# as scret: SSH_PRIVATE_KEY like "-----BEGIN OPENSSH PRIVATE KEY----- ..."
# SSH_USER like "deployer"
# SSH_HOST like "hostname"
# PATH_BASE_FOLDER like "/opt/klubshop_container/klubshop"
# COMMON VARS
DOCKER_COMPOSE_SERVICE="app"
PATH_LOCAL_FOLDER="shopware"
HOSTING_DIR="hosting/shopware"
CI_APP_ENV="production"
OCY_APP_FRAMEWORK="shopware"
OCY_CADDYFILE_OVERWRITE="/etc/caddy/CaddyfileKlubshop"

GIT_CLONE_URL="git@github.com:$GITHUB_REPOSITORY.git"

. ./common.sh

[[ -z "$SSH_PRIVATE_KEY" ]] && echo "Variable SSH_PRIVATE_KEY is empty. Check CI Variable Settings and check if branch or tag is protected!" && exit 1
[[ -f /.dockerenv ]] && mkdir -p ~/.ssh/ && touch ~/.ssh/known_hosts
mkdir -p ~/.ssh/sockets
ssh-keyscan $SSH_HOST >> ~/.ssh/known_hosts
ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts
eval $(ssh-agent -s)
[[ -f /.dockerenv ]] && echo -e "Host *\n\tStrictHostKeyChecking no" > ~/.ssh/config
[[ -f /.dockerenv ]] && echo -e "\tControlMaster auto\n\tControlPath ~/.ssh/sockets/%r@%h-%p\n\tControlPersist 10\n" >> ~/.ssh/config
echo "$SSH_PRIVATE_KEY" | tr -d "\r" | ssh-add -

[[ "$PATH_BASE_FOLDER" == "" ]] && echo "Environment Variable PATH_BASE_FOLDER is not set." && exit 1 || true
echo PATH_BASE_FOLDER: $PATH_BASE_FOLDER

ssh_exec "[[ ! -d '${PATH_BASE_FOLDER}/.git/' ]] && git clone '${GIT_CLONE_URL}' '${PATH_BASE_FOLDER}' || true"
ssh_exec "cd '${PATH_BASE_FOLDER}' && git fetch --prune --all"
ssh_exec "cd '${PATH_BASE_FOLDER}' && git reset --hard ${GITHUB_SHA}"

[[ "$BUILD_TAG" == "" ]] && BUILD_TAG=${GITHUB_SHA} || true
echo BUILD_TAG=$BUILD_TAG
[[ "$HOSTING_DIR" == "" ]] && echo "Environment Variable HOSTING_DIR is not set. Example value: hosting/middleware" && exit 1 || true
echo HOSTING_DIR: $HOSTING_DIR"
[[ "$DOCKER_COMPOSE_SERVICE" == "" ]] && echo "Environment Variable DOCKER_COMPOSE_SERVICE is not set." && exit 1 || true
echo DOCKER_COMPOSE_SERVICE: $DOCKER_COMPOSE_SERVICE"
[[ "$PATH_BASE_FOLDER" == "" ]] && echo "Environment Variable PATH_BASE_FOLDER is not set." && exit 1 || true
echo PATH_BASE_FOLDER: $PATH_BASE_FOLDER"
[[ "$PATH_LOCAL_FOLDER" == "" ]] && echo "Environment Variable PATH_LOCAL_FOLDER is not set." && exit 1 || true
echo PATH_LOCAL_FOLDER: $PATH_LOCAL_FOLDER"
scp_exec ./asset/docker-hosting-builder.sh "${SSH_CONNECT}:${PATH_BASE_FOLDER}/${HOSTING_DIR}/"
ssh_exec "cd '${PATH_BASE_FOLDER}/${HOSTING_DIR}/' && chmod +x docker-hosting-builder.sh"
ssh_exec "cd '${PATH_BASE_FOLDER}/${HOSTING_DIR}/' && ./docker-hosting-builder.sh ${BUILD_TAG} ${DOCKER_COMPOSE_SERVICE} ${PATH_LOCAL_FOLDER} ${PATH_BASE_FOLDER} '${DOMAINS}' '${CI_APP_ENV}' '${OCY_APP_FRAMEWORK}' '${OCY_CADDYFILE_OVERWRITE}'"
ssh_exec "cd '${PATH_BASE_FOLDER}/${HOSTING_DIR}/' && docker compose up -d"
