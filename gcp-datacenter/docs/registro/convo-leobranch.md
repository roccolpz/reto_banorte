# Conversation log: landing zone review and the QA approval rule

Record of a working session with Claude Code (2026-11-24) on the `reto_banorte` repository. Each turn shows the
request as written and a summary of the answer and of the work done. Long command output is summarized, not copied.

---

## 1. Explain the project and the 2-QA-approver rule

**Request**

> Can you explain me the infrastructure and the whole project with not so techincal terms? A little bit more simple
> explanation, but not necessarily super simple, enough to describe it. Also, my friend told me that in order that
> the QA changes are launched to Prod, it needs approval from 2 users of the QA department with that privilege.
> Following the least privileged principle, what needs to be implemented in the project to grant these users this
> permission? Can you also explain me the project with a real-life example (analogy) so I can understand it better?

**Answer (based on the local `main`, which turned out to be an early prototype)**

- **What the repo is:** Infrastructure as Code with Terraform. Files describe what Google Cloud should build.
  - `stages/0-bootstrap` creates a versioned bucket for Terraform state.
  - `stages/test-orchestration` builds three environments (Dev, Test, Prod). Each gets a project, a private network
    (VPC/subnet), a small private GKE cluster, and VPC Service Controls perimeters (Prod alone; Dev and Test shared).
  - Reusable modules: `project-factory`, `network-host`, `gke`, `vpc-sc`.
  - Cluster security: private nodes and endpoint, authorized networks, Binary Authorization, Workload Identity and
    Shielded nodes.
- **Analogy:** a bank building new branches.
  - Terraform is the blueprints and the state bucket is the archive room.
  - Dev is the workshop, Test is a mock branch, Prod is the real branch.
  - The VPC is the hallways, GKE is the operations floor, and the private cluster has no street door.
  - Binary Authorization is the badge guard, Workload Identity is personal ID badges, and VPC-SC is the vault
    perimeter.
  - The 2-approver rule is the bank's **dual control**: two officers turn two keys.
- **What to implement (least privilege)**, as four points:
  - **A.** Separate who approves from who deploys: a QA group (read-only), a dedicated deploy service account, and
    no direct human write access to Prod.
  - **B.** Enforce 2 approvals in the pipeline: remote state, a CI/CD pipeline, a 2-approval rule on `main`, Code
    Owners, and WIF limited to `main`/`prod`.
  - **C.** Binary Authorization with QA attestations for container images.
  - **D.** Smaller fixes: pipeline access to a private endpoint, `deletion_protection`, hardcoded org ID, a separate
    QA folder.

---

## 2. Start with point A

**Request**

> Let's start with point A of who approves and who deploys

**Work**

- New module `modules/env-access`:
  - A deploy service account with minimal roles (`browser`, `serviceUsageAdmin`, `compute.networkAdmin`,
    `container.clusterAdmin`).
  - `serviceAccountUser` only on the node service account.
  - `xpnAdmin` only on the environment folder, and `policyEditor` only on the access policy.
  - A QA group with read-only roles.
- Wired into `stages/test-orchestration` for Prod.
- Terraform wasn't installed, so nothing was validated in this turn.

---

## 3. Install Terraform and test

**Request**

> You cajn install terraform to test those changes

**Work**

- Installed Terraform 1.17.2 with Homebrew.
- `terraform validate` passed. Fixed `fmt` in the new module.
- Added offline tests (`terraform test` with a mock Google provider): 3 of 3 passed.
- Noted that `init` added a harmless platform hash to a lock file.

---

## 4. Commit and push to `LeoBranch`

**Request**

> Yes, commit them and push them to my remote branch LeoBranch. Explain the changes in the commit message in detail

**Work**

- Found that remote `LeoBranch` was about 110 commits ahead of the local `main`. It already had the full landing
  zone:
  - stages 0–5 and per-stage deploy service accounts with WIF;
  - read-only human groups with `break_glass` (ADR 0009-g);
  - GitHub Actions and `CODEOWNERS`.
- It also marked `test-orchestration` as frozen legacy.
- Asked how to proceed. The user chose **"Rebase onto LeoBranch anyway"**.
- Moved the changes onto `LeoBranch`, added `versions.tf`, re-validated, committed `ebd3b10` with a detailed
  message, and pushed.

---

## 5. Audit what already exists

**Request**

> Before moving to point B, could ypou check if the smaller issues in the code to fix along the way and if there is
> something already implemented in the current state of project that has been put to fix in the other points,
> including point b are already in the projectt

**Findings on `LeoBranch`**

| Area | Status |
|---|---|
| A: deploy service accounts, read-only humans | Already implemented (0-bootstrap, 1-org, ADR 0009-g). No QA group. |
| B: GCS state, CI plan/apply, WIF | Implemented. WIF limited Prod to the `prod` environment but not to `main`. |
| B: 2 QA approvals | **Not enforced.** The docs claimed "two approvals", but GitHub environments ask for one. No QA team in CODEOWNERS. |
| C: Binary Authorization | Enabled on clusters, but with no policy or attestors, so it allowed everything. |
| D: private endpoint | Not an issue (defaults to `false`). |
| D: `deletion_protection` | On for Prod in code, turned off on purpose in the lab `lab.tfvars`. |
| D: hardcoded org ID | Only left in legacy `test-orchestration`. |
| D: QA folder | Already separate. |

- `gh` returned 401, so the live GitHub settings couldn't be checked yet.
- Recommendation: revert `env-access`, which duplicated existing work, and add the QA group to `1-org`.

---

## 6. Revert and add `qa_approvers` to 1-org

**Request**

> Revert that commit and dad the qa_approvers group to 1-org

**Work**

