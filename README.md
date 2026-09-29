# acme-iacsandbox-deploy

No-AWS sandbox for the shared Terraform workflows in
[acme-iacplatform-githubworkflows](https://github.com/56kcloud/acme-iacplatform-githubworkflows).
It stands in for a foundation deploy repo: `engorg/` and `prodorg/` are environment
directories with a `null_resource` and a local backend.

One workflow per env, `.github/workflows/terraform-<env>.yml`, on
`pull_request`, push to `main`, and `workflow_dispatch` (`plan`/`apply`):

- **`plan` job** (shared `terraform-plan.yml`, no `environment:`): plans every
  time. On PRs it also scans. It uploads `tfplan`, `plan.txt`
  and `.terraform.lock.hcl` as an artifact.
- **`apply` job** (shared `terraform-deploy.yml`, `environment: <env>`): runs on
  push to `main` or dispatched `apply`. It waits for environment approval,
  then applies **that artifact**; it never plans again. A stale plan is
  refused.

**One AWS role for both jobs.** Both jobs receive the same `aws-role-arn`. A
read-only plan role and a separate apply role are planned; when they land,
only the trust policies and the ARN each job receives change. Until then,
branch protection on `main` is what stops unreviewed applies.

## Fixture

| file | terraform | purpose |
|---|---|---|
| `engorg/mise.toml` | 1.13.5 | Full tool set: terraform, tflint, trivy, `min_version`, `[_] CONFIG_SKIP`. |
| `prodorg/mise.toml` | 1.14.2 | Same, deliberately a different Terraform. |

There is no root `mise.toml`. Every tool pin lives in the env directory, so
scanner upgrades roll engorg → prodorg the same way Terraform does. The cost is
that engorg and prodorg can drift for tools other than Terraform, which is
deliberate; group the bumps in Renovate.

Without a root config, a job that forgets mise-action's `working_directory`
installs nothing:
- On `ubuntu-24.04`, `terraform` is not found. That's loud.
- On `ubuntu-22.04` (preinstalls Terraform 1.16.3) or a self-hosted runner
  with Terraform installed, the runner's version runs silently.
- On a self-hosted runner with a persistent mise data dir, shims left over
  from earlier jobs decide what runs.

The shared `setup-tools` verify step (mise's version vs the one on PATH)
fails all of these. Keep it, and keep `runs-on` pinned.

Vendored configs in each env dir (`.tflint.hcl`, `trivy.yaml`, `.trivyignore`,
`.checkov.yml`) must match the shared repo at the SHA that env's stubs pin.

```sh
mise run stubs:pin engorg <sha> v0.1.0  # repin terraform-engorg.yml
mise run config:sync engorg            # vendor configs at that SHA
mise run config:check engorg           # what CI checks
```

## One-time setup

1. **Shared repo access.** The shared repo and this repo are public, so any
   repo can call the shared workflows. If the shared repo goes private, set
   Settings → Actions → General → Access to "Accessible from repositories in
   the organization"; that only covers **private** callers.
2. **GitHub App** with Contents: read, installed on **all repositories** in
   the org. Tokens carry no `repositories:` list, so the installation scope
   is what they can read: the shared repo and every private module repo.
   Reusable workflows check themselves out at `job.workflow_sha`, and a
   caller's `GITHUB_TOKEN` can't read another private repo. In this repo, set
   the variable `SHARED_WORKFLOWS_APP_CLIENT_ID` and the secret
   `SHARED_WORKFLOWS_APP_PRIVATE_KEY`.
3. **Environments** `engorg` and `prodorg`, deployment branch policy `main`
   only, with a required reviewer on `prodorg`. On GitHub Team, required
   reviewers work only in public repos, which is why this repo is public.
4. Push the shared repo, then `mise run stubs:pin <env> <sha> <version>` and
   `mise run config:sync <env>` for both envs.
5. Optional: protect `main` with required code owner review, to test
   CODEOWNERS.
6. Later, with a bootstrapped account: set `AWS_ROLE_ARN_ENGORG` and
   `AWS_ROLE_ARN_PRODORG` repo variables. While they're unset, nothing
   assumes a role.

## Probes

The probe workflows used to validate this setup (OIDC claims, environments,
reusable-workflow interface, secret masking, mise resolution) were removed
after testing. They are in git history at `f399c47` here and `641caa8` in the
shared repo.
