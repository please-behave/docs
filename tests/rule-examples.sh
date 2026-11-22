#!/bin/sh
set -eu

examples=$(cd examples && pwd)
fixture=$(mktemp -d)
log=$(mktemp)
trap 'rm -rf "$fixture" "$log"' EXIT

export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
cd "$fixture"
git init --quiet --template= --initial-branch=main
git remote add origin https://git.example.invalid/team/my-app.git
please init >/dev/null

echo "Validate the My_App example rules"
sed -i.bak 's/^project = .*/project = "My_App"/' .please/config.toml
rm .please/config.toml.bak
cp -R "$examples/my-app/checks/build" .please/checks/
cp -R "$examples/my-app/reviews/product" .please/reviews/
please sync --yes

echo "Run the dummy adapter"
mkdir tools .please/adapters
cp "$examples/adapters/dummy.py" tools/dummy-adapter.py
cp "$examples/adapters/dummy.toml" .please/adapters/dummy.toml
sed -i.bak 's/^enabled = false/enabled = true/; s/^\[review\]/[review]\nadapter = "dummy"/' \
  .please/reviews/product/rule.toml
rm .please/reviews/product/rule.toml.bak
printf '# My_App\n' >README.md
git add -A
git -c user.name=example -c user.email=example@example.invalid commit --quiet --no-verify -m 'chore: add example'

echo "Check rule versions and knowledge digests offline"
please run --at pre-push --plan --json >"$log"
python3 - "$log" <<'PY'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as plan_file:
    plan = json.load(plan_file)
rules = {rule["id"]: rule for rule in plan["scheduled"] + plan["disabled_rules"]}
for rule_id in ("macos-build", "my-app-product"):
    metadata = rules[rule_id].get("rule_metadata", {})
    if metadata.get("version") != "1.0" or not re.fullmatch(
        r"v1:sha256:[0-9a-f]{64}", metadata.get("digest", "")
    ):
        raise SystemExit(f"{rule_id}: expected version 1.0 and a knowledge digest")
PY

if please run --at pre-push >"$log" 2>&1; then
  cat "$log" >&2
  echo "Expected the dummy adapter review to end as ERROR" >&2
  exit 1
fi
if ! grep -Fq "my-app-product · ERROR" "$log" ||
  ! grep -Fq "Dummy adapter performs no AI assessment" "$log"; then
  cat "$log" >&2
  exit 1
fi

echo "The example rules validate and the dummy adapter ends as ERROR"
