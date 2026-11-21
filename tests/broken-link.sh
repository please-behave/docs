#!/bin/sh
set -eu

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
cp book.toml "$fixture/"
cp -R src "$fixture/"

missing_page=broken-link-test-missing-page
missing_anchor=broken-link-test-missing-anchor
printf '\n[Missing page](%s.md)\n' "$missing_page" >>"$fixture/src/overview.md"
printf '\n[Missing anchor](#%s)\n' "$missing_anchor" >>"$fixture/src/overview.md"

if sh scripts/build.sh "$fixture" >"$fixture/build.log" 2>&1; then
  echo "Expected the build to reject the broken links" >&2
  exit 1
fi

if [ ! -f "$fixture/book/docs/index.html" ] ||
  ! grep -Fq "$missing_page.html" "$fixture/build.log" ||
  ! grep -Fq "#$missing_anchor" "$fixture/build.log"; then
  cat "$fixture/build.log" >&2
  exit 1
fi

echo "The build rejected a missing page and a missing anchor"
