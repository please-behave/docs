#!/bin/sh
set -eu

compose_dir=$(cd compose && pwd)
fixture=$(mktemp -d)
suffix=$(printf '%s' "${fixture##*.}" | LC_ALL=C tr '[:upper:]' '[:lower:]')
set -- docker compose --env-file /dev/null --profile collector \
  -f "$compose_dir/compose.yaml" -f "$fixture/offline.yaml" -p "please-example-test-$suffix"

cleanup() {
  status=$?
  if [ "$status" -ne 0 ]; then
    "$@" logs --no-color >&2 || true
  fi
  if ! "$@" down --volumes --remove-orphans; then
    status=1
  fi
  rm -rf "$fixture"
  exit "$status"
}
trap 'cleanup "$@"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

unset COCKPIT_GITHUB_CLIENT_ID COCKPIT_GITHUB_CLIENT_SECRET COCKPIT_GITHUB_CALLBACK_URL
unset COCKPIT_COOKIE_KEY COCKPIT_GITHUB_ALLOWED_IDS
export NO_PROXY=127.0.0.1 no_proxy=127.0.0.1

cat >"$fixture/offline.yaml" <<'YAML'
services:
  github-collector:
    networks: !override [private]
YAML
GITHUB_COLLECTOR_ENV_FILE="$fixture/collector.env"
export GITHUB_COLLECTOR_ENV_FILE
cat >"$GITHUB_COLLECTOR_ENV_FILE" <<'ENV'
GITHUB_COLLECTOR_SCOPES=example-team/sample-app
GITHUB_COLLECTOR_TOKEN_EXAMPLE_TEAM=synthetic-collector-token
ENV

"$@" up -d --wait --wait-timeout 90 --pull never --no-build

cd "$fixture"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
git init --template= --initial-branch=main
mkdir -p .please/checks/readme
printf '# Example project\n' >README.md

cat >.please/config.toml <<'EOF'
project = "Compose example"

[publish]
key_env = "PLEASE_GATEWAY_KEY"
repository = "git.example.org/team/compose-example"
EOF

cat >.please/checks/readme/rule.toml <<'EOF'
id = "repository-readme"
description = "Require a nonempty README"
run_at = ["check"]

[check]
command = "test -s README.md"
EOF

git add README.md .please
git -c user.name="Example Author" -c user.email="author@example.org" commit -m "Add example check"
please run --at check
PLEASE_GATEWAY_KEY=$(cat "$compose_dir/example-key.txt")
export PLEASE_GATEWAY_KEY

python -I - "$(git rev-parse HEAD)" "$@" <<'PY'
import json
import os
import subprocess
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.request import ProxyHandler, Request, build_opener
from uuid import UUID

commit, *compose = sys.argv[1:]
path = "/v0/attestations"
gateway = "http://127.0.0.1:8080"
latest = path + "/latest"
opener = build_opener(ProxyHandler({}))


def read_ledger(endpoint):
    return json.loads(subprocess.check_output(
        [*compose, "exec", "-T", "postgres", "wget", "-T", "5", "-qO-", "http://ledger:8080" + endpoint],
        timeout=10,
    ))


def response_status(request):
    try:
        with opener.open(request, timeout=5) as response:
            return response.status
    except HTTPError as error:
        with error:
            return error.code


def post(key, payload):
    return response_status(Request(
        gateway + path, data=json.dumps(payload).encode(), method="POST",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    ))


for attempt in range(10):
    try:
        initial = read_ledger(latest)
        assert post("unknown-example-key", {}) == 401, "Gateway did not challenge an unknown key"
        break
    except (subprocess.CalledProcessError, URLError) as error:
        if attempt == 9:
            raise RuntimeError("The ledger and gateway did not become ready") from error
        time.sleep(1)

assert initial == [], f"Expected an empty ledger, got {initial!r}"
overview_path = "/v0/repositories/overview"
assert read_ledger(overview_path)["repositories"] == [], "Expected an empty repository overview"
collector_logs = subprocess.check_output(
    [*compose, "logs", "--no-color", "github-collector"], text=True, timeout=10,
)
assert "GitHub collector started" in collector_logs, "The GitHub collector did not start"
assert response_status(Request(gateway + "/")) == 404, "Expected HTTP 404 at the gateway root"
assert response_status(Request(gateway + "/readyz")) == 204, "Expected HTTP 204 from gateway readiness"
subprocess.run(["please", "publish", "--gateway-url", gateway], check=True, timeout=30)

stored = read_ledger(latest)
assert len(stored) == 1, f"Expected one attestation, got {stored!r}"
summary = stored[0]
attestation_id = summary["id"]
assert UUID(attestation_id).version == 7, f"Expected a version 7 UUID, got {attestation_id!r}"
expected = {
    "repository": "git.example.org/team/compose-example",
    "commit": commit,
    "execution_points": ["check"],
    "overall": "PASS",
}
for field, value in {**expected, "sender": "example-ci"}.items():
    assert summary[field] == value, f"Expected {field}={value!r}, got {summary[field]!r}"

results = [{"id": "repository-readme", "kind": "check", "status": "PASS"}]
detail = read_ledger(f"{path}/{attestation_id}")
verification = {"status": "unverified", "reason": "unregistered"}
assert detail == {
    **summary, "rule_sets": [], "results": [{**results[0], "verification": verification}],
}, f"Unexpected attestation detail: {detail!r}"

repositories = read_ledger(overview_path)["repositories"]
assert len(repositories) == 1, f"Expected one repository, got {repositories!r}"
entry = repositories[0]
assert entry["repository"] == expected["repository"], entry
assert entry["managed"] is False and entry["state"] == "unknown", entry
assert entry["latest_check"]["overall"] == "PASS", entry

key = os.environ["PLEASE_GATEWAY_KEY"]
payload = {"schema_version": 1, **expected, "results": results}
for label, request_key, body, expected_status in [
    ("unknown key", "unknown-example-key", payload, 401),
    ("invalid structure", key, {**payload, "results": "invalid"}, 400),
    ("client-supplied sender", key, {**payload, "sender": "forged-example"}, 400),
]:
    status = post(request_key, body)
    assert status == expected_status, f"{label}: expected HTTP {expected_status}, got {status}"
    assert read_ledger(latest) == stored, f"{label}: the rejected request changed the ledger"

print("The example started the collector, published and read back an attestation, and rejected invalid requests")
PY
