# Ledger

The ledger stores attestations in PostgreSQL. The [gateway](gateway.md) writes
them and the [cockpit](cockpit.md) reads them. See the
[ledger repository](https://github.com/please-behave/ledger) for the container
image and service configuration.

## Migrate the database and start the service

Set `LEDGER_DATABASE_URL` to your PostgreSQL connection URL for both the
migration command and the service. Apply the migrations with the same
ledger release you intend to serve.

```sh
ledger migrate
```

The command applies the embedded migrations and exits. It creates the schema
in an empty database and can be run again after a successful migration.
Run `ledger` to start the service. Schema changes happen only through the
migration command. The [migration decision](https://github.com/please-behave/ledger/blob/main/why/decisions/DEC-0003.yaml)
describes how releases can share a database during a rollout.

## Check readiness

`GET /healthz` returns `200 OK` while the service is running. Use
`GET /readyz` before routing traffic to the instance. It returns `200 OK`
when PostgreSQL is reachable and all migrations required by this build have
been applied. Otherwise it returns `503 Service Unavailable`.

See the [ledger contracts](https://github.com/please-behave/ledger/tree/main/why/contracts)
for the ingest and read interfaces.
