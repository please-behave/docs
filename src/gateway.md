# Gateway

The gateway receives attestations from senders such as the [CLI](cli.md)
and forwards them to the [ledger](ledger.md). Set `GATEWAY_LEDGER_URL` to the
ledger's HTTP or HTTPS origin, for example `https://ledger.example.org`.
See the [gateway repository](https://github.com/please-behave/gateway) for the
container image and other settings.

## Issue and rotate sender keys

Choose a sender label and run the key generator.

```sh
gateway keygen example-ci
```

The command prints a random bearer key and a configuration entry in the form
`<sender>:<SHA-256 hex hash>`. Give the bearer key to the sender. Set
`GATEWAY_API_KEYS` to the comma-separated configuration entries on every
gateway instance. The gateway uses the matching entry's label as the sender.
An empty list leaves ingest without an authorized key.

To rotate a key, generate a new key with the same sender label and add its
entry alongside the old one on all instances. Switch the sender to the new
key, then remove the old entry from all instances.

## Check ingest and readiness

The gateway returns `201 Created` and the attestation ID after the ledger
confirms creation. See the [ingest contract](https://github.com/please-behave/gateway/blob/main/why/contracts/ingest/attestation.md)
for the request format and error responses.

`GET /readyz` confirms that the gateway loaded valid configuration.
It can succeed during a ledger outage.
