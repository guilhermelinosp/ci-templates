# ci-templates

Reusable GitHub Actions workflows for .NET, Go, containers, Kubernetes, Terraform, AWS, DevSecOps, FinOps, and SRE.

All workflows run on **ubuntu-latest** (GitHub-hosted runners).

## Usage

```yaml
jobs:
  build:
    uses: guilhermelinosp/ci-templates/.github/workflows/dotnet-build.yml@main
```

> Pin to a specific tag for production: `@v1` or `@v1.2.3`

---

## Workflows

### .NET

| Workflow | Description |
|---|---|
| `dotnet-build.yml` | Restore, build, test .NET solution |
| `dotnet-push.yml` | Pack, publish NuGet to GitHub Packages + NuGet.org, create release |
| `nuget-build.yml` | Restore, build, test (simplified, no version input) |
| `nuget-publish.yml` | Pack, publish NuGet to GitHub Packages + NuGet.org |
| `nuget-tag.yml` | Semver bump from conventional commits + git tag |
| `nuget-release.yml` | Create GitHub release from tag |
| `nuget-pipeline.yml` | Orchestration: build → tag → publish → release |

### Go

| Workflow | Description |
|---|---|
| `go-build.yml` | Go tidy, vet, lint (golangci-lint), build, test with cache |

### Node.js

| Workflow | Description |
|---|---|
| `node-build.yml` | npm install, lint, build, test with cache |

### Bash

| Workflow | Description |
|---|---|
| `shellcheck.yml` | ShellCheck + shfmt formatting check |

### Containers

| Workflow | Description |
|---|---|
| `buildah.yml` | Build and push container images with buildah |
| `buildx.yml` | Multi-arch build and push with docker buildx (SBOM + provenance) |
| `cosign.yml` | Sign container images with cosign (keyless, OCI referrers) |
| `trivy.yml` | Vulnerability scan with Trivy (SARIF output) |
| `push.yml` | Promote container images across tags with skopeo |
| `sbom.yml` | Generate SBOM with Anchore Syft (SPDX/CycloneDX) |
| `slsa.yml` | Generate SLSA provenance attestation |

### Kubernetes

| Workflow | Description |
|---|---|
| `helm-lint.yml` | Helm lint, template, kubeconform schema validation |
| `helm-publish.yml` | Package and publish Helm charts to OCI registry |
| `helm-docs.yml` | Auto-generate Helm chart README from values.yaml |
| `kustomize-validate.yml` | Kustomize build + kubeconform validation |
| `deploy.yml` | Helm upgrade via kubeconfig secret + rollout verification |
| `conftest.yml` | OPA policy-as-code for Kubernetes configs |
| `kube-bench.yml` | CIS Kubernetes benchmark |
| `popeye.yml` | K8s cluster sanitizer |

### Terraform

| Workflow | Description |
|---|---|
| `terraform-validate.yml` | Terraform fmt, init, validate |
| `terraform-apply.yml` | Plan + apply with environment gating, OIDC support |
| `terraform-docs.yml` | Auto-generate Terraform docs on PR |
| `terraform-aws-auth.yml` | AWS OIDC auth for Terraform + validate |
| `infracost.yml` | Cloud cost estimation with PR comments |

### AWS

| Workflow | Description |
|---|---|
| `prowler.yml` | AWS CIS security benchmarking (OIDC auth) |

### DevSecOps

#### SAST

