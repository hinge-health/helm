#!/bin/bash

set -euo pipefail

if [[ -n "${DEBUG:-}" ]]; then
  set -x
fi

function cleanup() {
  echo "Exiting and cleaning up after ourselves."
  pids="$(pgrep sleep) $(pgrep kubectl)" # had no luck with killall...
  if [[ $pids != "" ]]; then
    kill $pids
  fi
}

trap cleanup EXIT HUP TERM INT

function watch_pods() {
  local release="$1"
  local namespace="$2"
  local version="$3"

  echo "Gettings Pods"

  kubectl get pods \
    --namespace "${namespace}" \
    --watch \
    --selector "app.kubernetes.io/instance=${release},app.kubernetes.io/version=${version}" 2> /dev/null
}

function watch_pods_events() {
  local release="$1"
  local namespace="$2"
  local version="$3"

  while true ; do
    local args=(
      --namespace "${namespace}"
      --selector "app.kubernetes.io/instance=${release},app.kubernetes.io/version=${version}"
      --output jsonpath='{.items[*].metadata.name}'
    )

    pending_pods=$(kubectl get pods ${args[@]} --field-selector=status.phase=Pending 2> /dev/null)
    if [[ $pending_pods == "" ]]; then
      echo "No pending pods found.."
      sleep 3
      continue
    fi
    echo "Found some pods, emitting their events..."
    break
  done

  for pod in ${pending_pods}; do
    kubectl get events \
      --namespace=${namespace} \
      --watch_only \
      --field-selector involvedObject.name="${pod}" 2> /dev/null
  done
}

function watch_pods_logs() {
  local release="$1"
  local namespace="$2"
  local version="$3"

  while true; do
    local args=(
      --namespace "${namespace}"
      --selector "app.kubernetes.io/instance=${release},app.kubernetes.io/version=${version}"
      --output jsonpath='{.items[*].metadata.name}'
    )

  running_pods=$(kubectl get pods "${args[@]}" --field-selector=status.phase=Running -ojson | jq -r '.items[] | select(.status.containerStatuses[].started | not) | .metadata.name' 2> /dev/null)
  echo $running_pods
  if [[ $running_pods == "" ]]; then
    echo "Searching for pods with logs to display..."
    sleep 8
    continue
  fi
  echo "Found some pods, showing their logs..."
  break
  done

  for pod in ${running_pods}; do
    kubectl logs \
      --namespace "${namespace}" \
      --all-containers \
      --prefix \
      --follow \
      "${pod}" 2> /dev/null
  done
}

function get_first_non_option() {
  for arg in "$@"; do
    if [[ "${arg}" != "-"* ]]; then
      echo "${arg}"
      return
    fi
  done
}

function get_namespace() {
  for arg in "$@"; do
    if [[ "${arg}" = "--namespace"* ]]; then
      namespace=`echo $arg | cut -d"=" -f 2`
      echo "${namespace}"
      return
    fi
  done
}

release="$(get_first_non_option "$@")"
namespace="$(get_namespace "$@")"
version=${IMAGE_TAG} # should be in the environment in our github workflow

watch_pods "${release}" "${namespace}" "${version}" &
watch_pods_logs "${release}" "${namespace}" "${version}" &
watch_pods_events "${release}" "${namespace}" "${version}" &

helm3 upgrade "$@" & # our action calls it helm3 (because we use helm 3)
pid="$!"

wait ${pid}
helm_status=$?
exit $helm_status