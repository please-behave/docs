# Adapters

An adapter connects Please Behave reviews to an AI CLI, HTTP API or local model.
It owns authentication, model settings, permissions and the communication with the
AI provider, including timeouts, retries, backoff and budgets of that
communication. Please Behave only bounds one adapter invocation by its configured
deadline and output limits, and it ships no adapter.

Describe the adapter in an
[adapter profile](configuration.md#configure-an-adapter-profile) and select the
profile in a review, or set a project default. This guide covers CLI 0.20.0. The
binding definitions are the contracts in the CLI repository; if this guide and a
contract differ, the contract is right:

- [Invocation](https://github.com/please-behave/cli/blob/main/why/contracts/adapter/invocation.md): process, streams, exit status, deadlines and
  trust.
- [Request](https://github.com/please-behave/cli/blob/main/why/contracts/adapter/request.md) and its
  [JSON schema](https://github.com/please-behave/cli/blob/main/why/contracts/adapter/request.schema.json): review input and adapter settings.
- [Response](https://github.com/please-behave/cli/blob/main/why/contracts/adapter/response.md) and its
  [JSON schema](https://github.com/please-behave/cli/blob/main/why/contracts/adapter/response.schema.json): verdict evidence, local validation and
  optional telemetry.

## How an adapter works

For each selected review, Please Behave starts the configured command once, writes
one JSON request to its standard input and reads the result. The exit status gives
the verdict:

| Exit status | Result |
| --- | --- |
| 0 | `PASS`, only with a valid response on standard output. |
| 1 | `FAIL`, only with a valid response on standard output. |
| Any other status | `ERROR`. Explain the failure on standard error. |

At exit status 0 or 1, standard output carries exactly one JSON response object
with the `protocol_version` of the request, a one-line `reason` and the `findings`.
Please Behave checks cited files and lines locally, so a response alone does not
establish `PASS`. A timeout, a missing or invalid response and output above the
limits also end as `ERROR`. Please Behave never retries.

An adapter runs with your permissions and is neither sandboxed nor supplied with AI
provider tools. Never print credentials: the output of an `ERROR` stays visible in
`please status --details`.

## Try the dummy adapter

The [dummy adapter](https://github.com/please-behave/docs/tree/main/examples/adapters)
shows the protocol without any AI provider. It rejects unsupported protocol versions
and then exits with status 2 because it performs no assessment, so every review that
uses it ends as `ERROR`. Do not use it as a working adapter.

1. Copy `dummy.py` to `tools/dummy-adapter.py` in your repository.
2. Save `dummy.toml` as `.please/adapters/dummy.toml`.
3. Add `adapter = "dummy"` to the `[review]` table of an enabled review.
4. Run `please sync`, then `please run`, and read the diagnostic with
   `please status --details`.

## Write your own adapter

Start from the dummy and replace its result generation with the communication with
your AI provider. Read the request from standard input, ask the provider to assess
the evidence against the review criteria, and print the response object. Report
technical failures with another exit status. Keep credentials in the environment of
the adapter and list their names in the `requirements` of the profile.

The [illustrative My_App setup](https://github.com/please-behave/docs/tree/main/examples/my-app)
in the same directory shows a check and a review for a macOS application that you can
adapt to your project.
