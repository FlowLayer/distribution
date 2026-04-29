# FlowLayer Distribution

**Where every supported install path of FlowLayer lives — recipes, manifests, and the one-liner that gets you running.**

[![install.sh](https://img.shields.io/badge/install.sh-ready-4d8eff?style=flat-square)](install.sh)
[![Homebrew](https://img.shields.io/badge/Homebrew-tap%20ready-4d8eff?style=flat-square)](#homebrew)
[![Scoop](https://img.shields.io/badge/Scoop-bucket%20ready-4d8eff?style=flat-square)](#scoop-windows)
[![Chocolatey](https://img.shields.io/badge/Chocolatey-pending%20moderation-orange?style=flat-square)](#chocolatey-pending)
[![Winget](https://img.shields.io/badge/Winget-partial-orange?style=flat-square)](#winget-partial)

[Website](https://flowlayer.tech/) · [Main repo](https://github.com/FlowLayer/flowlayer) · [Releases](https://github.com/FlowLayer/flowlayer/releases) · [TUI source](https://github.com/FlowLayer/tui)

---

This repository is the **packaging surface** of FlowLayer. It does not contain application source code — it contains the scripts, formula templates, and manifests that turn a tagged release of `flowlayer-server` and `flowlayer-client-tui` into something users can install on every major OS.

If you just want to **install FlowLayer**, you are in the right place. Pick your platform below.

If you are looking for the engine, the protocol, or the TUI source, see:

- [FlowLayer/flowlayer](https://github.com/FlowLayer/flowlayer) — release hub, protocol, config reference
- [FlowLayer/tui](https://github.com/FlowLayer/tui) — official terminal client source
- [flowlayer.tech](https://flowlayer.tech/) — full documentation

---

## Install

### Linux & macOS

One curl, one shell — the canonical fast path:

```sh
curl -fsSL https://raw.githubusercontent.com/FlowLayer/distribution/main/install.sh | sh
```

The installer detects your OS and architecture, downloads the matching binaries from the global FlowLayer release, verifies SHA-256 checksums, and drops `flowlayer-server` + `flowlayer-client-tui` into your `PATH`.

### Homebrew

```sh
brew tap FlowLayer/distribution https://github.com/FlowLayer/distribution.git
brew install flowlayer
```

### Scoop (Windows)

```powershell
scoop bucket add flowlayer https://github.com/FlowLayer/distribution.git
scoop install flowlayer
```

### Chocolatey (pending)

The Chocolatey package is **submitted and in Community moderation**. Once approved it will install with:

```powershell
choco install flowlayer
```

### Winget (partial)

Manifests are tracked in [`winget/manifests/FlowLayer.FlowLayer/`](winget/manifests/FlowLayer.FlowLayer) and pass `winget validate`. **End-to-end local install verified**: `winget install --manifest <path>` registers FlowLayer under ARP and exposes both `flowlayer-server` and `flowlayer-client-tui` aliases via the dual-binary nested portable. Public submission to [`microsoft/winget-pkgs`](https://github.com/microsoft/winget-pkgs) is the only remaining follow-up before promoting this channel to *validated*.

> Note: when invoking `winget install --manifest <path>` against a freshly downloaded archive, SmartScreen / `IAttachmentExecute` may silently hang on unsigned binaries (Mark-of-the-Web). The published flow via `microsoft/winget-pkgs` is unaffected; signing the Windows binaries (Authenticode) is tracked as a separate follow-up.

---

## Verify what you downloaded

Every release ships a `SHA256SUMS` file alongside the binaries. Verify before you run:

```sh
sha256sum -c SHA256SUMS
```

GPG-signed releases are not part of the distribution surface yet.

---

## Repository layout

```text
distribution/
├── install.sh              # canonical Linux/macOS one-liner
├── Formula/                # Homebrew formula (legacy path)
├── homebrew/Formula/       # Homebrew tap formula (current)
├── scoop/bucket/           # Scoop bucket manifest
├── chocolatey/flowlayer/   # Chocolatey nuspec + tools
├── winget/manifests/       # Winget multi-file manifests
├── templates/              # Source templates rendered at release-sync
└── scripts/                # Release-sync, validation, and bundle builders
```

The recipes are **generated**, not hand-edited — every release the `scripts/release-sync.sh` pipeline rerenders the formulas, manifests, and Scoop JSON from `templates/` against the new version and freshly computed SHA-256 sums. That means every channel is **always in lockstep** with the release tag — no stale checksums, no version drift.

Key scripts:

| Script | Purpose |
|---|---|
| [`scripts/release-sync.sh`](scripts/release-sync.sh) | Master pipeline: pull release, recompute hashes, rerender every recipe |
| [`scripts/build-winget-bundles.sh`](scripts/build-winget-bundles.sh) | Build the Windows installer bundles consumed by Winget manifests |
| [`scripts/test-release-sync.sh`](scripts/test-release-sync.sh) | Local dry-run validation of the full pipeline |
| [`scripts/update-{homebrew,scoop,chocolatey,winget}.sh`](scripts) | Per-channel update entry points |

---

## Channel status

| Channel | Status | Notes |
|---|---|---|
| `install.sh` | ✓ Stable | OS + arch detection, checksum verification, idempotent |
| Homebrew tap | ✓ Stable | Public tap, formula auto-synced per release |
| Scoop bucket | ✓ Stable | Public bucket, manifest auto-synced per release |
| Chocolatey | ⏳ In moderation | Package submitted, awaiting Community approval |
| Winget | ⚠︎ Partial | Manifest valid; dual-binary local install verified end-to-end; pending submission to `microsoft/winget-pkgs` |

---

## Related repositories

- **FlowLayer release hub** — <https://github.com/FlowLayer/flowlayer>
- **TUI source** — <https://github.com/FlowLayer/tui>
- **This repo (distribution recipes)** — <https://github.com/FlowLayer/distribution>

---

## License

See [LICENSE](LICENSE).
