# Third-party notices

## Cua Driver

- Project: Cua
- Source: <https://github.com/trycua/cua>
- Pinned Driver version: 0.30.4 (`cua-driver-rs-v0.30.4`)
- Pinned source commit: `bf6c76786d938070f4ecf1e44004752f69f518b8`
- License: MIT
- Copyright: Cua contributors

This repository does not vendor a Cua Driver binary. The component build may download and redistribute only
the exact Windows x64 release recorded in `upstream/cua-driver-0.30.4-windows-x64.lock.json`, after verifying
the archive and every extracted file. The upstream MIT license is preserved at
`licenses/CUA_DRIVER_LICENSE.md` and must be included in the component package.

The optional `cua-perception` extension is explicitly outside this project because its licensing and
model-artifact obligations differ from the MIT-licensed base Driver. FFmpeg, model files, installer scripts,
Agent Skills and application workflows are also excluded.

The macOS variant separately pins Cua Driver 0.32.0 at commit
`66ca6c0833a7e04dd611c473100ba36bbf1f11be` and redistributes the verified universal
`CuaDriver.app` so its official signing identity and macOS permission attribution are preserved. Exact source,
size and SHA-256 are recorded in `upstream/cua-driver-0.32.0-macos-universal.lock.json`.
