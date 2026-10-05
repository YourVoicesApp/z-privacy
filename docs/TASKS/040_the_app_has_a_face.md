# 040 · The app has a face, and Linux ships from a script

**Status: ORDERED** · 5 Oct 2026 · lead → `mono-privacy-88` · branch `ship/the-app-has-a-face` from `main` (`57ed3cd`) · **no change to the core, the scanner, the gateway or any gate's subject.**

## The owner's words (5 Oct)

«سأقوم بتنظيف الجهاز من جميع ما تم تنزيله سابقاً من Z-privacy وسنضيف صورة جميلة لتكون شعار التطبيق، ثم أقوم بعد أن تخبرني بتثبيت التطبيق من الويب وأرى كيف تسير جميع الأمور.»

The image: `~/Pictures/Pasted image (3).png`, 1008 × 1792, RGB — a lighthouse in a ring on a dark blue night, a crescent on the lantern. The owner's own picture, made for this product; no third-party licence applies. **The mark is the ring and what is inside it**; the dark field around it is the page, not the logo.

## Measured state (`57ed3cd`)

- **Linux**: `linux/runner/my_application.cc` sets no window icon; there is no `.desktop` file; the window shows GTK's default.
- **Windows**: `windows/runner/resources/app_icon.ico` is Flutter's template icon; `packaging/windows/zprivacy.iss` already takes `IconFile` (`SetupIconFile`, `UninstallDisplayIcon`), so the installer is one file away.
- **Site**: `site/{en,de,ar}/index.html` carry no logo and no favicon line (measure; `site/assets/` exists).
- **The Linux tarball** on beta (`zprivacy-v1-linux-x86_64.tar.gz`, 30 Sep, sha `d5c531a3…`) was assembled **by hand** in `~/zprivacy-release/`: top folder `zprivacy-v1-linux-x86_64/` with `zprivacy` (the runner), `lib/`, `data/`, `BUILD-INFO.txt` (product commit + its title + a note on the tree), `README.txt` («To run it: ./zprivacy … needs GTK3»), `LICENSE`, `third-party/{NOTICES.txt, flutter-engine-LICENSE.txt, flutter-sdk-LICENSE.txt, material-icons-LICENSE.txt, rust-crates.txt}`. No script in the repository produces it, so it was never rebuilt after 30 Sep — the live download predates the PDF reader, the names, and all four phases.

## What to build

### A · One source, every size

1. `scripts/build_brand.py` (Pillow is on this machine; no new Rust or Dart dependency): reads **one** source file `brand/source.png` (the owner's image, committed once; ~1.7 MB is acceptable, say so in the commit), crops the square around the ring with a margin that keeps the ring's glow (measure the ring's bounds from the pixels, do not hard-code a guess without writing the measured numbers in the script), and writes:
   - `apps/flutter_app/assets/brand/zprivacy-1024.png` and `…-512/256/128/64/48/32/16.png` (square, dark field kept — the ring on transparent would lose the glow; the owner's image is night, so the icon is night);
   - `apps/flutter_app/windows/runner/resources/app_icon.ico` (256 · 48 · 32 · 16 inside one `.ico`);
   - `site/assets/favicon-32.png`, `favicon-16.png`, `apple-touch-icon.png` (180), `logo-512.png`.
   The script is **idempotent and checked by a gate**: run twice → the same bytes; the gate re-runs it into a temp dir and diffs against what is committed, so nobody edits an icon by hand.
2. **Linux window icon**: in `my_application.cc`, after the window is made, `gtk_window_set_icon` from the bundled PNGs (read from the app's own `data/flutter_assets/assets/brand/`, found relative to the executable — never a hard-coded home path); and `gtk_window_set_default_icon_name`/`icon_name` to `zprivacy` so a `.desktop` file can name it.
3. **`.desktop` and icon in the tarball**: `packaging/linux/zprivacy.desktop` (`Name=Z Privacy`, `Exec=` relative, `Icon=zprivacy`, `Categories=Office;Utility;`, `Terminal=false`) and an `install-shortcut.sh` that copies the `.desktop` to `~/.local/share/applications/` and the icons to `~/.local/share/icons/hicolor/<size>/apps/zprivacy.png` — optional for the person, said in the README. Nothing is written anywhere unless they run it.
4. **Windows**: the new `.ico` in place; `zprivacy.iss` unchanged (it already takes it). **Do not build Windows** (the owner's rule: Linux is the development platform; the Windows workflow is manual-only and runs when he says).
5. **Site**: `<link rel="icon">` ×2 and `apple-touch-icon` in the three pages' heads; the 512 logo at the top of the page beside the name, same size on the three; nothing else on the pages moves. `scripts/check_site.sh` learns the four asset files exist.
6. **In the app**: the 64 px mark in the first-run screen's corner and the window title stays «Z Privacy». No other screen changes.

### B · Linux ships from a script

7. `scripts/package_linux.sh`: from a **clean tree** (refuses if `git status --porcelain` is not empty, unless `ALLOW_DIRTY=1` is set and then says so in BUILD-INFO), runs `flutter build linux --release`, assembles exactly the 30 Sep layout (top folder, runner, `lib/`, `data/`, `BUILD-INFO.txt`, `README.txt`, `LICENSE`, `third-party/`), **adds** `zprivacy.desktop`, `install-shortcut.sh` and `icons/`, and writes `dist/zprivacy-v1-linux-x86_64.tar.gz` + `.sha256`. `BUILD-INFO.txt` carries the core's own stamp line (`z_core 0.1.0 · <date> · <sha>`) read by running the built `check_document` with no file, so the archive names the commit the same way the window does. `third-party/rust-crates.txt` is generated (`cargo metadata` or `cargo tree`, no new tool) rather than copied from the September file.
8. The script prints the sha256 and the stamp and nothing else of consequence; the lead runs it, uploads to beta (previous kept in `beta/previous/`), purges, and the page's sha line changes by the owner's hand or the lead's.

## Done means

- `python3 scripts/build_brand.py` twice → identical bytes; the gate for it passes; all sizes are square; the `.ico` opens (a Python check reads its directory and finds the four sizes).
- A debug run on this machine shows the lighthouse in the window's title bar/dock (the lead looks).
- `scripts/package_linux.sh` on a clean `main` produces the archive; extracted on a path with spaces, `./zprivacy` starts, the window has the icon, `install-shortcut.sh` puts a launcher in the menu, and uninstalling is deleting two folders (say so in README).
- `cargo test`, `flutter test` (the gates' way), gates, clippy: counts before/after; the gate count rises by the brand gate and the site check.
- Report: the measured crop box, the file sizes, the gate line, the archive's sha and stamp, and anything in the September layout you could not reproduce.

## Not in this task

- The Windows build itself.
- Any wording on the site beyond the two `<link>` lines and the logo.
- Code signing.
