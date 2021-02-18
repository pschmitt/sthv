#!/usr/bin/env bash

usage() {
  echo "Usage: $0 IMAGE_NAME"
}

array_join() {
  local IFS="$1"
  shift
  echo "$*"
}

get_base_image() {
  awk '/^FROM/ { split($NF, img, ":"); print img[1], img[2]; exit }' ./Dockerfile
}

get_available_architectures() {
  local image="$1"
  local tag="${2:-latest}"

  docker buildx imagetools inspect --raw "${image}:${tag}" | \
    jq -r '.manifests[].platform | .os + "/" + .architecture + "/" + .variant' | \
    sed 's#/$##' | sort
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  set -ex

  cd "$(cd "$(dirname "$0")" >/dev/null 2>&1; pwd -P)" || exit 9

  if [[ "$#" -lt 1 ]]
  then
    usage >&2
  fi

  IMAGE_NAME="$1"
  echo "Building image: $IMAGE_NAME" >&2

  case "$1" in
    help|h|-h|--help)
      usage
      exit 0
      ;;
  esac

  read -r base_image base_image_tag <<< "$(get_base_image)"

  # shellcheck disable=2207
  platforms=($(get_available_architectures "${base_image}" "${base_image_tag}"))

  PUSH_IMAGE="${PUSH_IMAGE:-true}"
  BUILD_TYPE="${BUILD_TYPE:-manual}"

  if [[ "$GITHUB_ACTIONS" == "true" ]]
  then
    BUILD_TYPE=github
  fi

  docker buildx build \
    --platform "$(array_join "," "${platforms[@]}")" \
    --output "type=image,push=${PUSH_IMAGE}" \
    --no-cache \
    --label=built-by=pschmitt \
    --label=build-type="$BUILD_TYPE" \
    --label=built-on="$HOSTNAME" \
    --tag "${IMAGE_NAME}:latest" \
    .
fi
