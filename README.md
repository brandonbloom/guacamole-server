# guacamole-server for Arr

**This is a fork of [apache/guacamole-server](https://github.com/apache/guacamole-server)
for [Arr](https://github.com/brandonbloom/arr)'s media host,** which runs
guacd natively on macOS. The `arr` branch is Apache Guacamole 1.6.0 plus the
changes below, each on its own branch based on the `1.6.0` tag, and is what
the [releases](https://github.com/brandonbloom/guacamole-server/releases) are
built from. The upstream README is in [README](README).

| Branch | Change | Upstream status |
|--------|--------|-----------------|
| [`vnc-size-before-connect`](https://github.com/brandonbloom/guacamole-server/tree/vnc-size-before-connect) | Do not crash when the client resizes while the VNC connection is still being established, such as during a password prompt; includes a repro | Not submitted. Matches [GUACAMOLE-2148](https://issues.apache.org/jira/browse/GUACAMOLE-2148); [apache/guacamole-server#706](https://github.com/apache/guacamole-server/pull/706) proposes a similar guard |
| [`macos-build`](https://github.com/brandonbloom/guacamole-server/tree/macos-build) | Build and run guacd with VNC on macOS against Homebrew libraries | Not submitted |
| [`macos-release`](https://github.com/brandonbloom/guacamole-server/tree/macos-release) | Workflow publishing a relocatable `guacd-<tag>-macos-arm64.tar.gz` (VNC only) for each tag | Fork-specific |

Install a release with [mise](https://mise.jdx.dev):

```sh
mise use github:brandonbloom/guacamole-server@<tag>
```
