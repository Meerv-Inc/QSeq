# Changelog

All notable changes to **QSeq** are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/). QSeq uses date-stamped 1.x
releases.

© 2026 Meerv Inc. — PolyForm Noncommercial License 1.0.0.

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
