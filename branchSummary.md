# Branch summary: `LeoBranch` vs `main`

`LeoBranch` is `main` (merge base `7f244f4`, "Merge pull request #1") **plus the commits below**. `main` has nothing
that `LeoBranch` lacks, so merging is a fast-forward of these changes.

| Commit | What it does |
|---|---|
| `ebd3b10` | Adds `modules/env-access` to the legacy `test-orchestration` stage (first attempt at point A) |
| `bd83239` | Reverts `ebd3b10`: it duplicated the per-stage service accounts and edited the frozen legacy stage |
| `bfe026e` | Point A: read-only `qa_approvers` group in `1-org` |
| `217c523` | Point B: 2 QA approvals before anything reaches Prod |
| `e172e24` | Point C: Prod only runs container images that QA approved and the pipeline signed |
| (this commit) | `convo.md` and this file |

`ebd3b10` and `bd83239` cancel each other out, so they leave **no difference** in the files. Net result: about 35
files changed, around 1,165 lines added and 49 removed, plus the two root documents.

---

## The goal

A change from QA reaches Prod only with the approval of **two QA users who have that privilege**, following least
privilege. Approvers can look but not change anything. Only dedicated service accounts can deploy or sign, and only
from the protected pipeline.

```
PR ──► CI (fmt, tflint, checkov, tests, plan, script-tests) ──► ruleset: 2 approvals + Code Owners
                                                                   │
merge to main ──► apply.yml ──► qa-approval: ≥2 approvals from QA_APPROVERS on the last commit
                                   ├─► Terraform stages (Prod jobs also wait for the `prod` environment)
                                   └─► attest-prod: signs images listed in release/prod-images.txt
                                                         │
Prod GKE ◄── Binary Authorization: only images with the `qa-approved` attestation (+ GKE system images)
```

---

## Point A: who approves vs who deploys (`bfe026e`)

`main` already separated the two: per-stage deploy service accounts (0-bootstrap) and read-only human groups
(ADR 0009-g). What was missing was a group for the people who approve.

| File | Change |
|---|---|
| `stages/1-org/variables.tf` | New accepted key `qa_approvers` in `var.groups` |
| `stages/1-org/iam.tf` | Read-only roles `browser`, `container.clusterViewer`, `logging.viewer`, `monitoring.viewer`, **only on the `qa` and `prod` folders**. Nothing on `dev`, the organization or individual projects. No `roles/viewer`, no write roles, no acting as service accounts |
| `stages/1-org/tests/org.tftest.hcl` | Assertions: only `qa`/`prod` folders, only read-only roles, clusters visible |
| `docs/adr/0020-k-grupo-qa-approvers.md` | Decision record |
| `stages/1-org/README.md`, `terraform.tfvars.example` | Document the new key |

---

## Point B: enforce 2 QA approvals (`217c523`)

On `main`, the docs said the `prod` environment "requires two approvals", but GitHub asks for **one** approval from an
environment's reviewer list. The live settings were also weaker than documented (see `convo.md`, turn 7).

| File | Change |
|---|---|
| `.github/workflows/apply.yml` | New `qa-approval` job, which the whole apply chain depends on. If the push touches a Prod root, a shared stage (`1-org`, `2-security`, `3-networks/hub`) or the release list, it requires ≥2 QA approvals on the merged PR. Fails closed |
| `scripts/check-qa-approvals.sh` | The check: finds the PR for the commit and counts each reviewer's latest review. Only approvals on the head commit from logins in `QA_APPROVERS` count, and the PR author is excluded |
| `scripts/tests/check-qa-approvals.test.sh` | 13 tests with a fake `gh` |
| `.github/workflows/ci.yml` | New `script-tests` job, included in `ci-ok` |
| `.github/rulesets/main.json` | Ruleset for `main`: 2 approvals, Code Owners, stale approvals dismissed, last-push approval, conversations resolved, `ci-ok` required with an up-to-date branch, no deletion or force push, **no bypass**. Applied by an admin with `gh api` |
| `stages/0-bootstrap/main.tf` | New WIF attribute `attribute.prod_main` (`"true"` only for environment `prod` **and** `refs/heads/main`). Prod and shared-stage service accounts now require it |
| `stages/0-bootstrap/tests/bootstrap.tftest.hcl`, `README.md` | Updated for `prod_main` |
| `.github/CODEOWNERS` | Requests the `@acme/gcp-qa-approvers` team on Prod roots |
| `docs/adr/0021-k-dos-aprobaciones-de-qa.md` | Decision record, including the live settings found |
| `docs/runbooks/qa-approvers.md` | Checklist to add QA users later: people table, GitHub and GCP steps, end-to-end test, removals |
| `docs/README.md`, ADR 0004-e, ADR 0016-j | Fix the "two approvals" claims; document `QA_APPROVERS`, the ruleset and "Prevent self-review"; remove the outdated "CODEOWNERS is a template" note |

