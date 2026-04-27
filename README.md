# FlowLayer Distribution

This repository contains the distribution and packaging layer for FlowLayer.
It is dedicated to package manager manifests, install scripts, and release-sync templates.

It does not contain the application source code.

## Package Scope

- Public package name: `flowlayer`
- Installed binaries:
  - `flowlayer-server`
  - `flowlayer-client-tui`
- Current artifact sources (v1.0.0):
  - Server release: `FlowLayer/flowlayer`
  - TUI release: `FlowLayer/tui`

FlowLayer binaries are native Go executables and do not require an additional runtime dependency to run.

The current distribution state intentionally aggregates two independent release sources. A future single `flowlayer` bundle (containing both binaries per OS/arch) remains possible and would simplify some package managers.

## Distribution Strategy

Phase 1:
- Homebrew
- Winget
- Linux/macOS install script (`install.sh`)

Phase 2:
- Scoop
- Chocolatey

Phase 3 (future work):
- `.deb` and `.rpm` packages (documented roadmap only at this stage)

## Target Installation Commands

These are target commands and may not work end-to-end until public packages are published with real artifact URLs and checksums.

Winget note: with today’s split Windows assets (server and TUI published as separate archives), `FlowLayer.FlowLayer` is kept as a draft manifest and is not considered cleanly publishable until a single Windows bundle exists for each architecture.

Windows (Winget):

```sh
winget install FlowLayer.FlowLayer
```

macOS (Homebrew tap):

```sh
brew tap FlowLayer/distribution https://github.com/FlowLayer/distribution
brew install flowlayer
```

Linux quick install:

```sh
curl -fsSL https://flowlayer.tech/install.sh | sh
```

Linux inspectable alternative:

```sh
curl -fsSL https://flowlayer.tech/install.sh -o install.sh
sh install.sh
```

Scoop (future):

```powershell
scoop bucket add flowlayer https://github.com/FlowLayer/distribution
scoop install flowlayer
```

Chocolatey (future):

```powershell
choco install flowlayer
```

Homebrew on Linux can also be supported through the same formula strategy, provided Linux artifacts are published consistently.

## Security and Install Script Note

Using `curl | sh` is practical for onboarding and upgrades, but inspectable download-first usage is supported and recommended for users who want to review the script before execution.

## Target Release Pipeline

1. Create tag `vX.Y.Z` in the main FlowLayer repository.
2. Build multi-OS and multi-architecture artifacts.
3. Generate `SHA256SUMS`.
4. Publish a GitHub Release.
5. Synchronize manifests in this repository.
6. Generate an automated PR.
7. Review.
8. Merge.
9. Publish through each package manager according to ecosystem rules.

Updates should ideally go through automated pull requests, not direct pushes.

## Repository Layout

- `homebrew/`: Homebrew formula(s)
- `winget/`: Winget manifests
- `scoop/`: Scoop bucket manifest(s)
- `chocolatey/`: Chocolatey package metadata and installer script
- `templates/`: tokenized templates used by sync scripts
- `scripts/`: generation and synchronization scripts
- `install.sh`: Linux/macOS installer bootstrap script

## Future Work

- Native `.deb` and `.rpm` packaging pipelines
- Advanced notarization/signing workflows
- Potential Microsoft Store distribution path
- Optional package split strategy (`flowlayer-server` / `flowlayer-client-tui`) if ecosystem constraints require it
- Optional single-bundle `flowlayer` artifact per OS/arch to simplify Winget publication
