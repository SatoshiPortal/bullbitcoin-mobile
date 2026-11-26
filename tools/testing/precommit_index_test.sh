#!/usr/bin/env bash
# Exercise the hook with the pinned formatter and controlled analyze/fix results.
set -euo pipefail
root=$(git rev-parse --show-toplevel)
hook=${1:-"$root/.git_hooks/pre-commit"}
fvm=$(command -v fvm)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
cd "$fixture"
git init -q
cp "$root/.fvmrc" .
mkdir -p bin member
cat > bin/fvm <<'SH'
#!/usr/bin/env bash
if [[ $1 == dart && $2 == fix ]]; then
  echo fix >> "$CHECKS"
  if [[ ${REAL_FIX:-0} == 1 ]]; then
    printf 'name: [invalid\n' > pubspec.yaml
    exec "$REAL_FVM" "$@"
  fi
  echo 'Nothing to fix!'
  exit "${FIX_EXIT:-0}"
elif [[ $1 == flutter && $2 == --version ]]; then
  echo 'Flutter fixture'
else
  exec "$REAL_FVM" "$@"
fi
SH
cat > bin/make <<'SH'
#!/usr/bin/env bash
echo analyze >> "$CHECKS"
SH
chmod +x bin/*
export REAL_FVM="$fvm" PATH="$fixture/bin:$PATH"
export CHECKS="$fixture/checks" GIT_INDEX_FILE="$fixture/custom-index"
good=$'void main() {\n  print(1);\n}'
bad='void main(){print(1);}'
check() {
  local name=$1 expected=$2 checks=$3 actual=0
  : > "$CHECKS"
  bash "$hook" > "$fixture/hook.log" 2>&1 || actual=$?
  if [[ $actual != "$expected" || $(sort "$CHECKS") != "$checks" ]]; then
    cat "$fixture/hook.log"
    echo "FAIL $name (exit $actual)" >&2
    exit 1
  fi
  echo "PASS $name"
}
both=$'analyze\nfix'
path='member/partial.dart'
printf '%s\n' "$bad" > "$path"
git add -- "$path"
printf '%s\n' "$good" > "$path"
check 'unformatted index, formatted worktree' 1 ''
git add -- "$path"
printf '%s\n' "$bad" > "$path"
check 'formatted index, unformatted worktree' 0 "$both"
rm "$path"
check 'formatted index, missing worktree file' 0 "$both"
printf '%s\n' "$good" > "$path"
printf '%s\n' "$good" > 'member/space and
newline.dart'
git add -- 'member/space and
newline.dart'
check 'spaces and newline in path' 0 "$both"
printf '%s\n' "$bad" > member/example.g.dart
git add -- member/example.g.dart
check 'generated file excluded' 0 "$both"
FIX_EXIT=1 check 'dart fix fails despite success text' 1 "$both"
REAL_FIX=1 check 'real dart fix fails on invalid pubspec' 1 "$both"
rm pubspec.yaml
git -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm initial
printf 'formatter:\n  page_width: 35\n' > analysis_options.yaml
printf 'void main() {\n  print("a line that fits at the root");\n}\n' > root.dart
git add -- root.dart
check 'root formatter settings' 1 ''
git reset -q -- root.dart
rm analysis_options.yaml root.dart
printf 'formatter:\n  page_width: 35\n' > member/analysis_options.yaml
printf 'void main() {\n  print("a line that fits at the root");\n}\n' > origin.dart
git add -- origin.dart
git -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm root
git mv -- origin.dart 'member/renamed test.dart'
printf '%s\n' "$good" > 'member/renamed test.dart'
check 'rename uses destination formatter settings' 1 ''
