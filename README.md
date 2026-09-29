# acme-iacsandbox-deploy

No-AWS sandbox for the shared Terraform workflows in
[acme-iacplatform-githubworkflows](https://github.com/56kcloud/acme-iacplatform-githubworkflows).
It stands in for a foundation deploy repo: `engorg/` and `prodorg/` are environment
directories with a `null_resource` and a local backend.

One stub per env, `.github/workflows/deploy-<env>.yml`, calling the shared
`terraform-deploy.yml` in one job: plan on PR, apply on push to `main`, and
`workflow_dispatch` (`plan`/`apply`, apply on `main` only). With no AWS account
passed, the job skips AWS credentials and runs against the local backend.

The stubs keep the template's path filter on push but not on `pull_request`:
every PR plans every env, so each env's check (`deploy / Deploy <env>`) can be
required. A path-filtered check that never runs would block the PR.

As in the template, the job binds `environment: <env>` on every run, so a PR
plan for `prodorg` waits for its required reviewer, and the environments allow
all branches.

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
`.checkov.yml`, `.terraform-docs.yml`) must match the shared repo at the SHA that env's stubs pin.

```sh
mise run stubs:pin engorg <sha> v0.1.0  # repin deploy-engorg.yml
mise run config:sync engorg            # vendor configs at that SHA
mise run config:check engorg           # what CI checks
```

### Owning a config file

Listing a file in `CONFIG_SKIP` (under `[_]` in the env's `mise.toml`) makes
the env's copy the one CI uses, unchecked against the shared repo. That can
weaken scanning without anyone noticing:

- trivy's `severity` is an exact list, not a threshold. Replacing `HIGH` with
  `MEDIUM` stops HIGH findings being reported at all. A local `trivy.yaml`
  must keep `HIGH` and `CRITICAL` and add levels, never swap them.
- `.trivyignore` entries need a reason and an expiry, as its header says.

CODEOWNERS gives the platform team every env's `mise.toml` and scanner
configs, so owning or editing one needs their review. It only takes effect
with branch protection on `main` requiring code owner review.

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
   the variable `GITHUBMCH_REPOS_READ_APP_CLIENT_ID` (an org variable at the
   client) and the secret `GITHUBMCH_REPOS_READ_APP_PRIVATE_KEY`.
3. **Environments** `engorg` and `prodorg`, open to all branches (PR plans bind
   them too), with a required reviewer on `prodorg`. On GitHub Team, required
   reviewers work only in public repos, which is why this repo is public.
   "Require main for apply" in the shared workflow stops applies from other
   branches.
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
