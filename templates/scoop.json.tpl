{
  "version": "{{VERSION}}",
  "description": "FlowLayer local process orchestration for development workflows",
  "homepage": "https://flowlayer.tech",
  "license": "Proprietary",
  "architecture": {
    "64bit": {
      "url": [
        "{{SERVER_WINDOWS_AMD64_URL}}",
        "{{TUI_WINDOWS_AMD64_URL}}"
      ],
      "hash": [
        "{{SERVER_WINDOWS_AMD64_SHA256}}",
        "{{TUI_WINDOWS_AMD64_SHA256}}"
      ]
    },
    "arm64": {
      "url": [
        "{{SERVER_WINDOWS_ARM64_URL}}",
        "{{TUI_WINDOWS_ARM64_URL}}"
      ],
      "hash": [
        "{{SERVER_WINDOWS_ARM64_SHA256}}",
        "{{TUI_WINDOWS_ARM64_SHA256}}"
      ]
    }
  },
  "pre_install": [
    "$serverExe = Get-ChildItem -Path $dir -Recurse -Filter 'flowlayer-server.exe' | Select-Object -First 1",
    "if (-not $serverExe) { throw 'flowlayer-server.exe not found after extraction' }",
    "Copy-Item -Path $serverExe.FullName -Destination (Join-Path $dir 'flowlayer-server.exe') -Force",
    "$tuiExe = Get-ChildItem -Path $dir -Recurse -Filter 'flowlayer-client-tui.exe' | Select-Object -First 1",
    "if (-not $tuiExe) { throw 'flowlayer-client-tui.exe not found after extraction' }",
    "Copy-Item -Path $tuiExe.FullName -Destination (Join-Path $dir 'flowlayer-client-tui.exe') -Force"
  ],
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
        "url": [
          "https://github.com/FlowLayer/flowlayer/releases/download/v$version/flowlayer-server-$version-windows-amd64.zip",
          "https://github.com/FlowLayer/tui/releases/download/v$version/flowlayer-client-tui-$version-windows-amd64.zip"
        ]
      },
      "arm64": {
        "url": [
          "https://github.com/FlowLayer/flowlayer/releases/download/v$version/flowlayer-server-$version-windows-arm64.zip",
          "https://github.com/FlowLayer/tui/releases/download/v$version/flowlayer-client-tui-$version-windows-arm64.zip"
        ]
      }
    }
  },
  "notes": [
    "Generated for release tag {{RELEASE_TAG}}.",
    "Dual-source package: server from FlowLayer/flowlayer and TUI from FlowLayer/tui."
  ]
}
