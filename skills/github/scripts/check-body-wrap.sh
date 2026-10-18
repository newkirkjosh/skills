#!/usr/bin/env bash
# Flag a hard-wrapped PR or issue body. GitHub reflows markdown, so prose
# should be one line per paragraph. Reads the body on stdin.
#
# usage: bash check-body-wrap.sh < body.md
#        gh pr view <n> --json body -q .body | bash check-body-wrap.sh
# Exit 0 when prose is not hard-wrapped, 1 when it is.
#
# A heuristic, not a markdown parser: fenced and indented code, headings,
# blockquotes, tables, list items and their continuation lines are skipped,
# and the body counts as wrapped when most remaining lines sit in the 60-100
# column band. On a 1, read the body before rewriting it.
set -uo pipefail

awk '
  # A fence closes only on the same character, at least as long as it opened.
  {
    t = $0; sub(/^[[:space:]]+/, "", t)
    if (t ~ /^```/ || t ~ /^~~~/) {
      ch = substr(t, 1, 1); len = 0
      while (substr(t, len + 1, 1) == ch) len++
      if (!fence)                          { fence = ch; flen = len; next }
      else if (ch == fence && len >= flen) { fence = ""; flen = 0; next }
    }
  }
  fence                { next }
  /^[[:space:]]*$/     { next }
  /^(    |\t)/         { next }
  /^[[:space:]]*#/     { list = 0; next }
  /^[[:space:]]*>/     { list = 0; next }
  /^[[:space:]]*\|/    { list = 0; next }
  /^[[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]/ { list = 1; next }
  /^[[:space:]]/       { if (list) next }
  { list = 0; n++; if (length($0) >= 60 && length($0) <= 100) w++ }
  END {
    if (n == 0) { print "no prose lines to check"; exit 0 }
    printf "prose lines: %d; in the 60-100 column band: %d\n", n, w
    if (w * 2 > n) { print "HARD-WRAPPED: rewrite each paragraph as one line"; exit 1 }
    print "OK: prose is not hard-wrapped"
  }'
