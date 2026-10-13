# Bundle identity — comparison copy

Recorded before any cycle that talks to the desktop app. Results must not be
attributed to HEAD unless this file (or the run log) says the bundle was
rebuilt from that commit.

## Git

- repo: `/home/monopeaks/mono-privacy-comparison-20261013-022102`
- branch: `comparison/local-cycle`
- HEAD: `d882c5f20a04c240ad9bdbde8688cbed742e901e`
- HEAD date: 2026-10-12 20:23:50 +0200
- subject: Merge 071: one value names the open panel

## Found release bundle (as copied, not rebuilt)

Path: `apps/flutter_app/build/linux/x64/release/bundle/`

| file | mtime | sha256 |
|---|---|---|
| `zprivacy` | 2026-10-12 20:07:19 +0200 | `d7ffc0f4ab9e9e879dc2b72773bee229a18eb45b21ee1776e710f8d05db396ed` |
| `lib/libapp.so` | 2026-10-12 20:07:18 +0200 | `9c40dd4d7d64dca73efea3cd0cedf7aad3bc2fe7cab73f5209dfb04b09d3c0a1` |
| `lib/libz_bridge.so` | 2026-10-12 20:07:14 +0200 | `715616d4639a80386e80ac538591bed0132c4236d16cf58494796d62f930dbe6` |
| `lib/libflutter_linux_gtk.so` | 2026-10-12 20:07:18 +0200 | `f3378ddd4e27b95476de9ad9124e9ebc882b95d9be379a8196a71218ba59c8f2` |

ELF BuildID of `zprivacy`: `22f66600276644af3393cb7371017aaf9050ab03`

This `libapp.so` is byte-identical to the original tree's bundle at
`~/mono-privacy/apps/flutter_app/build/linux/x64/release/bundle/lib/libapp.so`.

## Verdict on the found bundle

**It is not proven to be HEAD.** Two commits landed after the bundle mtime:

- `4dcb8bf` 20:23 — One value names the open panel · 071 (Dart: session_state, workspace, acts)
- `d882c5f` 20:23 — merge of that work

`4087de4` (19:59) only added a Dart test, so it does not change the binary.
Rust (`libz_bridge.so`) was not touched by those two commits; the Dart UI was.

A cycle run against this found bundle must be labelled **bundle 20:07**, not
HEAD `d882c5f`. To test HEAD, rebuild in this copy:

```bash
cd apps/flutter_app && flutter build linux --release
```

Do not build in `~/mono-privacy`. After a rebuild, hash the new `libapp.so` and
`libz_bridge.so` and keep them in `tests/cycle/output/` (gitignored).
