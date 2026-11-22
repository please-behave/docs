# Docker Compose example

Run the gateway, ledger, cockpit, and PostgreSQL locally, then publish a CLI
attestation and read it back from the ledger. You need Docker with the
`docker compose` plugin, Git, and [Please Behave CLI](https://github.com/please-behave/cli/releases)
0.19.0 or later on your `PATH`. The first startup downloads images. The
publish and read steps use the local stack and synthetic credentials.

## Start the stack

```sh
git clone https://github.com/please-behave/docs.git please-behave-docs
cd please-behave-docs/compose
compose_dir=$PWD
docker compose up -d --wait
export PLEASE_GATEWAY_KEY="$(cat example-key.txt)"
```

Once PostgreSQL is ready, the `migrate` container applies the schema and
exits. The ledger starts after the migration succeeds. The gateway and
cockpit listen on host loopback ports 8080 and 8081, respectively. PostgreSQL
and the ledger are reachable only on the private Compose network. The
gateway configuration contains the SHA-256 hash of the example key and
associates it with the sender `example-ci`.

## Publish an attestation

In the same shell, create a temporary Git repository containing one check
and a publishing configuration.

```sh
example_repo=$(mktemp -d)
cd "$example_repo"
git init --initial-branch=main
mkdir -p .please/checks/readme

cat > README.md <<'EOF'
# Example project
EOF

cat > .please/config.toml <<'EOF'
project = "Compose example"

[publish]
gateway_url = "http://127.0.0.1:8080"
key_env = "PLEASE_GATEWAY_KEY"
repository = "git.example.org/team/compose-example"
EOF

cat > .please/checks/readme/rule.toml <<'EOF'
id = "repository-readme"
description = "Require a nonempty README"
run_at = ["check"]

[check]
command = "test -s README.md"
EOF

git add README.md .please
git -c user.name="Example Author" -c user.email="author@example.org" commit -m "Add example check"
please run --at check
please publish
```

The check passes and `please publish` reports gateway acceptance. The
explicit repository identity lets you publish from this local repository
without adding a remote.

## Read the attestation

Return to the `compose/` directory and run an HTTP request from the
PostgreSQL container, which shares the ledger's private network.

```sh
cd "$compose_dir"
docker compose exec -T postgres wget -qO- http://ledger:8080/v0/attestations/latest
```

Find the summary for `git.example.org/team/compose-example`. Its `sender` is
`example-ci`. Substitute its `id` for `ATTESTATION_ID` to retrieve the
full attestation, including the `repository-readme` result.

```sh
docker compose exec -T postgres wget -qO- http://ledger:8080/v0/attestations/ATTESTATION_ID
```

## Optional GitHub sign-in

The cockpit starts with synthetic OAuth settings. For browser sign-in you
need network access to GitHub, a GitHub OAuth app, and an HTTPS URL that
serves the cockpit. Supply the settings described in
[Configure GitHub sign-in](cockpit.md#configure-github-sign-in) for the
client ID, client secret, registered HTTPS callback URL, cookie key, and
allowed numeric GitHub user IDs. Set those variables in your shell and run
`docker compose up -d cockpit` from `compose/` to apply them. Compose
already sets the ledger URL. Open `/sign-in` at your HTTPS URL.

## Stop the stack

From `compose/`, stop the stack and remove its example database volume.

```sh
docker compose down --volumes
unset PLEASE_GATEWAY_KEY
```
