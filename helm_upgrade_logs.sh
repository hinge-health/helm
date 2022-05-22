#!/bin/bash

## FIXME:
## gsed on pod log file bork
## need to only tail new pods logs

set -euo pipefail

if [[ -n "${DOTFILES_DEBUG:-}" ]]; then
  set -x
fi

show_help() {
cat << EOF
Usage: $(basename "$0") <options>
    -h, --help               Display help
    -v, --version            The chart-releaser version to use (default: $DEFAULT_CHART_RELEASER_VERSION)"
        --config             The path to the chart-releaser config file
    -d, --charts-dir         The charts directory (default: charts)
    -u, --charts-repo-url    The GitHub Pages URL to the charts repo (default: https://<release>.github.io/<repo>)
    -o, --release              The repo release
    -r, --repo               The repo name
    -c, --chartmuseum_url    The URL of the Chartmuseum Instance e.g. chartmuseum.example.com
EOF
}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            -r|release)
                if [[ -n "${2:-}" ]]; then
                    config="$2"
                    shift
                else
                    echo "ERROR: '--release' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -v|--version)
                if [[ -n "${2:-}" ]]; then
                    version="$2"
                    shift
                else
                    echo "ERROR: '-v|--version' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --n|namespace)
                if [[ -n "${2:-}" ]]; then
                    charts_dir="$2"
                    shift
                else
                    echo "ERROR: '-n|--namespace' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            *)
                break
                ;;
        esac

        shift
    done

    if [[ -z "$release" ]]; then
        echo "ERROR: '-r|--release' is required." >&2
        show_help
        exit 1
    fi

    if [[ -z "$repo" ]]; then
        echo "ERROR: '-v|--version' is required." >&2
        show_help
        exit 1
    fi

    if [[ -z "$namespace" ]]; then
        echo "ERROR: '-n|--namespace' is required." >&2
        show_help
        exit 1
    fi

    if [[ -z "$charts_repo_url" ]]; then
        charts_repo_url="https://$release.github.io/$repo"
    fi
}

function ensure_path_entry() {
  local entries=("$@")

  for entry in "${entries[@]}"; do
    if [[ ":${PATH}:" != *":${entry}:"* ]]; then
      export PATH="${entry}:${PATH}"
    fi
  done
}

function log_color() {
  local color_code="$1"
  shift

  printf "\033[${color_code}m%s\033[0m\n" "$*" >&2
}

function log_red() {
  log_color "0;31" "$@"
}

function log_blue() {
  log_color "0;34" "$@"
}

function log_green() {
  log_color "1;32" "$@"
}

function log_yellow() {
  log_color "1;33" "$@"
}

function log_task() {
  log_blue "🔃" "$@"
}

function log_manual_action() {
  log_red "⚠️" "$@"
}

function log_c() {
  log_yellow "👉" "$@"
}

function c() {
  log_c "$@"
  "$@"
}

function c_exec() {
  log_c "$@"
  exec "$@"
}

function log_error() {
  log_red "❌" "$@"
}

function log_info() {
  log_red "ℹ️" "$@"
}

function error() {
  log_error "$@"
  exit 1
}

################################################################
## ABOVE is script_libray
## BELOW is helm install debug
################################################################

mkdir helm_upgrade_log_tmp
watching_pods_logs_file=$(mktemp helm_upgrade_log_tmp/helm-upgrade-logs.watching-pods-logs.XXXXXX)
watching_pods_events_file=$(mktemp helm_upgrade_log_tmp/helm-upgrade-logs.watching-pods-events.XXXXXX)

function cleanup() {
  rm -f "${watching_pods_logs_file}" "${watching_pods_events_file}" || true
  jobs -pr | xargs -r kill
}

trap cleanup EXIT

function prefix_output() {
  local prefix="$1"
  local color_code="$2"
  shift 2

  local gsed_replace
  gsed_replace=$(printf "\033[${color_code}m%s: &\033[0m" "${prefix}")

  # shellcheck disable=SC2312
  "$@" &> >(gsed "s,^.*$,${gsed_replace}," >&2)
}

function watch_pods() {
  local release="$1"
  local namespace="$2"

  sleep 3 # Prevent flodding the logs with the initial output
  prefix_output "pods" "1;32" c kubectl get pods \
    --namespace "${namespace}" \
    --watch \
    --selector "app.kubernetes.io/instance=${release}"
}

function watch_pod_logs() {
  local pod="$1"
  local namespace="$2"

  if grep -q "^${pod}$" "${watching_pods_logs_file}"; then
    return
  fi

  echo "${pod}" >>"${watching_pods_logs_file}"

  prefix_output "pod ${pod} logs" "0;34" c kubectl logs \
    --namespace "${namespace}" \
    --all-containers \
    --prefix \
    --since 10s \
    "${pod}" || true

  # remove from watch list (it may be added again)
  gsed -i "/^${pod}$/d" "${watching_pods_logs_file}"
}

function watch_pod_events() {
  local pod="$1"
  local namespace="$2"

  if grep -q "^${pod}$" "${watching_pods_events_file}"; then
    return
  fi

  echo "${pod}" >>"${watching_pods_events_file}"

  prefix_output "pod ${pod} events" "0;35" c kubectl get events \
    --namespace "${namespace}" \
    --watch-only \
    --field-selector involvedObject.name="${pod}" || true

  # remove from watch list (it may be added again)
  gsed -i "/^${pod}$/d" "${watching_pods_events_file}"
}

function watch_pods_logs_and_events() {
  local release="$1"
  local namespace="$2"

  sleep 10 # Prevent flodding the logs with the initial output
  while true; do
    local args=(
      --namespace "${namespace}"
      --selector "app.kubernetes.io/instance=${release}"
      --output jsonpath='{.items[*].metadata.name}'
    )

    for pod in $(
      kubectl get pods "${args[@]}" --field-selector=status.phase=Pending
    ); do
      watch_pod_events "${pod}" "${namespace}" &
    done

    for pod in $(
      kubectl get pods \
        --namespace=${namespace} \
        --field-selector=status.phase=Running \
        "${args[@]}"
    ); do
      watch_pod_logs "${pod}" "${namespace}" &
    done

    sleep 10
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

function get_image_tag() {
  for arg in "$@"; do
    if [[ "${arg}" = "--namespace"* ]]; then
      namespace=`echo $arg | cut -d"=" -f 2`
      echo "${namespace}"
      return
    fi
  done
}

function main() {
    local version=
    local config=
    local release=

    parse_command_line "$@"
    : "${GITHUB_TOKEN:?Environment variable GITHUB_TOKEN must be set}"

    c helm upgrade "${release}" hinge-health/hinge-service --install
}
release="$(get_first_non_option "$@")"
namespace="$(get_namespace "$@")"
env
c helm "$@" &
pid="$!"

watch_pods "${release}" "${namespace}" &

watch_pods_logs_and_events "${release}" "${namespace}" &

wait "${pid}"
rm -rf helm_upgrade_log_tmp
