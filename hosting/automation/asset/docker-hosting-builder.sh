#!/usr/bin/env bash

#
# usage: ./docker-hosting-builder.sh <VERSION> <SERVICE> <APP_PATH>
#

export CLI_WORKDIR=$(cd $(dirname $0) && pwd)

set -e

if [[ "$1" == "" || "$2" == "" || "$3" == "" ]]; then
    echo "Usage: $0 <VERSION> <SERVICE> <APP_PATH>"
    exit 1;
fi

OCY_BUILD_TAG="$1"
DOCKER_COMPOSE_SERVICE="$2"
APPLICATION_PATH="$3"
PATH_BASE_FOLDER="$4"
OCY_DOMAINS="$5"
CI_APP_ENV="$6"
OCY_APP_FRAMEWORK="$7"
OCY_CADDYFILE_OVERWRITE="$8"

export OCY_BUILD_TAG

OCY_BUILD_TAG="$1"
echo "OCY_BUILD_TAG IS SET TO ${OCY_BUILD_TAG}"
DOCKER_COMPOSE_SERVICE="$2"
echo "DOCKER_COMPOSE_SERVICE IS SET TO ${DOCKER_COMPOSE_SERVICE}"
APPLICATION_PATH="$3"
echo "APPLICATION_PATH IS SET TO ${APPLICATION_PATH}"
PATH_BASE_FOLDER="$4"
echo "PATH_BASE_FOLDER IS SET TO ${PATH_BASE_FOLDER}"
DOCKER_COMPOSE_BUILD_ENV="$5"
echo "DOCKER_COMPOSE_BUILD_ENV IS SET TO ${DOCKER_COMPOSE_BUILD_ENV}"


# Persist the OCY_BUILD_TAG env
if [[ -f '.env' ]]; then
    rm .env
fi

echo "# CI BUTLER MANAGED ! -> DO NOT EDIT !" > .env
echo "OCY_BUILD_TAG=${OCY_BUILD_TAG}" >> .env
echo "CI_APP_ENV=${CI_APP_ENV}" >> .env
echo "OCY_DOMAINS=${OCY_DOMAINS}" >> .env
echo "OCY_APP_FRAMEWORK=${OCY_APP_FRAMEWORK}" >> .env
echo "OCY_CADDYFILE_OVERWRITE=${OCY_CADDYFILE_OVERWRITE}" >> .env

buildEnvFile=".env"

BUILD_SCRIPT="${DOCKER_COMPOSE_SERVICE}/build.sh"

printf "\n\n🏗️ BUILD DOCKER BASE IMAGE (PHP, Webserver, Composer etc.)\n"
docker compose --env-file="$buildEnvFile" build --no-cache --pull ${DOCKER_COMPOSE_SERVICE}

DOCKER_IMAGE=$(docker compose config --format json | jq -r ".services.${DOCKER_COMPOSE_SERVICE}.image")
DOCKER_NETWORKS=$(docker compose config --format json | jq -r ". as \$root | \$root.services.${DOCKER_COMPOSE_SERVICE}.networks | keys | map_values( \$root.networks[.].name ) | .[]")


#Todo: Make dynamic (currently its not possible to read the env_path field over docker compose config because of the extension)
DOCKER_SERVICE_ENV_PATH="${DOCKER_COMPOSE_SERVICE}/.env"

RANDOM=$(echo $RANDOM | tr '[0-9]' '[a-z]')
CONTAINER_BUILDER_NAME="builder_${APPLICATION_PATH}_${DOCKER_COMPOSE_SERVICE}_${CI_APP_ENV}_${OCY_BUILD_TAG}_${RANDOM}"
CONTAINER_BUILDER_RUN_ARGS="--env-file .env -e 'OCY_CONTAINER_SLEEP=true'"

if [[ -f "$DOCKER_SERVICE_ENV_PATH" ]]; then
    CONTAINER_BUILDER_RUN_ARGS="$CONTAINER_BUILDER_RUN_ARGS --env-file $DOCKER_SERVICE_ENV_PATH"
fi

if [[ -d "${PATH_BASE_FOLDER}/contract" ]]; then
    CONTAINER_BUILDER_RUN_ARGS="$CONTAINER_BUILDER_RUN_ARGS -v ${PATH_BASE_FOLDER}/contract:/contract"
fi

# Check if a build container is still running and if needed remove it
IS_BUILDER_RUNNING=$(docker ps -a -f name=${CONTAINER_BUILDER_NAME} -q)
if [[ "$IS_BUILDER_RUNNING" != "" ]]; then
    docker kill ${CONTAINER_BUILDER_NAME} || true
    docker rm ${CONTAINER_BUILDER_NAME}
fi

docker run -m "12G" --cpus="3.75" --name "${CONTAINER_BUILDER_NAME}" -d $CONTAINER_BUILDER_RUN_ARGS $DOCKER_IMAGE
for DOCKER_NETWORK in $DOCKER_NETWORKS
do
    docker network connect "$DOCKER_NETWORK" "${CONTAINER_BUILDER_NAME}" || true
done

DOCKER_BUILDER_CONTAINER_WORKDIR=$(docker inspect --format='{{.Config.WorkingDir}}' "${CONTAINER_BUILDER_NAME}")
#DOCKER_BUILDER_CONTAINER_USER=$(docker inspect --format='{{.Config.User}}' "${CONTAINER_BUILDER_NAME}")

# Copy application code in docker container and fix permissions
docker cp "${PATH_BASE_FOLDER}/${APPLICATION_PATH}/." "${CONTAINER_BUILDER_NAME}":$DOCKER_BUILDER_CONTAINER_WORKDIR
docker restart "${CONTAINER_BUILDER_NAME}" # Make sure container is running e.g. if container failed because of missing webroot.
docker exec -u root "${CONTAINER_BUILDER_NAME}" chown -R www-data:www-data $DOCKER_BUILDER_CONTAINER_WORKDIR

# Check if a build script exists and execute it
if [[ -f "${BUILD_SCRIPT}" ]]; then
    docker cp "${BUILD_SCRIPT}" "${CONTAINER_BUILDER_NAME}":/build.sh
    docker exec -u www-data "${CONTAINER_BUILDER_NAME}" bash /build.sh
else
    echo "No build script found! Create file here: '$BUILD_SCRIPT'!"
fi

docker exec -u root "${CONTAINER_BUILDER_NAME}" chown -R www-data:www-data $DOCKER_BUILDER_CONTAINER_WORKDIR
# Stop container and tag the changes
docker stop "${CONTAINER_BUILDER_NAME}" || true
docker commit "${CONTAINER_BUILDER_NAME}" $DOCKER_IMAGE
docker rm "${CONTAINER_BUILDER_NAME}"
