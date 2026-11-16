{{flutter_js}}
{{flutter_build_config}}

// Z's web trial (paper 122).
//
// * **No service worker** is registered: no `serviceWorkerSettings` here,
//   so rule 85 (c) holds — leaving the page keeps nothing. Flutter's default
//   bootstrap registers `flutter_service_worker.js`, which would cache the
//   site in the visitor's browser.
// * **No font from anywhere but our origin.** The engine asks for Roboto (and
//   for a fallback font on a missing glyph) under `fontFallbackBaseUrl`, which
//   is `https://fonts.gstatic.com/` unless it is said; said here as our own
//   folder, the ask stays at home. The trial's text is DejaVu Sans, bundled,
//   so nothing is missing for it to fall back for.
// * **CanvasKit at one absolute address, `/try/canvaskit/`** (paper 124): the
//   same for every language and for Scribe's editor (`/<lang>/try/scribe/`),
//   which loads it from there too, so the browser fetches it once. The server
//   serves the build's `canvaskit/` there (`_trial.nginx`, and the preview).
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "/try/canvaskit/",
    fontFallbackBaseUrl: "fonts/",
  },
});
