# CI Templates

Templates reutilizáveis de CI/CD para GitHub Actions.

## Git Flow

```
feature/* → PR → main → PR → main → release automática 🏷️
hotfix/*  → PR → main → release automática → sync main
```

| Branch | Uso | Quem cria PR |
|---|---|---|
| `main` | Produção | `main` ou `hotfix/*` |
| `main` | Desenvolvimento | `feature/*` |
| `feature/*` | Nova funcionalidade | — |
| `hotfix/*` | Correção urgente | — |

## Versionamento (SemVer + Conventional Commits)

| Commit | Bump |
|---|---|
| `fix:` | PATCH (v1.0.0 → v1.0.1) |
| `feat:` | MINOR (v1.0.0 → v1.1.0) |
| `BREAKING CHANGE` ou `!:` | MAJOR (v1.0.0 → v2.0.0) |

## Workflows

| Workflow | Descrição |
|---|---|
| `release.yml` | SemVer bump + GitHub Release + tag |
| `buildx.yml` | Build Docker multi-arch com SBOM + provenance |
| `push.yml` | Promote imagem para latest + SHA + versão |
| `trivy.yml` | Scan vulnerabilidades (SARIF) |
| `cosign.yml` | Assinatura keyless (sigstore) |
| `branch-rules.yml` | Valida branches feat/* + PR title |
| `merge-check.yml` | Valida commits (Conventional Commits) |
| `ci.yml` | Auto-validação do próprio ci-templates |

## Pipeline completa (exemplo)

```yaml
# .github/workflows/pipeline.yml
name: pipeline

on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches: [main, main]
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: write
  packages: write
  id-token: write

jobs:
  validate:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - run: |
          H="${{ github.head_ref }}"; B="${{ github.base_ref }}"
          echo "PR: $H → $B"
          [ "$H" = "main" ] && [ "$B" = "main" ] && echo "✅ main→main" && exit 0
          case "$H" in feat/*) echo "✅ $H" ;; *) echo "❌ Use feat/*"; exit 1 ;; esac
          echo "${{ github.event.pull_request.title }}" | grep -qE '^(feat|fix|docs|style|ref|refactor|test|chore|ci|perf|build|revert)(\(.+\))?!?:\s.+' && echo "✅ title" || { echo "❌ CC"; exit 1; }

  buildx:
    runs-on: ubuntu-latest
    outputs:
      image: ${{ steps.export.outputs.image }}
    steps:
      - uses: actions/checkout@v6
      - name: Login GHCR
        run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
      - name: Setup buildx
        run: docker buildx create --name ci-builder --driver docker-container --use 2>/dev/null || docker buildx use ci-builder
      - name: Build and push
        run: |
          docker buildx build --platform linux/amd64 --push --attest type=sbom --attest type=provenance,mode=max \
            -t "ghcr.io/${{ github.repository_owner }}/${{ github.event.repository.name }}:latest" .
      - name: Export digest
        id: export
        run: |
          DIGEST=$(docker buildx imagetools inspect "ghcr.io/${{ github.repository_owner }}/${{ github.event.repository.name }}:latest" --format '{{json .Manifest.Digest}}' | tr -d '"')
          echo "image=ghcr.io/${{ github.repository_owner }}/${{ github.event.repository.name }}@${DIGEST}" >> $GITHUB_OUTPUT

  trivy:
    needs: buildx
    runs-on: ubuntu-latest
    steps:
      - name: Scan
        env:
          TRIVY_USERNAME: ${{ github.actor }}
          TRIVY_PASSWORD: ${{ secrets.GITHUB_TOKEN }}
        run: |
          trivy image --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --format sarif --output trivy.sarif --no-progress "${{ needs.buildx.outputs.image }}" || true

  release:
    needs: [buildx, trivy]
    if: github.ref == 'refs/heads/main' || (github.base_ref == 'main' && github.head_ref == 'main')
    runs-on: ubuntu-latest
    outputs:
      tag: ${{ steps.semver.outputs.tag }}
    steps:
      - uses: actions/checkout@v6
        with: { fetch-depth: 0, token: "${{ github.token }}" }
      - name: Bump version
        id: semver
        env: { GH_TOKEN: "${{ github.token }}" }
        run: |
          HEAD=$(git rev-parse HEAD)
          if git tag --points-at "$HEAD" 2>/dev/null | grep -q .; then
            echo "Commit já tem tag, pulando"
            echo "tag=$(git tag --points-at "$HEAD" | head -1)" >> $GITHUB_OUTPUT
            exit 0
          fi
          L=$(gh release list --repo "${{ github.repository }}" --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null || echo "")
          [ -z "$L" ] && echo "tag=v1.0.1" >> $GITHUB_OUTPUT && exit 0
          IFS='.' read -r M m p <<< "${L#v}"; M=${M:-1}; m=${m:-0}; p=${p:-0}
          git log --format="%s" "$L..HEAD" 2>/dev/null | grep -q "BREAKING CHANGE\|!:" && { M=$((M+1)); m=0; p=0; } \
            || git log --format="%s" "$L..HEAD" 2>/dev/null | grep -q "^feat" && { m=$((m+1)); p=0; } \
            || p=$((p+1))
          echo "tag=v${M}.${m}.${p}" >> $GITHUB_OUTPUT
      - name: Create release
        if: steps.semver.outputs.tag != ''
        env: { GH_TOKEN: "${{ github.token }}" }
        run: |
          gh release create "${{ steps.semver.outputs.tag }}" --repo "${{ github.repository }}" --title "${{ steps.semver.outputs.tag }}" --generate-notes

  push:
    needs: [buildx, release]
    if: github.event_name == 'push' || (github.base_ref == 'main' && github.head_ref == 'main')
    runs-on: ubuntu-latest
    steps:
      - name: Login GHCR
        run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
      - name: Promote tags
        run: |
          SRC="${{ needs.buildx.outputs.image }}"
          DST="ghcr.io/${{ github.repository }}"
          docker buildx imagetools create --tag "$DST:latest" --tag "$DST:${GITHUB_SHA::7}" "$SRC"
          TAG="${{ needs.release.outputs.tag }}"
          if [ -n "$TAG" ]; then
            docker buildx imagetools create --tag "$DST:$TAG" "$SRC"
          fi
```

## ADRs

| Documento | Link |
|---|---|
| ADR-001: Alloy OTLP Gateway | https://gist.github.com/guilhermelinosp/09b474deeceaab3984225a22bf657347 |
| ADR-002: ARC + Runners | https://gist.github.com/guilhermelinosp/ec92d1edcfcccaf4fb87ca6ea46e01ba |
| ADR-003: Git Flow | https://gist.github.com/guilhermelinosp/b32f0681a03eb0fefe5f6a237b0c4ee5 |
