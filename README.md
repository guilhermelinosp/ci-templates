# CI Templates

Pipeline reutilizável para build, scan, assinatura e publicação de imagens Docker no GitHub Container Registry (GHCR).

## Workflows

| Workflow | Tipo | Descrição |
|---|---|---|
| `pipeline.yml` | **Orchestrator** | Pipeline completa: release → buildx → trivy + cosign → push |
| `release.yml` | reusable | Semver bump, git tag, GitHub Release, VERSION file |
| `buildx.yml` | reusable | Build multi-arch com SBOM, provenance e cache registry |
| `trivy.yml` | reusable | Scan de vulnerabilidades HIGH/CRITICAL com SARIF |
| `cosign.yml` | reusable | Assinatura keyless (sigstore) em modo OCI referrers |
| `push.yml` | reusable | Promote image digest para latest + versão |
| `docs.yml` | reusable | Build + deploy MkDocs para GitHub Pages |

## Como usar

### Em um repositório de app

Crie `.github/workflows/ci.yml`:

```yaml
name: CI
on:
  push:
    branches: [ main ]
jobs:
  ci:
    uses: guilhermelinosp/ci-templates/.github/workflows/pipeline.yml@main
    with:
      runner: self-hosted
    secrets: inherit
```

### Configuração

Crie `config.yml` na raiz do seu repositório:

```yaml
image: nome-da-imagem
```

Se `config.yml` não existir, usa o nome do próprio repositório.

### Pré-requisitos

- Dockerfile na raiz do repositório
- GitHub Actions habilitado
- ARC runner (self-hosted) ou `ubuntu-latest`
- Permissões: `contents: write`, `packages: write`, `id-token: write`

## Pipeline flow

```
push/PR → pipeline.yml
            │
            ├── release.yml  → v1.2.3
            │
            ├── buildx.yml   → ghcr.io/owner/image@sha256:abc...
            │
            ├─┬ trivy.yml    → SARIF → GitHub Security
            │ └ cosign.yml   → Signature → OCI referrers
            │
            └── push.yml     → ghcr.io/owner/image:latest
                              → ghcr.io/owner/image:v1.2.3
```

## Git Flow

### Branches

| Branch | Uso | Quem cria PR |
|---|---|---|
| `main` | Produção | `staging` ou `hotfix/*` |
| `staging` | Desenvolvimento contínuo | `feature/*` ou `bugfix/*` |
| `feature/*` | Nova funcionalidade | — |
| `hotfix/*` | Correção urgente em produção | — |

### Fluxo

```
feature/login → PR → staging
                        ↓
                  staging → PR → main (tag automática via release-please)
                        ↓
                  main → sync staging

hotfix/crash → PR → main (tag automática) → sync staging
```
feature/login → PR → develop
                        ↓
                  develop → PR → homolog (testes)
                                    ↓
                              homolog → PR → main (tag automática via release-please)
                                    ↓
                              main → sync develop, homolog
```

### Versionamento (SemVer + Release Please)

O versionamento é **automático** via `release-please` ao mergear para `main`:

- `MAJOR` — commit com `BREAKING CHANGE:` ou `!` no escopo
- `MINOR` — commit `feat:`
- `PATCH` — commit `fix:`

Release-please:
1. Escaneia commits desde o último tag
2. Calcula próxima versão (SemVer)
3. Abre/atualiza Release PR com changelog
4. Quando mergeado → cria GitHub Release + tag

### Conventional Commits

```
feat(auth): adiciona login com Google
fix(api): corrige timeout do gateway
docs(readme): atualiza documentação
refactor(user): simplifica validação
test(auth): adiciona testes de login
```

### Regras (via GitHub Actions)

Os workflows `branch-rules.yml` e `merge-check.yml` validam:

1. **Push direto** em `main`, `homolog`, `develop` → ❌ bloqueado
2. **Nome da branch** no PR → deve seguir o padrão (`feature/*` → `develop`, etc.)
3. **PR title** → deve seguir Conventional Commits
4. **Commits** → devem seguir Conventional Commits (ignora merges)
5. **PR template** → checklist obrigatório

Ative esses workflows adicionando no seu repositório:

```yaml
# .github/workflows/ci.yml
jobs:
  validate:
    uses: guilhermelinosp/ci-templates/.github/workflows/branch-rules.yml@main
    secrets: inherit
```
