# QSeq → Jaspr migration

Status as of 2026-06-11 (branch `jaspr-migration`). The live site (`qseq.app`)
is **unchanged** — it still serves the static `website/` from `main`. This branch
builds the Dart/Jaspr replacement in parallel; nothing cuts over until parity.

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
- SVG export (client-only blob download).
- SEO head ported (title, description, OG, canonical, GA, favicon) + dark theme.

## Remaining (in rough priority)

1. **PNG export** — rasterize the SVG to a canvas (`package:web`, client-only) and
   download. (The `pdf` package OOMs dart2js, so **PDF** needs either a lighter
   client lib, canvas→jsPDF interop, or a small server route. Do NOT add `pdf` to
   the client deps.)
2. **Serialized sheets** — port `composeSheet`/pagination; tile codes; per-code
   captions; page browser; PDF/PNG of all codes.
3. **Combined label + label designer** — the feature built in JS on branch
   `js-label-designer` (2D-left/1D-right, shared HRI, dashed cut-frame, free
   drag/resize, background-image offline round-trip, serialized label sheets).
   Port to Jaspr with a `<canvas>` via `package:web` (client-only).
4. **Marketing parity** — add mission/about/support sections (raw HTML) + assets
   (`/QSeq.dmg`, `/qseq-windows-setup.exe`) into `site/web/`.
5. **Serialization log** panel.
6. **Desktop de-dup** onto `qseq_core` (watch `flutter build`).

## Build / run / deploy

```bash
# from site/
dart pub get
dart pub global run jaspr_cli:jaspr serve      # dev server (hot reload) on :8080
dart pub global run jaspr_cli:jaspr build      # -> site/build/jaspr (static)
```

**Vercel cutover (prebuilt static — Vercel has no Dart toolchain):**
The qseq Vercel project currently deploys `website/`. To cut over, build locally
then deploy `site/build/jaspr` as a static dir to the same project:
```bash
cd site && dart pub global run jaspr_cli:jaspr build
cd build/jaspr && vercel --prod      # serves the static output; needs the project link
```
Keep `website/` until the Jaspr build is at parity; cutover = point the deploy at
`site/build/jaspr` instead of `website/`. See the `qseq-deploy-and-discovery`
memory (manual `vercel --prod`, no GitHub auto-deploy).

## Branches

- `main` — live static site (untouched).
- `js-label-designer` — the vanilla-JS label designer (preserved, pushed).
- `jaspr-migration` — this work.
