# FlowLayer Distribution

This repository contains FlowLayer distribution tooling and package manager recipes.

It is a technical repository for distribution scripts, package recipes, and release-sync templates. It does not contain application source code.

For user-facing installation instructions, see https://github.com/FlowLayer/flowlayer or https://flowlayer.tech.

Assets are published from the global FlowLayer release:
https://github.com/FlowLayer/flowlayer/releases

The global release includes:
- `flowlayer-server`
- `flowlayer-client-tui`
- global Windows bundles
- `SHA256SUMS`

Official documentation entry point: https://flowlayer.tech

## Installation Status

- `install.sh` public installer: validated
- Homebrew public tap: validated
- Scoop public bucket: validated
- Chocolatey package has been submitted and is pending Chocolatey Community moderation
- Winget manifests are tracked here and valid, but local install testing currently fails with a Winget internal error in the test environment

## Maintainer Reference: Stable Installation Methods

These commands are kept here for packaging and validation workflows. The main user entry point is https://github.com/FlowLayer/flowlayer.

Linux/macOS (`install.sh`):

```sh
curl -fsSL https://raw.githubusercontent.com/FlowLayer/distribution/main/install.sh | sh
```

Homebrew:

```sh
brew tap FlowLayer/distribution https://github.com/FlowLayer/distribution.git
brew install flowlayer
```

Scoop:

```powershell
scoop bucket add flowlayer https://github.com/FlowLayer/distribution.git
scoop install flowlayer
```

## Pending / Not Yet Stable

- Chocolatey package has been submitted and is pending Chocolatey Community moderation.
- Winget manifests are tracked here, but local install testing currently fails with a Winget internal error.

## Checksum Verification

Download assets and `SHA256SUMS` from:
https://github.com/FlowLayer/flowlayer/releases

Verify with:

```sh
sha256sum -c SHA256SUMS
```

GPG verification is not published as an active distribution method at this stage.

## Related Repositories

- FlowLayer release hub: https://github.com/FlowLayer/flowlayer
- TUI source repository: https://github.com/FlowLayer/tui
- Distribution repository: https://github.com/FlowLayer/distribution