| Workflow | Description |
|---|---|
| `codeql.yml` | CodeQL analysis (Go/JS/C# matrix) |
| `semgrep.yml` | Semgrep SAST (configurable rules) |
| `gosec.yml` | Go security static analysis |
| `sonarcloud.yml` | SonarCloud analysis with PR decoration |

#### DAST

| Workflow | Description |
|---|---|
| `zap.yml` | OWASP ZAP baseline/full scan |
| `nuclei.yml` | ProjectDiscovery nuclei vulnerability scanner |

#### Supply Chain

| Workflow | Description |
|---|---|
| `grype.yml` | Anchore Grype vulnerability scanner |
| `snyk.yml` | Snyk vulnerability scanning + monitor |
| `osv-scanner.yml` | Google OSV dependency scanner |
| `owasp-dependency-check.yml` | OWASP Dependency Check |
| `dependency-review.yml` | License + vulnerability review on PRs |

#### IaC Security

| Workflow | Description |
|---|---|
| `checkov.yml` | Bridgecrew IaC scanning (Terraform, K8s, Dockerfile) |
| `tfsec.yml` | Terraform security scanner |
| `kics.yml` | Checkmarx KICS IaC scanning |

#### Container Security

| Workflow | Description |
|---|---|
| `dockle.yml` | Docker CIS benchmark linter |

#### Secrets

| Workflow | Description |
|---|---|
| `gitleaks.yml` | Git secret scanning |
| `trufflehog.yml` | Additional secret scanning |

#### Repository

| Workflow | Description |
|---|---|
| `scorecard.yml` | OpenSSF Scorecard |

### FinOps

| Workflow | Description |
|---|---|
| `infracost.yml` | Terraform cloud cost estimation |
| `kube-resource.yml` | Analyze K8s resource requests/limits |

### Automation

| Workflow | Description |
|---|---|
| `auto-pr.yml` | Auto-create/update PR to main from feature branches |
| `merge-check.yml` | Validate merge strategy, conventional commits |
| `labeler.yml` | Auto-label PRs by changed paths |
| `dependabot-auto-merge.yml` | Auto-approve + squash low-risk Dependabot PRs |
| `stale.yml` | Stale issue/PR management |
| `renovate.yml` | Renovate dependency update automation |
| `commit-lint.yml` | Validate PR commits follow conventional commits |

### Release

| Workflow | Description |
|---|---|
| `release.yml` | Semver bump, git tag, GitHub release, mutable `latest` tag |
| `pipeline.yml` | Push-to-main pipeline: release → build → push |

#### Signed release tags

When the repo (or caller) provides secrets `GPG_PRIVATE_KEY` + `GPG_PASSPHRASE`,
`release.yml` imports the key and creates **signed, annotated** tags
(`git tag -s`) for both the version tag and `latest`. Without them, behavior is
unchanged (lightweight, unsigned tags) — signing is opt-in per repo.

- Public key for verification: [`signing-key.asc`](signing-key.asc)
  (`gpg --import signing-key.asc && git verify-tag v1.2.3`)
- Enrolled repos: hellnet-lib-cache, hellnet-lib-kafka, hellnet-lib-telemetry,
  hellnet-lib-environments, golang-lib-template

> ⚠️ The account is personal (no org-level secrets), so each repo carries its
> own copy of the secret. Use
> [`scripts/sync-gpg-release-secret.sh`](scripts/sync-gpg-release-secret.sh)
> to set/rotate it across all repos in one command. Keep a backup of the
> private key outside GitHub — Actions secrets are write-only.

### AI

| Workflow | Description |
|---|---|
| `ai-review.yml` | AI-powered code review via OpenAI API (PR comments) |

### Code Review

| Workflow | Description |
|---|---|
| `reviewdog.yml` | Automated PR comments (golangci-lint, misspell, shellcheck) |

---

## Patterns

### Passing inputs

```yaml
jobs:
  scan:
    uses: guilhermelinosp/ci-templates/.github/workflows/trivy.yml@main
    with:
      image: ghcr.io/org/app@sha256:abc123
```

### Passing secrets

```yaml
jobs:
  deploy:
    uses: guilhermelinosp/ci-templates/.github/workflows/deploy.yml@main
    with:
      namespace: production
      release-name: my-app
    secrets:
      KUBECONFIG: ${{ secrets.KUBECONFIG }}
```

### Chaining workflows

```yaml
jobs:
  lint:
    uses: guilhermelinosp/ci-templates/.github/workflows/shellcheck.yml@main

  build:
    needs: [lint]
    uses: guilhermelinosp/ci-templates/.github/workflows/go-build.yml@main

  scan:
    needs: [build]
    uses: guilhermelinosp/ci-templates/.github/workflows/gitleaks.yml@main
```

---

## Principles

- **No self-hosted runners** — all workflows run on `ubuntu-latest`
- **Least privilege** — minimal `permissions:` on every workflow
- **SARIF everywhere** — security tools output SARIF for GitHub Security tab
- **Conventional Commits** — semver bump depends on commit messages
- **Reusable** — all workflows are `workflow_call` for composition
