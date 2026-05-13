# tf-analyze-action-demo

Demo repo for the [`ChrisAdkin8/tf-analyze`](https://github.com/marketplace/actions/tf-analyze) GitHub Action.

The `terraform/` directory contains **intentionally insecure** AWS configuration so the action has something to fire on. Do not use as a reference for real infrastructure.

## What you should see on a PR

Open a PR that touches `terraform/**` and the workflow at `.github/workflows/tf-analyze.yml` will:

- Run `tf-analyze` at `ref: v0.2.1`
- Fail the check if any **HIGH** findings are present (`fail-on: HIGH`)
- Post inline `suggestion` blocks on the changed lines (`post-pr-comment: true`)
- Append a collapsible **OWASP IaC** compliance gap report (`compliance-framework: owasp_iac`)
- Embed a **Mermaid attack graph** in the PR summary (`attack-graph: true`)

## Findings you can expect

| Resource | Why it fires |
| --- | --- |
| `aws_s3_bucket.public_data` | public-read ACL, no encryption, no versioning, public-access-block disabled |
| `aws_security_group.wide_open` | 22 + 3389 open to `0.0.0.0/0` |
| `aws_db_instance.demo` | publicly accessible, unencrypted, hardcoded password |
| `aws_iam_role_policy.star_star` | `Action: "*"` on `Resource: "*"` |
| `aws_instance.demo` | IMDSv1 allowed, unencrypted root volume, attached to wide-open SG and admin role |

The combination of the wide-open EC2 → admin IAM role → star/star policy is what makes the **attack graph** interesting — it's an end-to-end privilege-escalation path from the public internet.