- `git revert` of `ebd3b10` (commit `bd83239`).
- `1-org`: new `qa_approvers` group key with read-only roles (`browser`, `container.clusterViewer`,
  `logging.viewer`, `monitoring.viewer`), only on the `qa` and `prod` folders.
- Three new test assertions, plus a mutation check: giving the group access to `dev` made the test fail, then the
  code was restored.
- ADR 0020-k; README and tfvars example updated.
- Validation: 1-org 8 of 8 passed. Committed `bfe026e` and pushed.

---

## 7. Checklist, live GitHub settings, point B

**Request**

> Ok I already logged in first with gh auth login. Write the what you need to do in a list of things to look at so we
> can add their users later. Check the live Github settings now that the gh auth login is done, commit changes and
> move to point B

**Live GitHub settings found**

- `main`: classic protection requiring only the `ci-ok` check, and admins can skip it. No rulesets. PR #1 was
  merged with 0 reviews.
- `prod` environment: one reviewer (`roccolpz`), self-review allowed.
- The repo is owned by a personal account, so the `@acme/...` teams in CODEOWNERS don't exist.
- The user has write access, not admin, so settings must be applied by the repo admin.

**Work (commit `217c523`)**

- **`qa-approval` job** in `apply.yml`, run by `scripts/check-qa-approvals.sh`. It requires at least 2 approvals:
  - from the logins in the `QA_APPROVERS` variable;
  - on the PR's latest commit, using each reviewer's latest review;
  - not counting the PR author.
  - It fails closed, and it runs from `main` after the merge, so a PR branch can't change it.
- **Tests**: 13 cases with a fake `gh`, in a new CI job `script-tests`. Run against the real PR #1, the check fails
  with "0 of 2".
- **Ruleset** `.github/rulesets/main.json`: 2 approvals, Code Owners, stale approvals dismissed, last-push approval,
  `ci-ok` required, no force push, no bypass.
- **WIF**: new `attribute.prod_main` (environment `prod` **and** `refs/heads/main`) for Prod and shared-stage service
  accounts.
- **CODEOWNERS**: the QA team requested on Prod roots.
- **Docs**:
  - ADR 0021-k.
  - Checklist `docs/runbooks/qa-approvers.md`: a people table, GitHub/GCP steps, an end-to-end test, and removals.
  - The wrong "two approvals" claims fixed in the README, ADR 0004-e, ADR 0016-j and `apply.yml`.
- **Validation**: actionlint, shellcheck, 13 of 13 script tests, 0-bootstrap 5 of 5.

---

## 8. Point C

**Request**

> Commit these changes, detail them and move to point C

**Work**

- Point B was already committed and the tree was clean.
- Explained that Binary Authorization can't express "any 2 of N people". Asked who should sign; the user chose
  **"Pipeline signs"**.
- **Commit `e172e24`:**
  - `0-bootstrap`: signing service account `attestor-prod`. It has no state access, no org roles, and WIF only from
    `prod` on `main`.
  - `1-org`:
    - APIs on the security project;
    - custom role `attestor_iam_admin`;
    - roles for 2-security, attestor-prod and 4-projects-prod (`policyEditor` only on the Prod folder).
  - `2-security`:
    - KMS key `binauthz-qa-approved` (EC P-256 signing);
    - Container Analysis note and attestor `qa-approved`;
    - `signerVerifier` only for attestor-prod, only on that key;
    - outputs `binauthz_attestor` and `binauthz_key_version`.
  - `4-projects`: Prod app project policy `REQUIRE_ATTESTATION` + `ENFORCED_BLOCK_AND_AUDIT_LOG`, with GKE system
    images allowed. The verifier role is granted to the project's Binary Authorization service agent. The variable is
    required for Prod.
  - Pipeline:
    - release list `release/prod-images.txt` (digests only);
    - `scripts/attest-images.sh check|sign`, using only GA gcloud commands;
    - 14 tests with a fake gcloud;
    - `attest-prod` job behind `qa-approval`;
    - CI checks the list's format.
  - Docs: ADR 0022-k, runbook section 3, README variables, CONTRATO, CODEOWNERS, corrected Checkov skip reasons.
- **Validation**:
  - `validate-all.sh`: 52 of 52 passed;
  - Checkov 198 passed, 0 failed;
  - tflint v0.66.0 clean;
  - actionlint and shellcheck clean.
- **Bugs found and fixed while testing**:
  - a test helper returned the wrong exit code;
  - `git diff | grep -q` under `pipefail` could misreport the release list as unchanged.

---

## 9. This file

**Request**

> Write this whole conversation in a markdown file called convo.md next to the readme.md please. Then, commit all the
> changes and explain all the differences between this branch and main in a separate file called branchSummary.md

**Work:** wrote this file and `branchSummary.md` at the repository root, then committed and pushed both.

---

## Decisions made by the user

| Decision | Choice |
|---|---|
| How to handle the commit after finding `LeoBranch` already had point A | Rebase onto `LeoBranch` anyway (later reverted at the user's request) |
| Who signs images for Binary Authorization | The pipeline signs, after the 2-QA-approval check |

## Pending (needs the repo admin and a GCP admin)

See `gcp-datacenter/docs/runbooks/qa-approvers.md`:

1. Fill in the QA approvers table.
2. Set `QA_APPROVERS`, the `prod` environment reviewers and "Prevent self-review".
3. Apply the ruleset and remove the classic branch protection.
4. Create the Google group and add it to `1-org`.
5. Re-apply `0-bootstrap` and set the `TF_SA_ATTESTOR_PROD`, `BINAUTHZ_ATTESTOR` and `BINAUTHZ_KEY_VERSION`
   variables.
6. Apply 1-org → 2-security → 4-projects-prod. Before 4-projects-prod, list any images already running in Prod in
   `release/prod-images.txt`.
