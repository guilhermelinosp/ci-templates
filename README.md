# CI Templates

Pipeline reutilizável para build, scan, assinatura e publicação de imagens Docker no GitHub Container Registry (GHCR), com git flow integrado.

## Git Flow

### Branches

| Branch | Uso | Recebe PR de |
|---|---|---|
| `main` | Produção | `staging` ou `hotfix/*` |
| `staging` | Desenvolvimento contínuo | `feature/*` ou `bugfix/*` |
| `feature/*` | Nova funcionalidade | — |
| `hotfix/*` | Correção urgente | — |

### Fluxo

```
feature/login → PR → staging
                        ↓
                  staging → PR → main
                                    ↓
                              release-please 🤖
                              ├── Calcula próxima versão (SemVer)
                              ├── Gera changelog automático
                              ├── Cria GitHub Release
                              └── Cria tag vX.Y.Z
                                    ↓
                              main → sync staging

hotfix/crash → PR → main (release-please) → sync staging
```

### Versionamento (SemVer + Release Please)

Automático via `googleapis/release-please-action`:

| Convencional Commits | Versão |
|---|---|
| `fix:` | PATCH (1.0.0 → 1.0.1) |
| `feat:` | MINOR (1.0.0 → 1.1.0) |
| `BREAKING CHANGE` ou `feat!:` | MAJOR (1.0.0 → 2.0.0) |

### Conventional Commits

```
feat(auth): adiciona login com Google
fix(api): corrige timeout do gateway
docs(readme): atualiza documentação
refactor(user): simplifica validação
test(auth): adiciona testes de login
BREAKING CHANGE: altera formato da response
```

## Workflows

### CI / Validação

| Workflow | Evento | Descrição |
|---|---|---|
| `branch-rules.yml` | push + PR | Bloqueia push direto em `main`/`staging`, valida nomes de branch e PR title |
| `merge-check.yml` | PR | Valida Conventional Commits nos commits do PR |

### Pipeline de Imagem

| Workflow | Tipo | Descrição |
|---|---|---|
| `pipeline.yml` | **Orchestrator** | release → buildx → trivy + cosign → push |
| `release.yml` | reusable | Semver bump, git tag, GitHub Release |
| `buildx.yml` | reusable | Build multi-arch com SBOM, provenance e cache registry |
| `trivy.yml` | reusable | Scan vulnerabilidades HIGH/CRITICAL (SARIF → GitHub Security) |
| `cosign.yml` | reusable | Assinatura keyless (sigstore) em modo OCI referrers |
| `push.yml` | reusable | Promote image digest para tags latest + versão |
| `release-please.yml` | reusable | Versionamento + changelog automático no merge pra main |

### Outros

| Workflow | Tipo | Descrição |
|---|---|---|
| `docs.yml` | reusable | Build + deploy MkDocs para GitHub Pages |

### Pipeline flow

```
push/PR → pipeline.yml (runner: self-hosted)
            │
            ├── release.yml      → v1.2.3
            ├── buildx.yml       → ghcr.io/owner/app@sha256:abc...
            ├─┬ trivy.yml (par.) → SARIF → GitHub Security
            │ └ cosign.yml (par.)→ Signature → OCI referrers
            └── push.yml         → promote latest + v1.2.3
```

## Como usar

### Em um repositório de app

Crie `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  pull_request:
    branches: [main, staging]
  push:
    branches: [staging]

jobs:
  validate:
    uses: guilhermelinosp/ci-templates/.github/workflows/branch-rules.yml@main
    secrets: inherit
  merge-check:
    uses: guilhermelinosp/ci-templates/.github/workflows/merge-check.yml@main
    secrets: inherit
```

### Release automática

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    branches: [main]
jobs:
  release:
    uses: guilhermelinosp/ci-templates/.github/workflows/release-please.yml@main
    secrets: inherit
```

### Pipeline de imagem (após release)

```yaml
# .github/workflows/build.yml
name: Build
on:
  release:
    types: [published]
jobs:
  pipeline:
    uses: guilhermelinosp/ci-templates/.github/workflows/pipeline.yml@main
    with:
      runner: self-hosted
    secrets: inherit
```

### Setup inicial do repositório

```bash
git clone git@github.com:guilhermelinosp/meu-repo.git
cd meu-repo
git checkout -b staging && git push origin staging
git checkout main
```

## Configuração

Crie `config.yml` na raiz do repositório:

```yaml
image: nome-da-imagem
```

Se `config.yml` não existir, usa o nome do próprio repositório como fallback.

## Pré-requisitos

- Dockerfile na raiz do repositório
- GitHub Actions habilitado
- ARC runner (self-hosted) ou `ubuntu-latest`
- Permissões: `contents: write`, `packages: write`, `id-token: write`

## ADRs

| Documento | Gist |
|---|---|
| ADR-001: Alloy OTLP Gateway | https://gist.github.com/guilhermelinosp/09b474deeceaab3984225a22bf657347 |
| ADR-002: ARC + Auto-Runners | https://gist.github.com/guilhermelinosp/ec92d1edcfcccaf4fb87ca6ea46e01ba |
| ADR-003: Git Flow + Branching | https://gist.github.com/guilhermelinosp/b32f0681a03eb0fefe5f6a237b0c4ee5 |
