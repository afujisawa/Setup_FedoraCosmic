#!/bin/bash
# check.sh: runs every project check and prints a summary.

set -u

cd "$(dirname "$0")/.." || exit 1

status=0

mapfile -d '' shell_files < <(
	find . -path ./.git -prune -o -name '*.sh' -print0
)

run() {
	local label=$1
	shift
	printf '\n==> %s\n' "$label"
	if "$@"; then
		printf 'OK: %s\n' "$label"
	else
		printf 'FAIL: %s\n' "$label"
		status=1
	fi
}

# shellcheck disable=SC2317  # called indirectly through run()
check_line_length() {
	local output
	output=$(awk 'length > 80 { print FILENAME ": " FNR ": " length }' "$@")
	if [ -n "$output" ]; then
		printf '%s\n' "$output"
		return 1
	fi
}

if [ "${#shell_files[@]}" -gt 0 ]; then
	run "shellcheck" shellcheck -x "${shell_files[@]}"
	run "shfmt: format diff" shfmt -i 0 -ci -bn -d "${shell_files[@]}"
	run "lines > 80" check_line_length "${shell_files[@]}"
else
	echo "No .sh files found."
fi

if [ -d tests ]; then
	run "bats: tests" bats tests/
fi

printf '\n'
if [ "$status" -eq 0 ]; then
	echo "All checks passed."
else
	echo "Some checks failed."
fi

exit "$status"
