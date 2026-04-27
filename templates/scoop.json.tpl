{
  "version": "{{VERSION}}",
  "description": "FlowLayer local process orchestration for development workflows",
  "homepage": "https://flowlayer.tech",
  "license": "TODO-VERIFY-LICENSE",
  "architecture": {
    "64bit": {
      "url": "{{WINDOWS_AMD64_URL}}",
      "hash": "{{WINDOWS_AMD64_SHA256}}"
    },
    "arm64": {
      "url": "{{WINDOWS_ARM64_URL}}",
      "hash": "{{WINDOWS_ARM64_SHA256}}"
    }
  },
  "bin": [
    "flowlayer-server.exe",
    "flowlayer-client-tui.exe"
  ],
  "checkver": {
    "github": "https://github.com/FlowLayer/flowlayer"
  },
  "autoupdate": {
    "architecture": {
      "64bit": {
        "url": "https://github.com/FlowLayer/flowlayer/releases/download/v$version/flowlayer_windows_amd64.zip"
      },
      "arm64": {
        "url": "https://github.com/FlowLayer/flowlayer/releases/download/v$version/flowlayer_windows_arm64.zip"
      }
    }
  },
  "notes": [
    "Generated for release tag {{RELEASE_TAG}}.",
    "Replace placeholder checksums before publication."
  ]
}
