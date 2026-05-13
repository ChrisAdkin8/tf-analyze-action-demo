# Security policy

## This repository is a teaching fixture, not a reference

[`terraform/main.tf`](terraform/main.tf) is **intentionally insecure**. Every resource trips one or more findings on purpose so the [`ChrisAdkin8/tf-analyze`](https://github.com/ChrisAdkin8/tf-analyze) GitHub Action has something to demonstrate. The findings table in [README.md](README.md) lists what's wrong and why.

**Do not copy any of this Terraform into a real environment.** It would create:

- Publicly-readable S3 buckets without encryption
- Security groups open to `0.0.0.0/0` on SSH and RDP
- A publicly-accessible RDS instance with a hardcoded password
- An IAM role with `Action: "*"` on `Resource: "*"` attached to a public EC2 instance
- An EC2 instance allowing IMDSv1 (vulnerable to SSRF-based credential theft)

If you want a baseline that *passes* a strict tf-analyze scan, start from the [HashiCorp Terraform AWS modules](https://github.com/terraform-aws-modules) or the engine's own [`examples/attack-graph-demo`](https://github.com/ChrisAdkin8/tf-analyze/tree/main/examples/attack-graph-demo) (a tier-segmented production-shaped corpus that scores well *despite* being a demo).

## Reporting issues in the demo repo itself

If you find a genuine security issue with the demo's *automation* — the workflow file, the README's instructions, a malicious dependency, etc. — please open an issue on this repo or contact the maintainer directly. Issues with the action itself belong upstream: [`ChrisAdkin8/tf-analyze/issues`](https://github.com/ChrisAdkin8/tf-analyze/issues).
