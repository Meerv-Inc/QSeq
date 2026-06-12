# Changelog

All notable changes to **QSeq** are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/). QSeq uses date-stamped 1.x
releases.

© 2026 Meerv Inc. — PolyForm Noncommercial License 1.0.0.

## [1.4.0] — 2026-06-12

Serialization that starts where you say, in every sheet — and a site that
spells out what a sustainable identifier is.

### Added
- **Dark / light mode switch** in the navigation (left of Generator); the
  choice persists and applies before first paint. The light palette uses the
  Meerv brand green.
- **"What Sustainable Identity requires"** section on the site: an identifier
  must be an *Identity* — serialized, web-resolvable, ultimately leading to a
  Digital Product Passport (a bare SKU is not one) — **and** *Sustainable* —
  printed true-to-size with enough error-correction margin to survive real
  life. Both conditions must hold.
- The hero now reads **Sustainable Identity Generator for Every Thing**, in
  the Meerv brand green.

### Changed
- **Serialization starts at the Serial field.** The serial you type (e.g.
  6789) is the basis: its trailing digits increment per item — 6789, 6790, … —
  leading text stays as a fixed prefix, and leading zeros are preserved
  (AB0099 → AB0100). The separate Prefix / Start / Zero-pad fields are gone.
- **Sheet-of-copies workspaces serialize too** — every label on a copies sheet
  gets the next identifier, so no two printed codes are the same.
- The **Serialization Log** lists every generated identifier in all sheet
  workspaces (it previously counted 00001… from a separate Start field,
  ignoring the Serial).

### Fixed
- **Blank dropdowns after switching workspaces** (e.g. the Resolver showing
  nothing until clicked): form controls are now keyed, so the UI never
  re-purposes one control's element as another's.

## [1.3.0] — 2026-06-12

The website is now the **Dart/Jaspr app** — qseq.app cut over from the old
hand-written JavaScript to the same Dart core (`qseq_core` + `barcode`) the
desktop apps use, so an identity minted in the browser is byte-for-byte the
desktop's. Source moved to **github.com/Meerv-Inc/QSeq**.

### Added
- **Sheet-of-copies workspaces (web)** — "2D — Sheet of copies" and "1D — Sheet
  of copies" tile N identical codes per page (1–2000), with the same page
  formats, pagination and PDF export as serialized sheets.
- **Label designer as an overlay (web)** — the designer is now a checkbox
  available in *every* workspace instead of a separate workspace: single modes
  design one label, sheet modes tile the designed label per copy/serial. The
  label shows exactly the workspace's symbols.
- **HRI font size (web)** — the Digital Link printout on a label has an
  adjustable font size (mm, 0 = auto), saved in `.qseq` projects.
- **Rulers settings section (web)** — screen rulers can be switched off, and
  PDF exports can opt **in** to mm-true ruler bands (mm/inch ticks + vernier).
- **Logo dead-space controls (web)** — the Logo section offers 15/20/30/40/50%
  of the error-correction budget or a Manual side-in-mm override (previously
  fixed at 15%); persisted in `.qseq` projects. For every size it reports the
  share of the error-correction capacity consumed and what that means for
  scanability (robust / fragile / will not scan).
- The footer shows the running version (bottom left).

### Fixed
- **Numeric fields were dead on the web** — typing into Count, DPI,
  X-dimension and every other number field did nothing (a type mismatch threw
  on each keystroke in release builds). Number inputs also no longer mangle
  half-typed values while you type; out-of-range values clamp when you leave
  the field.

### Changed
- Old `.qseq` projects with label workspaces load as Combined + label overlay.

## [1.2.2] — 2026-06-10

Print-true fixes and a friendlier web app.

### Fixed
- **Measurement rulers no longer overlay the code** in single-code PDF exports.
  The symbol is now pinned to its exact physical size, so it can never expand
  into the reserved ruler gutter.

### Added
- **Centre-logo image overlay (web)** — open a PNG/JPEG/SVG logo into the
  cleared 2D dead-space, or remove it; the knockout still protects the symbol's
  finder, timing and alignment patterns.
