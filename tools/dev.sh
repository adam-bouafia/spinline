#!/usr/bin/env bash
# Run Swift commands for the Spinline packages with a known toolchain.
#
# On a workstation every build runs in a memory-capped systemd scope at low
# priority, so a large compile cannot freeze the desktop. In CI (CI=true), or
# where systemd-run is missing (macOS), commands run directly.
#
# Usage:
#   tools/dev.sh test  [Package...]        test every package, or the ones named
#                                          (packages without tests are built)
#   tools/dev.sh build [Package...]        build every package, or the ones named
#   tools/dev.sh run   <Package> <product> [args...]
#   tools/dev.sh lint                      swift format lint (strict)
#   tools/dev.sh format                    swift format in place
#   tools/dev.sh packages                  list the packages
#   tools/dev.sh swift <args...>           any swift command, capped
#
# Environment:
#   SPINLINE_TOOLCHAIN    toolchain bin directory (default: Fedora's Swift 6.3.2)
#   SPINLINE_MEMORY_MAX   memory cap for the scope (default: 2500M)
#   SPINLINE_MIN_FREE_MB  refuse to start below this much available memory (default: 3000)
#   SPINLINE_TIMEOUT      seconds before a command is stopped (default: 900)
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
toolchain=${SPINLINE_TOOLCHAIN:-/usr/libexec/swift/6.3.2/bin}
if [[ -d $toolchain ]]; then
    export PATH="$toolchain:$PATH"
fi
memory_max=${SPINLINE_MEMORY_MAX:-2500M}
min_free_mb=${SPINLINE_MIN_FREE_MB:-3000}
timeout_s=${SPINLINE_TIMEOUT:-900}

die() {
    echo "dev.sh: $*" >&2
    exit 1
}

# Every directory that holds a Package.swift, outside build folders.
packages() {
    find "$root/Packages" "$root/tools" -name Package.swift -not -path '*/.build/*' 2>/dev/null |
        sed 's|/Package.swift$||' | sort
}

package_dir() {
    local name=$1 dir
    while read -r dir; do
        if [[ $(basename "$dir") == "$name" ]]; then
            echo "$dir"
            return
        fi
    done < <(packages)
    die "no package named '$name' (see: tools/dev.sh packages)"
}

capped() {
    if [[ -n ${CI:-} ]] || ! command -v systemd-run >/dev/null 2>&1; then
        "$@"
        return
    fi
    local available
    available=$(awk '/MemAvailable/ {print int($2 / 1024)}' /proc/meminfo)
    if ((available < min_free_mb)); then
        die "only ${available} MB available, ${min_free_mb} MB needed; free memory first"
    fi
    systemd-run --user --scope --quiet -p MemoryMax="$memory_max" -p MemorySwapMax=0 \
        nice -n 10 timeout "$timeout_s" "$@"
}

for_each_package() {
    local action=$1
    shift
    # Plain loops instead of mapfile: macOS ships bash 3.2.
    local dirs=() dir name
    if (($# == 0)); then
        while read -r dir; do
            dirs+=("$dir")
        done < <(packages)
    else
        for name in "$@"; do
            dirs+=("$(package_dir "$name")")
        done
    fi
    local run
    for dir in "${dirs[@]}"; do
        run=$action
        # swift test fails on a package without tests (tools); build it instead.
        if [[ $action == test && ! -d $dir/Tests ]]; then
            run=build
        fi
        echo "==> swift $run: ${dir#"$root"/}"
        capped swift "$run" --package-path "$dir"
    done
}

command=${1:-}
shift || true
case $command in
test | build) for_each_package "$command" "$@" ;;
run)
    (($# >= 2)) || die "usage: tools/dev.sh run <Package> <product> [args...]"
    dir=$(package_dir "$1")
    product=$2
    shift 2
    capped swift run --package-path "$dir" "$product" "$@"
    ;;
lint) capped swift format lint --strict --recursive --parallel "$root/Packages" "$root/tools" "$root/App" ;;
format) capped swift format --in-place --recursive --parallel "$root/Packages" "$root/tools" "$root/App" ;;
packages) packages | sed "s|^$root/||" ;;
swift) capped swift "$@" ;;
*) sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
esac
