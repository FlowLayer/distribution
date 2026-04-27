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

## Licensing

- `flowlayer-server` is distributed as proprietary software.
- `flowlayer-client-tui` is distributed from the public `FlowLayer/tui` project.
- This distribution repository (scripts, templates, and manifests) is licensed under Apache-2.0.
- Package manager metadata uses `Proprietary` because the installed `flowlayer` package includes the proprietary server binary.

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

Winget note: public v1.0.0 bundled Windows assets now exist on `FlowLayer/flowlayer` and the local Winget manifest targets those unified archives.
Submitting to `winget-pkgs` and real publication remains a separate step.

Generated Winget multi-file manifests are written under `winget/manifests/FlowLayer.FlowLayer/1.0.0/`.

## Winget Local Bundle Preparation

Public assets are available in `https://github.com/FlowLayer/flowlayer/releases/tag/v1.0.0`:
- `flowlayer-1.0.0-windows-amd64.zip`
- `flowlayer-1.0.0-windows-arm64.zip`

Run `scripts/build-winget-bundles.sh` to rebuild equivalent local bundles for validation. These generated bundles are local artifacts only and are not committed to Git.

Validate on Windows with:

```powershell
winget validate .\winget\manifests\FlowLayer.FlowLayer\1.0.0
```

Submission to `winget-pkgs` and real publication remain separate operational steps.

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

Current assumption: server and TUI releases share the same version tag.

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
