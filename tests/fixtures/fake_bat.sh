#!/bin/sh
# Stands in for bat in tests/features/test_code_fenced.nim: colors every
# line bold 81, fails for the language "nope", changes the text for "mangle".
lang="$2"
[ "$lang" = nope ] && { echo "unknown syntax" >&2; exit 1; }
while IFS= read -r line; do
  [ "$lang" = mangle ] && line="$line!"
  printf '\033[1;38;5;81m%s\033[0m\n' "$line"
done