---

## Point C: Binary Authorization in Prod (`e172e24`)

On `main`, clusters evaluate Binary Authorization, but no policy exists, so every image is allowed. Binary
Authorization can't express "any 2 of N people", so the **pipeline signs after the QA check**; nobody signs by hand.

| Stage / file | Change |
|---|---|
| `0-bootstrap` | New service account `attestor-prod`: no Terraform state access, no organization roles, WIF only from `prod` on `main` |
| `1-org/main.tf` | Binary Authorization and Container Analysis APIs on the security project |
| `1-org/iam.tf` | Custom role `attestor_iam_admin` (get/getIamPolicy/setIamPolicy only). `2-security` gets `attestorsAdmin` and `notes.editor` on the security project. `attestor-prod` gets `notes.attacher` and `occurrences.editor` on the security project. `4-projects-prod` gets `binaryauthorization.policyEditor` **only on the Prod folder** |
| `2-security/binauthz.tf` (new) | KMS key `binauthz-qa-approved` (`ASYMMETRIC_SIGN`, EC P-256), note and attestor `<prefix>-prod-qa-approved`. `signerVerifier` **only** for `attestor-prod` **only** on that key. `attestor_iam_admin` for `4-projects-prod` on the attestor |
| `2-security/outputs.tf` | `binauthz_attestor`, `binauthz_key_version` |
| `4-projects/modules/env/binauthz.tf` (new) | Prod app project policy: `REQUIRE_ATTESTATION`, `ENFORCED_BLOCK_AND_AUDIT_LOG`, GKE system images allowed. The project's Binary Authorization service agent gets `attestorsVerifier` on the attestor only |
| `4-projects/modules/env/variables.tf`, `envs/prod/main.tf` | `binauthz_attestor`, required when `env = prod`. Dev and QA keep the default policy |
| `release/prod-images.txt` (new) | List of images approved for Prod, **pinned by digest only** |
| `scripts/attest-images.sh` (new) | `check` validates the format; `sign` signs each image that isn't signed yet, using only GA gcloud commands |
| `scripts/tests/attest-images.test.sh` (new) | 14 tests with a fake `gcloud` |
| `apply.yml` | `detect` reports whether the release list changed. `qa-approval` also guards it. New `attest-prod` job (environment `prod`) does the signing |
| `ci.yml` | `script-tests` also runs the signing tests and checks the release list's format |
| `.checkov.yaml` | Corrected skip reasons for `CKV_GCP_66` and `CKV_GCP_43` (the asymmetric key can't auto-rotate) |
| Tests | New runs in 0-bootstrap, 1-org (also the `custom_role_ids` contract), 2-security and 4-projects |
| Docs | ADR 0022-k (with a least-privilege table), runbook section 3, README variables, `CONTRATO.md`, CODEOWNERS for `release/` |

---

## Least privilege at a glance

| Identity | Can do | Where |
|---|---|---|
| QA approvers (people) | Read only | `qa` and `prod` folders |
| QA approvers (GitHub) | Approve PRs; their logins in `QA_APPROVERS` count toward the 2 | Repository |
| `attestor-prod` | Sign with one key and attach attestations | One key and the security project; only from `prod` on `main` |
| `4-projects-prod` | Edit the Binary Authorization policy and attestor permissions | Prod folder and the attestor only |
| Prod Binary Authorization service agent | Verify attestations | The attestor only |
| Other people | Nothing new | — |

---

## Validation run on this branch

- `gcp-datacenter/scripts/validate-all.sh` (fmt, validate of all roots, every `terraform test`): **52 passed, 0 failed**
- Checkov (with `.checkov.yaml`): **198 passed, 0 failed**
- tflint v0.66.0 (google ruleset 0.41.0) on the changed roots: clean
- actionlint and shellcheck: clean
- Script tests: `check-qa-approvals` 13/13, `attest-images` 14/14

**Not done:** no `plan` or `apply` against GCP, and no GitHub settings were changed (the author has write access,
not admin).

---

## Things to know before merging

1. **Once merged, any push that touches Prod, a shared stage or the release list is blocked until the repo admin sets
   `QA_APPROVERS` with at least 2 logins.** This is on purpose; set it before or right after merging.
2. With the ruleset applied, every PR needs 2 approvals from people other than the author and the last pusher.
3. Apply order (see `docs/runbooks/qa-approvers.md`):
   1. 0-bootstrap (manual, admin);
   2. GitHub variables;
   3. 1-org;
   4. 2-security;
   5. `BINAUTHZ_*` variables;
   6. 4-projects-prod.
4. **Before applying 4-projects-prod**, add any image already running in Prod to `release/prod-images.txt`, or those
   pods can't be recreated.
5. Removing an image from the list doesn't revoke its signature (see ADR 0022-k).
6. The `@acme/...` teams in CODEOWNERS only work if the repo moves to a GitHub organization (ADR 0017-j).
