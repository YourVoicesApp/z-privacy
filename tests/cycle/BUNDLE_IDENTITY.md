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

## Rebuilt bundle (this copy, 2026-10-13 02:39)

Rebuilt **in this copy only** after deleting this copy's stale
`CMakeCache.txt` / `CMakeFiles` (they still named
`/home/monopeaks/mono-privacy/apps/flutter_app/build/linux/x64/release`).
Origin hashes were not rewritten.

Path: `apps/flutter_app/build/linux/x64/release/bundle/`

| file | mtime | sha256 |
|---|---|---|
| `zprivacy` | 2026-10-13 02:39:49 +0200 | `a9b9f4e310579273c10bd339be60e5307e0507eb0cee7591b650eaef85f1dafc` |
| `lib/libapp.so` | 2026-10-13 02:39:48 +0200 | `af8a24140e2c0fdc437ab698d3f86fb20bb2b2d12f9113d0325690966d50c58c` |
| `lib/libz_bridge.so` | 2026-10-13 02:39:39 +0200 | `ac68ca84db24e8717dbb489ea9a6e31e58f79ee258eea94778f7f91b1aee3eb2` |

ELF BuildID of `zprivacy`: `556568796a5e6434fd910d27b00c7570be76036f`

Running isolated pid's `/proc/<pid>/exe` matches this `zprivacy` hash.
Log line: `bridge ok — z_core 0.1.0 · 2026-10-13 · 61fa27b`.

### What that stamp means

- Product source in the binary is **d882c5f** (Dart 071 + merge). `libapp.so`
  differs from origin's 20:07 hash `9c40dd4d…` because those two commits
  landed after the found bundle.
- The z_core stamp is **61fa27b** (the tools commit on this branch at rebuild
  time). `tests/cycle/` is not compiled into the app; the stamp is git HEAD
  when `build.rs` ran.
- Branch HEAD after the isolation_check commit is **40b08ce**. That commit
  does not change Dart or Rust, so the running binary still matches the
  rebuild. A later tools-only commit must not be described as a new app
  build unless `libapp.so` / `libz_bridge.so` are hashed again.

A UI cycle against this process may be attributed to **product d882c5f,
bundle rebuilt 2026-10-13 02:39, stamp 61fa27b**. It must not be attributed
to the 20:07 origin bundle.
