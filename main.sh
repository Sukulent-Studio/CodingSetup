#! /bin/bash

USED_FROM_DIR="$(pwd)"
MAIN_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_PM="pnpm"

export USED_FROM_DIR
export MAIN_SCRIPT_DIR
export NODE_PM

source "${MAIN_SCRIPT_DIR}/scripts/checkPackages.sh"

main_pkgs=("gum" "jq" "nodejs" "pnpm" "git")
ni_main_pkgs=()

check_pkgs -c 'pacman -Qq "$pkg" > /dev/null 2>&1' -a "main_pkgs" -o "ni_main_pkgs"

echo "${ni_main_pkgs[@]}"

./ai/opencode/agents/report-maker/settings.sh