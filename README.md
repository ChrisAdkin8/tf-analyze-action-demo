# tf-analyze-action-demo

End-to-end demo for the **[`ChrisAdkin8/tf-analyze`](https://github.com/marketplace/actions/tf-analyze)** GitHub Action.

Open a pull request that touches `terraform/**` and the workflow exercises every load-bearing feature of the action: HIGH-threshold gating, inline `suggestion` comments, the engine-rendered PR summary, the OWASP IaC compliance gap report, and the Mermaid attack-graph block.

> [!CAUTION]
> The `terraform/` directory is **intentionally insecure** — a teaching fixture for the scanner. Do not deploy any of it. See [SECURITY.md](SECURITY.md).

---

## Quickstart

1. **Fork or clone** this repo into your own account.
2. **Push a no-op change** to `terraform/main.tf` on a branch and open a PR. The simplest way:
   ```sh
   git clone https://github.com/<you>/tf-analyze-action-demo
   cd tf-analyze-action-demo
   git checkout -b trigger-demo
   echo "# trigger" >> terraform/main.tf
   git commit -am "trigger tf-analyze"
   git push -u origin trigger-demo
   gh pr create --fill
   ```
3. **Watch the action run.** Within ~90s you should see:
   - A status check on the PR (red, because the fixture trips multiple HIGH findings — `fail-on: HIGH` is doing its job).
   - A bot comment with the engine-rendered PR summary (score, top findings, Mermaid attack graph, collapsible OWASP IaC compliance section).
   - Inline review comments with `suggestion` blocks on the lines that introduced findings — click **Apply suggestion** to one-click-fix.
   - A SARIF upload in the repo's **Security → Code scanning alerts** tab.
   - An `tf-analyze-report` artifact on the workflow run (HTML report, 30-day retention).

That's the entire demo. The rest of this README explains the moving parts.

---

## The workflow

[`.github/workflows/tf-analyze.yml`](.github/workflows/tf-analyze.yml) wires the action up in the smallest possible way:

```yaml
- uses: ChrisAdkin8/tf-analyze@v1
  with:
    fail-on: HIGH
    post-pr-comment: true
    compliance-framework: owasp_iac
    attack-graph: true
    ref: v0.2.4
```

The workflow also declares:

- **Triggers**: `pull_request` on changes to `terraform/**` (so docs-only PRs don't burn minutes) plus `push` to `main` for the post-merge baseline run.
- **Permissions**: `pull-requests: write` is the load-bearing one — without it `post-pr-comment` silently no-ops. `security-events: write` is needed for the SARIF upload to Code Scanning. `contents: read` is the default.

---

## Per-input reference

Every input the action accepts, with the demo's value and what other values do. Sourced from [`action.yml`](https://github.com/ChrisAdkin8/tf-analyze/blob/v1/action.yml).

| Input | Default | Demo value | What it does |
|---|---|---|---|
| `target` | `.` | _(default)_ | Path within the workspace to scan. Useful if your Terraform lives in a subdirectory. |
| `fail-on` | `HIGH` | `HIGH` | Minimum urgency that fails the check. Allowed: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, `INFO`. Set to `CRITICAL` for a softer gate, `MEDIUM` for a stricter one. |
| `mode` | `auto` | _(default)_ | Engine mode. `auto` resolves to `diff` on `pull_request` events and `static` elsewhere. Other values: `plan`, `fleet`, `trend`, `pr-review`. |
| `section` | _(empty)_ | _(default)_ | Restrict to one catalogue section. Useful when you only want `security` rules or want to silo `robustness`/`ops`. |
| `attack-graph` | `true` | `true` | Build the internet → crown-jewels attack graph and promote critical-path findings one urgency tier. Embeds a Mermaid graph in the PR summary. |
| `baseline` | _(empty)_ | _(default)_ | Path to a prior JSON report. Findings present in the baseline are suppressed; only **new** findings affect the exit code. Useful for legacy repos with a known baseline of issues. |
| `post-pr-comment` | `true` | `true` | Posts the engine-rendered PR summary as a bot comment and inline `suggestion` blocks on changed lines. Requires `permissions: pull-requests: write`. |
| `upload-sarif` | `true` | _(default)_ | Uploads `tf-analyze.sarif` to GitHub Code Scanning. Requires `permissions: security-events: write`. |
| `upload-html-artifact` | `true` | _(default)_ | Uploads the HTML report as a 30-day workflow artifact. |
| `compliance-framework` | _(empty)_ | `owasp_iac` | Optional compliance gap report. Allowed: `cis`, `pci_dss`, `soc2`, `owasp_iac`, `all`. Adds a collapsible compliance section to the PR comment. Validated — an unknown framework fails the action with `::error::`. |
| `ref` | _(empty)_ | `v0.2.4` | Shorthand for the image tag. `ref: v0.2.4` is equivalent to `image: ghcr.io/chrisadkin8/tf-analyze:0.2.4` — the leading `v` is stripped before building the docker tag (R31.6), so both `v0.2.4` and `0.2.4` work. Non-semver values (`main`, `latest`) pass through untouched. **Mutually exclusive with `image:`.** |
| `image` | `ghcr.io/chrisadkin8/tf-analyze:latest` | _(default)_ | Engine Docker image. Override to pin (or to test a fork). Mutually exclusive with `ref:`. |
| `extra-args` | _(empty)_ | _(default)_ | CLI flags appended verbatim to `detect.py`. Read-then-tokenized via `read -ra` (no shell-substitution). Useful for `--check-registry`, `--oscal PATH`, `--pdf-output PATH`. |

### Outputs

The action also exposes the following outputs for downstream steps:

| Output | Description |
|---|---|
| `score` | Risk score 0–100. |
| `grade` | Letter grade — `A`, `B`, `B-`, `C`, `D`, or `F`. |
| `total-findings` | Total findings count (all urgencies). |
| `critical-count` | CRITICAL findings only. |
| `high-count` | HIGH findings only. |
| `json-report-path` / `html-report-path` / `sarif-report-path` | Absolute paths to the generated reports. |

---

## The fixture

[`terraform/main.tf`](terraform/main.tf) deliberately wires a real privilege-escalation chain so the attack-graph block has something interesting to render.

| Resource | Findings |
|---|---|
| `aws_s3_bucket.public_data` | public-read ACL, public-access-block disabled, no encryption, no versioning |
| `aws_security_group.wide_open` | `0.0.0.0/0` ingress on 22 (SSH) and 3389 (RDP); unrestricted egress |
| `aws_db_instance.demo` | `publicly_accessible = true`, `storage_encrypted = false`, hardcoded `password = "SuperSecret123!"`, `skip_final_snapshot = true` |
| `aws_iam_role_policy.star_star` | `Action: "*"` on `Resource: "*"` attached to the EC2 instance role |
| `aws_instance.demo` | IMDSv1 allowed (`http_tokens = "optional"`), unencrypted root volume, attached to the wide-open SG and the admin role, public IP |

The chain — **public-internet EC2 → admin IAM role → star/star policy** — is what the attack graph surfaces. Even a single weak link is interesting; the full chain is *why* prioritization-by-path-centrality matters.

---

## Reading the output

### Bot comment on the PR

A single auto-upserted comment at the top of the PR carrying the engine's `--format pr-summary` Markdown:

- Score banner (e.g. `🛡 tf-analyze: 12 (F) · 9 findings`)
- Top-3 findings table with `[<rule_id>]` deep-links to the rule docs site
- The single highest-impact fix (`<details><summary>Suggested fix</summary>…`)
- Collapsible Mermaid attack-graph block
- Collapsible **OWASP IaC compliance** section (because `compliance-framework: owasp_iac` is set)
- Footer: count of inline suggestions posted

### Inline review comments

For every fixable finding on a line in the PR diff, a separate review comment with a `suggestion` block. GitHub renders these with an **Apply suggestion** button — one click, your branch gets the fix as a new commit, the next workflow run is cleaner.

### Code Scanning alerts (SARIF)

`upload-sarif: true` posts findings to **Security → Code scanning alerts**. Each alert is keyed on `rule_id + file + line` so re-runs upsert rather than duplicate. Click an alert to see the engine's narrative (`adversarial_scenario`) and the canonical rule docs URL.

### HTML report (workflow artifact)

`upload-html-artifact: true` attaches `tf-analyze-report.html` to the workflow run. Same content as the bot comment but with the full findings table and inline `<pre>` blocks. Useful for sharing outside the PR (Slack, mail, ticketing).

---

## Customizing the demo

Things to try by editing [`.github/workflows/tf-analyze.yml`](.github/workflows/tf-analyze.yml):

- **Tighten the gate**: `fail-on: MEDIUM` will flip more PRs red. `fail-on: CRITICAL` makes the check almost never fail.
- **Swap compliance frameworks**: `compliance-framework: cis` or `pci_dss` or `soc2` or `all`. Each renders a different gap report. `''` (empty) disables the section entirely.
- **Disable the attack graph**: `attack-graph: false` removes the Mermaid block and turns off path-centrality urgency promotion.
- **Pin a different engine version**: `ref: v0.2.3` to roll back one patch; `ref: latest` for the floating tag; `image: ghcr.io/<your-fork>/tf-analyze:latest` to test a fork.
- **Section filter**: `section: security` to scan only the `security` catalogue; useful for huge repos where `robustness` noise dominates.
- **Baseline a legacy repo**: run the action once on `main`, commit the JSON to the repo as `baseline.json`, then set `baseline: baseline.json` on PR runs. Only *new* findings affect the exit code.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Workflow didn't run on the PR | Triggered paths don't match | The trigger filters on `terraform/**` and `.github/workflows/tf-analyze.yml`. Touch one of those, or remove the `paths:` filter. |
| No bot comment | `permissions: pull-requests: write` missing | Check the top of [`tf-analyze.yml`](.github/workflows/tf-analyze.yml). Forked PRs into your own repo also drop write permissions by default; configure **Settings → Actions → General → Workflow permissions** to allow it. |
| `Unexpected input(s)` warnings | You're on an old `@v1` predating R31.5 | Update `uses:` to `ChrisAdkin8/tf-analyze@v1` (the floating tag picks up the latest release). Verify the action commit at `https://github.com/ChrisAdkin8/tf-analyze/actions`. |
| Action errors on `compliance-framework must be one of …` | Typo or unsupported framework | Valid: `cis`, `pci_dss`, `soc2`, `owasp_iac`, `all`. Lower-case, underscore-separated. |
| Action errors on `'ref' and 'image' are mutually exclusive` | You set both inputs | Pick one. `ref:` is shorthand for `image: ghcr.io/chrisadkin8/tf-analyze:<ref>`; pass the explicit `image:` only when pulling from a fork or non-default registry. |
| Mermaid graph doesn't render | Org disabled Mermaid in Markdown | **Settings → General → Features** in your org settings. The graph is a `<details>`-collapsed fenced block, so other readers still see the source. |
| SARIF doesn't appear in Security tab | Code scanning not enabled, or `security-events: write` missing | Enable code scanning under **Security → Code scanning** (it's free for public repos). Check the permissions block in the workflow. |

---

## Links

- **Action source**: [`ChrisAdkin8/tf-analyze`](https://github.com/ChrisAdkin8/tf-analyze) — engine, catalogue, action.yml
- **Marketplace listing**: [marketplace/actions/tf-analyze](https://github.com/marketplace/actions/tf-analyze)
- **Per-rule docs**: [chrisadkin8.github.io/tf-analyze/rules/](https://chrisadkin8.github.io/tf-analyze/rules/) — every rule has a canonical page (linked from PR comments, SARIF `helpUri`, and the Findings panel)
- **VS Code extension**: [`vscode-extension/`](https://github.com/ChrisAdkin8/tf-analyze/tree/main/vscode-extension) — same engine, in-editor diagnostics + Quick Fix + attack-graph panel
- **Showcase corpora**: [`examples/attack-graph-demo`](https://github.com/ChrisAdkin8/tf-analyze/tree/main/examples/attack-graph-demo), [`examples/module-reuse-demo`](https://github.com/ChrisAdkin8/tf-analyze/tree/main/examples/module-reuse-demo) — bigger fixtures than this one

---

## License

MIT — see [LICENSE](LICENSE).
