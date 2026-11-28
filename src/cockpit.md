# Cockpit

The cockpit shows the reported attestations held by the [ledger](ledger.md).
See the [cockpit repository](https://github.com/please-behave/cockpit) for the
container image and how to start the service from source.

## Configure GitHub sign-in

Serve the cockpit through an HTTPS reverse proxy. Register a GitHub OAuth app
with a callback at your cockpit's HTTPS origin followed by
`/sign-in/callback`, for example
`https://cockpit.example.org/sign-in/callback`.

| Required setting | Value |
| --- | --- |
| `COCKPIT_LEDGER_URL` | HTTP or HTTPS origin of the ledger, such as `https://ledger.example.org`. |
| `COCKPIT_GITHUB_CLIENT_ID` | GitHub OAuth app client ID. |
| `COCKPIT_GITHUB_CLIENT_SECRET` | GitHub OAuth app client secret. |
| `COCKPIT_GITHUB_CALLBACK_URL` | The HTTPS callback URL registered with GitHub. |
| `COCKPIT_COOKIE_KEY` | 64 random bytes encoded as 128 hex digits. Generate it with `openssl rand -hex 64` and use the same key on every instance. |
| `COCKPIT_GITHUB_ALLOWED_IDS` | Comma-separated positive numeric GitHub user IDs, such as `12345,67890`. |

Set `COCKPIT_BIND_ADDR` if the reverse proxy needs the service to listen on
a different address than the default `127.0.0.1:8080`.

## Read the repository dashboard

Open `/sign-in` and sign in with an allowed GitHub account. The dashboard
shows which repositories need attention, why they need it, and what the
ledger has received recently.

### Repository health

The status tiles count **Failed**, **Warning**, **Unknown**, and **Passed**
repositories across the whole overview. Hover over a tile or focus it with
the keyboard to preview up to three matching names and see how many more
match. Select a tile to filter the **Repository map** by that status. On a
touch screen, a tap on a tile with a preview opens it, and the next tap
applies the filter. The filter is part of the URL, so you can share the
filtered view. Select **Clear status filter** in the map to show all
repositories again. The counts, **Needs attention**, and **Recent activity**
keep their full scope.

The toolbar shows the oldest covering sync completion, marks it when stale,
and reports when no covering sync has completed. Archived repositories are
excluded from the overview.

| State | Meaning | Health |
| --- | --- | --- |
| **Unknown** | No covering sync has completed, the last one is stale, or there is check evidence but no observed head. | Unknown |
| **Never integrated** | A fresh sync covers the repository, and there is no check evidence. | Failed |
| **Current** | The observed head has check evidence for that exact commit. | Passed |
| **Pending** | Check evidence for the observed head is missing within the grace period. | Passed |
| **Overdue** | The grace period has elapsed. | Warning until the final step, then Failed |

For a known state, a **FAIL** or **ERROR** verdict makes the repository's
health **Failed**. The verdict comes from the newest attestation that
includes `check`. A repository can show **Warning** alongside a **PASS**
verdict when the passing check was reported for an earlier commit and the
observed head is overdue. The ledger configures the grace period, overdue
steps, and sync staleness.
See the [ledger repository overview contract](https://github.com/please-behave/ledger/blob/main/why/contracts/read/repository-overview.md#heartbeat-and-status).

### Needs attention

**Needs attention** lists failed repositories first, followed by those with
warnings and those with unknown health. Each row links to the repository and
explains why it needs attention. A reported failure or error shows the
verdict, commit, and receipt time. An overdue repository without a failing
verdict shows the current and total overdue steps. If every repository is
passing, the widget shows how many it checked.

### Repository map

The map shows a chip for each repository. When the overview spans multiple
organizations, the map groups the chips by organization and shows each
group's health counts for the full overview. A status filter hides groups
with no matches.

Hover over a chip, focus it with the keyboard, or tap it once to preview the
full repository name, health, state, and latest check verdict. **Not
managed** identifies a repository with attestations and no collector inventory
entry. **No evidence** means the ledger has no attestation that includes
`check` for the repository. When there is evidence, the preview shows the
reported commit and receipt time. For a pending or overdue head, it shows
the head commit, how long it has been waiting for evidence, and how many
heads the collector has observed since the last evidence. The count can
miss changes between syncs.

When available, the preview links to the latest recorded release and the
bound versions of completed Rule Sets, and shows the latest deployment
target and receipt time. Follow the chip link to the repository page to see
its latest attestation for each execution-point combination, recent
attestations, releases, and deployments. On a touch screen, tap the chip
again to follow the link. Select an attestation's reported time to see
its rules and outcomes.
See the [cockpit repository overview contract](https://github.com/please-behave/cockpit/blob/main/why/contracts/browser/repository-overview.md).

### Recent activity

**Recent activity** combines up to ten of the newest attestations, releases,
and deployments, ordered by when the ledger received them. Each entry shows
its kind, a link to the repository, the verdict, release version, or deployment
target, and how long ago the ledger received it. If a read fails, the feed
keeps the last entries it received for that kind and identifies the affected
kind.

## View the reported evidence

The dashboard and **Attestations** tab refresh while the browser tab is
visible. The default interval is five minutes. Use **Refresh interval** to
change it or **Refresh** to read again immediately. A dashboard refresh
keeps the active status filter.

The **Attestations** tab loads older reports as you scroll, and the **Releases**
tab shows [recorded releases](recording-releases.md#view-releases-in-the-cockpit)
with their reported evidence. The
[Deployments tab](recording-deployments.md#view-deployments-in-the-cockpit)
shows what was reported on each target and what evidence is available.
Sessions expire after eight hours.
**Sign out** clears the session in your browser.

See the [cockpit sign-in requirements](https://github.com/please-behave/cockpit/tree/main/why/requirements)
and the [ledger read contracts](https://github.com/please-behave/ledger/tree/main/why/contracts/read).