- **Serialization-log buttons (web)** — the log scrolls with up / down /
  page-up / page-down buttons, since the macOS overlay scrollbar auto-hides and
  is hard to grab.
- **Support page** (support@meerv.com) and in-page **release notes** on the
  website.

## [1.2.1] — 2026-06-09

### Added
- **Centre logo in the serialized preview**, and **arrow-button navigation**
  for the serialization log.

### Changed
- The **macOS build is now signed & notarized** — open it without Gatekeeper
  prompts.
- A **Windows installer** (Inno Setup) branded as QSeq; About / Flutter
  sections credit both macOS and Windows.

### Fixed
- The **ungrabbable serialization-log scrollbar** in the macos_ui sidebar.

## [1.2.0] — 2026-06-09

First **Windows desktop** release, plus a serialized-sheet overhaul.

### Added
- **Native Windows desktop build** from the same Dart codebase, shipped as a
  portable ZIP and an installer.
- **Portrait / landscape** label orientation and a **zoom-to-fit** preview.

### Changed
- **Serialized-sheet overhaul** — packing and pagination reworked across the
  app and the web so the preview tracks the printed pages.

## [1.1.0] — 2026-06-09

Serialized-sheet pagination, flexographic page sizes, a cleaner centre-logo
zone, and input hardening — across both the macOS app and the web app.

### Added
- **Page sizes for serialized sheets** — choose the printed page: **A4, US
  Letter, A3, US Legal**, or a **flexographic continuous web** (12/24/36 inch or
  12/24/36 cm wide), which lays every code down one endless page.
- **Page browser** — the serialized preview now pages through the sheet exactly
  as it will print, with a page selector and a per-page count. On the web, the
  serialization log links each code to the page that holds it.

### Changed
- **Centre-logo zone is now fully cleared.** A logo reserves a clean square,
  snapped to whole modules, that is free of *all* code — data, error correction
  and function patterns alike — instead of preserving function patterns through
  the logo. Keep the logo within the EC budget the size readout shows.
- The serial **item count is capped at 2000**, the real render/PDF limit.

### Fixed
- **Resolver presets now update the Digital Link domain** on the web — switching
  to QDat.io rewrites the domain instead of snapping back to GS1.
- **Out-of-range inputs can no longer crash either app** — negative, empty or
  absurd values (DPI, X-dimension, logo size, zero-pad, count…) are clamped to
  safe ranges.

## [1.0.0] — 2026-06-07

First public release. Native macOS app (Apple silicon) plus a companion web app
at [qseq.app](https://qseq.app).

### Generate
- Symbologies: **QR Code, Data Matrix, GS1-128, Code 128, Code 39, EAN-13,
  UPC-A**.
- **SGTIN** encoding in three standard forms: GS1 element string `(01)…(21)…`,
  **EPC Tag URI** (`urn:epc:id:sgtin:…`), and **GS1 Digital Link**.
- **GS1 Digital Links** with a selectable resolver — GS1 (`id.gs1.org`) or
  **QDat.io** (`tapdpp.qdat.io`).
- **NATO Stock Numbers** (NSN) — structural parsing and encoding.

### Serialize
- **1D / 2D / combined** workspaces, each as a single design or a **serialized
  sheet**.
- Serialization extends the GTIN to an **SGTIN** (the serial is GS1 AI 21), so
  every code resolves as a proper GS1 Digital Link.
- The serial number prints **under each code**, with the incrementing digits in
  **bold**.
- A **Serialization Log** lists the full GS1 Digital Link encoded in every code.

### Get the size right
- **Live print-true size calculator** — the printed outer perimeter as a
  function of the centre logo dead-space, the byte count, the DPI and the
  error-correction level.
- **Structure-aware logo dead-space** — a centre logo never destroys QR finder,
  timing or alignment patterns.
- **mm + inch + vernier measurement rulers** on screen and embedded in exports,
  so a print can be verified against a physical ruler.

### Export & share
- **PNG** at exact DPI (with a pHYs chunk), **SVG**, **PDF** (single codes and
  multi-page serialized sheets), and copy-to-clipboard.
- **Project files** — every parameter saved as editable JSON, interchangeable
  between the macOS app and the website.
