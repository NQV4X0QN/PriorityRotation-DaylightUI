#!/bin/bash
# Runs every check from the repo root: syntax, luacheck, then each tests/*_test.lua.
set -u
cd "$(dirname "$0")/.." || exit 1

LUA=/opt/homebrew/opt/lua@5.4/bin/lua
LUAC=/opt/homebrew/opt/lua@5.4/bin/luac
ADDON=PriorityRotationDUI
status=0

for f in "$ADDON"/*.lua; do
  "$LUAC" -p "$f" || status=1
done

if command -v luacheck >/dev/null 2>&1; then
  luacheck -q "$ADDON" tests || status=1
else
  echo "luacheck not found"; status=1
fi

for t in tests/*_test.lua; do
  result="$("$LUA" "$t" "$ADDON" 2>&1)"
  rc=$?
  printf '%-24s %s\n' "$(basename "$t" .lua)" "$(printf '%s\n' "$result" | tail -1)"
  if [ $rc -ne 0 ]; then printf '%s\n' "$result" | grep FAIL; status=1; fi
done

if [ $status -eq 0 ]; then echo "ALL GREEN"; else echo "FAILURES"; fi
exit $status
