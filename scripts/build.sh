#!/bin/sh
set -eu

book_root=$(cd "${1:-.}" && pwd)
mdbook build "$book_root"
lychee --offline --include-fragments=anchor-only --index-files index.html \
  --root-dir "$book_root/book" "$book_root/book/docs/**/*.html"
