# Overview

Please Behave shows the results of development rules for each repository.
Teams define those rules alongside their code and use the reported outcomes
to see which rules passed, failed, or could not be evaluated for a given run.
The [central Why](https://github.com/please-behave/why/tree/main/why) explains
the purpose and principles behind this approach.

## How a report reaches the cockpit

{{#include report-flow.svg}}

1. The [CLI](cli.md) runs checks and reviews and saves a local report.
   When you run `please publish`, it sends a summary of the newest eligible
   report as an **attestation**.
2. The [gateway](gateway.md) authenticates the sender, validates the
   attestation, and forwards it to the ledger with the sender label associated
   with the key.
3. The [ledger](ledger.md) stores the attestation in PostgreSQL and serves it
   through its read API.
4. The [cockpit](cockpit.md) reads from the ledger. After signing in, you can see
   the latest reported attestation for each repository and execution-point
   combination and open its individual rule results.

The [GitHub collector](github-collector.md) independently sends the ledger a
repository inventory and observations of default-branch heads. This lets the
[dashboard](cockpit.md#read-the-repository-dashboard) show repositories that
have never reported check evidence.

## Evidence and its limits

An attestation carries the report format version, repository identity, saved
commit, execution point, overall verdict, and each result's rule ID, kind, and
status. Detailed output, review findings, and local paths stay in the local
report. Review pass and check pass remain distinguishable through the rule
kind. See the [CLI report contract](https://github.com/please-behave/cli/blob/main/why/contracts/report/document.md#publishing-evidence).

The gateway authenticates the sender. The repository identity and verdict are
claims made by that sender. Acceptance confirms that the ledger stored the
submitted evidence. See the [gateway ingest contract](https://github.com/please-behave/gateway/blob/main/why/contracts/ingest/attestation.md).

Deterministic checks interpret command results and are reproducible. AI
reviews depend on the evidence they receive and can reach different judgments
across runs. A review pass records the review's judgment for that run and
carries no proof that the requirement is satisfied. See
[DEC-0002, Verdicts Carry Their Evidential Weight](https://github.com/please-behave/why/blob/main/why/decisions/DEC-0002.yaml).
