# QSeq → Jaspr migration

Status as of 2026-06-12 (branch `jaspr-migration`): **CUT OVER** — `qseq.app`
now serves the Jaspr build (`site/build/jaspr`, deployed via `vercel --prod`).
The old static `website/` is retired from production but kept in the repo for
reference. The notarized, universal macOS download lives at `site/web/QSeq.dmg`
(tracked alongside `site/web/qseq-windows-setup.exe`), so `/QSeq.dmg` resolves on
qseq.app and is reproduced by `jaspr build`.

## Why

The old web app (`website/app.js`, 789 lines) **reimplemented** the GS1/SGTIN/NSN
encoders and the QR/DataMatrix/linear capacity tables in JavaScript — a second
source of truth that can drift from the Dart `lib/` used by the desktop app.
Jaspr (Dart → web, SSR/SSG) lets the web reuse the Dart core and the same
`barcode` package the desktop uses.

## Architecture

```
packages/qseq_core/     NEW pure-Dart package (no Flutter): encoders + sizing
                        engine + models. Single source of truth.
site/                   NEW Jaspr static app (the web frontend)
  lib/main.server.dart  Document: SEO head (title/desc/OG/canonical/GA/favicon)
                        + <link styles.css>; server prerender entry
  lib/main.client.dart  client hydration entry (generated options)
  lib/app.dart          page shell — raw() marketing HTML + <Generator>
  lib/components/generator.dart   @client interactive generator (hydrates AND
                        prerenders, so index.html ships a real symbol)
  lib/qseq/generate.dart          pure bridge: DataSourceInput.resolve() +
                        Sizer.compute() + barcode.toSvg()
  lib/qseq/download*.dart          client-only blob download (conditional import:
                        stub on server, package:web on JS)
  web/styles.css        copied from website/styles.css (visual parity)
website/                OLD static site — STILL LIVE on qseq.app until cutover
```

The desktop Flutter app (`lib/`, `pubspec.yaml`) is **untouched**. De-duplicating
it onto `qseq_core` (replace `lib/encoders|sizing|models` with re-export shims and
verify `flutter build`) is a later step — do it with the desktop build watched.

## Done

- `qseq_core` extracted, analyzes clean, passes runtime smoke tests as pure Dart.
- Jaspr static app scaffolded and **builds** (`jaspr build` → `site/build/jaspr/`).
- Single-code generator at parity: SGTIN (Digital Link / element / EPC) + NSN +
  free text; QR/DataMatrix (+EC) and GS1-128/Code128/Code39/EAN-13/UPC-A; DPI +
  X-dimension; live print-true size readout — all from `qseq_core`.
- Symbol renders via the `barcode` package as inline SVG, **server-prerendered**
  (great for SEO + first paint) and hydrated for interactivity.
- SVG **and PNG** export (PNG rasterizes the SVG to a print-true canvas, client-only).
- **Serialized sheets** — 4-option workspace (2D/1D × single/serial) + prefix/start/
  count/zero-pad; `buildSheet` tiles per-serial barcode SVGs into one composed SVG;
  preview shows first 48, SVG/PNG export the full run (≤2000).
- mission/about/support sections + copy-button; Windows installer asset.
- SEO head ported (title, description, OG, canonical, GA, favicon) + dark theme.

## Done (full parity push, overnight 2026-06-11→12)

- **All 8 workspaces** incl. Combined 1D+2D (stacked/side-by-side, gap, padding)
  and the **Label designer** (single + serialized): drag/resize with snapping,
  element toggles, title, ONE shared HRI, dashed cut-frame (show/print),
  background import + at-scale template export (offline round-trip).
- **Logo dead-space** (auto 15% EC share, module-snapped knockout, logo image,
  budget readout) · **page formats/orientation/columns + pagination + tabs** ·
  **bold-counter captions** · **mm/inch/vernier rulers** · **serialization log**
  · **.qseq project save/load** · **PDF via the page's jsPDF** (single + sheets).
- Engine is mm-true SVG in `site/lib/qseq/` (svgkit/generate/label/project);
  VM smoke test `site/tool/smoke.dart` covers every mode — run
  `dart run tool/smoke.dart` from `site/`.

## Done (live click-through fixes + workspace restructure, 2026-06-12)

- **Numeric-input bug fixed**: Jaspr dispatches `num` (not String) to `onInput`
  for `type=number` inputs — the String-typed handlers threw on every keystroke
  in release JS, so no numeric field (Count, DPI, X-dim…) could be edited.
  `_num` now takes `num`, live-updates only changed in-range values (mid-typing
  state echo used to clamp half-typed numbers, e.g. "600" → 36 → 3600 → 1200),
  and clamps on blur/Enter. Ranges (`min`/`max`) live in the `_num` call sites.
- **Workspace restructure**: new `twoDSheet`/`oneDSheet` "Sheet of copies"
  workspaces (N identical codes tiled per page — `SerialSpec(serialize: false)`
  yields null serials so every cell encodes the single-mode payload). The
  **label designer is now an overlay checkbox** available in every workspace
  (single → one label, paged → label sheet), not a workspace; the overlay shows
  exactly the workspace's symbols (2D/1D/both). Legacy `.qseq` files with
  `label`/`labelSerial` modes load as combo (+Serialized) with the overlay on.
- **Label HRI font size** (`LabelSpec.hriFontMm`, 0 = auto) — resizes the
  Digital Link printout; persisted in `.qseq` and the label JSON.
- **Browser-level UI test harness**: `.scratch/uitest/verify.js`
  (puppeteer-core + system Edge) drives the hydrated app — workspaces,
  resolver, numeric typing, overlay, HRI font — `node verify.js <url>`.
- Mystery "lost tapdpp resolver" solved: the preview alias had pointed at a
  4-day-old deployment; the resolver was fine in current code.

## Remaining (in rough priority)

1. `/QSeq.dmg` into `site/web/` — **the macOS download is a 404 in production**
   (it was already broken before the cutover: the dmg is not in git and was
   missing from the previous deployment too). Needs a dmg from a Mac build,
   then rebuild + redeploy.
2. Minor desktop deltas: copy-PNG-to-clipboard, pHYs DPI chunk in PNG.
3. Delete `website/` once nobody needs it for reference.
4. **Desktop de-dup** onto `qseq_core` (watch `flutter build`).
5. Merge `jaspr-migration` → `main`; flip the GitHub default branch back to main.

## Build / run / deploy

```bash
# from site/
dart pub get
dart pub global run jaspr_cli:jaspr serve      # dev server (hot reload) on :8080
dart pub global run jaspr_cli:jaspr build      # -> site/build/jaspr (static)
```

**Vercel production deploy (prebuilt static — Vercel has no Dart toolchain):**
```bash
cd site && dart pub global run jaspr_cli:jaspr build
# the build WIPES build/jaspr including .vercel/ — restore the project link
# (projectName "qseq"; copy from website/.vercel/project.json) before deploying
cd build/jaspr && vercel --prod --yes
```
Preview deploys: `vercel deploy --yes` then re-point the alias
`vercel alias set <url> qseq-jaspr.vercel.app`. No GitHub auto-deploy.

## Branches

- `main` — live static site (untouched).
- `js-label-designer` — the vanilla-JS label designer (preserved, pushed).
- `jaspr-migration` — this work.
