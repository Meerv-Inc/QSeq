# QSeq

*© 2026 Meerv Inc.*

A native **macOS and Windows** (Flutter) generator for Barcodes, QR Codes and
Data Matrix codes — plus the **[qseq.app](https://qseq.app)** web app, written
in **Dart/Jaspr** from the same core — built for GS1 supply-chain and defense
logistics use. Its defining feature is a **live physical-size calculator**: the
printed outer perimeter is shown as a function of the centre logo dead-space,
the byte count, the printing resolution (DPI) and the error-correction level.

Download the macOS or Windows app and use the browser version at **[qseq.app](https://qseq.app)**.

## Purpose

QSeq exists to make it trivial to **mint correct, durable, standards-based
identities for physical things** — and to do it in a way that anyone can use,
audit and build on.

Every object in a modern supply chain needs an identity that a scanner can read
and a server can resolve: a **GTIN**, a serialized **SGTIN**, a web-resolvable
**GS1 Digital Link**, or a **NATO Stock Number**. Getting that right is fiddly —
the data must follow GS1/EPC rules, the symbol must hold the bytes at the chosen
error-correction level, a logo must not destroy the code, and the print must come
out at the *exact* physical size on the label. Most tools get one or two of
these right. QSeq is built to get **all of them** right at once:

- **Correct by construction** — SGTIN, EPC Tag URI and GS1 Digital Link encoders
  that follow the standards, including serialization (GTIN → SGTIN via AI 21).
- **Print-true** — a size calculator and mm/inch/vernier rulers so what you
  design is exactly what prints.
- **Damage-tolerant** — a structure-aware logo dead-space that respects the
  symbol's error-correction budget and never destroys its finder patterns.
- **Serial-ready** — generate a whole sheet of sequentially-numbered codes with a
  full log of every encoded link.

QSeq is released as **source-available** (noncommercial) in service of
**Sustainable Identity on Every Thing (SIoT)**: a future where every physical
object carries an open, web-resolvable, standards-based identity that anyone can
read, verify and build upon — without proprietary lock-in. Durable, interoperable
identity is the foundation of the circular economy (reuse, repair, recall,
provenance, end-of-life), and the tools that *mint* those identities should stay
a public good. It is written in Dart so a **single core** (`packages/qseq_core`)
serves macOS, Windows (Flutter) and the web (Jaspr) identically — an identity
minted on any surface is byte-for-byte the same.

## Features

- **Symbologies:** QR Code, Data Matrix, GS1-128, Code 128, Code 39, EAN-13,
  UPC-A.
- **SGTIN encoding** in three representations:
  - GS1 element string — `(01)<gtin>(21)<serial>`
  - GS1 Digital Link URI — `https://id.gs1.org/01/<gtin>/21/<serial>`
  - EPC Tag URI — `urn:epc:id:sgtin:<companyPrefix>.<indicator+itemRef>.<serial>`
- **GS1 Digital Links** for web-resolvable QR / Data Matrix.
- **NATO Stock Numbers (NSN):** 13-digit structural parser (NSC / NCB / NIIN).
  NSNs have no standardized check digit — only structure is validated.
- **Live outer-size readout** in mm, inches and pixels at the target DPI.
- **Logo dead-space ⇄ error-correction budget:** for QR/Data Matrix the centre
  logo is checked against the recoverable EC fraction (with a safety margin) and
  the app reports the maximum safe logo size. For 1D codes it warns that a logo
  must not overlap the bars.
- **Structure-aware dead-space:** the centre knockout never erases QR function
  patterns (finder, timing, alignment, format/version) — they show through the
  logo, so a centred logo can't destroy a central alignment pattern.
- **Batch sheets:** fill a page (A4 / US Letter / A3 / US Legal, or a
  flexographic continuous web) with sequentially-numbered codes, each captioned
  with its serial — the **incrementing digits in bold** — auto-tiled into a grid
  and exported as a multi-page PDF.
- **Combined 1D + 2D label:** pairs a GS1-128 (SGTIN element string) with a
  QR/Data Matrix (GS1 Digital Link) for the same item on one larger label,
  stacked or side-by-side, with the combined outer size computed.
- **Sheets of copies:** tile N identical codes per page — alongside the
  serialized sheets — with page format, orientation and column control.
- **Label designer (web):** an overlay on any workspace — drag/resize the
  code(s), title and shared HRI (adjustable font) on a sized label with a
  dashed cut-frame and an offline background-image round-trip.
- **Exports:** PNG at exact DPI (with a pHYs chunk so print software reads the
  true physical size), SVG / PDF vector (optionally with mm/inch/vernier
  rulers), and copy-to-clipboard.

## Architecture

```
packages/qseq_core/   pure-Dart shared core: encoders (gtin, sgtin, gs1/FNC1,
                      nsn), sizing (capacity tables, logo_ec, dpi, Sizer) and
                      models — the single source of truth for every surface
site/                 the qseq.app web app (Dart/Jaspr, statically prerendered;
                      mm-true SVG engine, label designer, serialized sheets)
lib/
  encoders/ sizing/ models/   desktop copies of the core (being de-duplicated
                              onto qseq_core)
  render/     barcode_factory, raster_renderer (pixel-exact PNG + pHYs),
              label_renderer (combined), svg_exporter, pdf_exporter, clipboard
  state/      app_controller (Riverpod) + derived size providers
  ui/         home_page (macos_ui shell), inputs_panel, preview_pane,
              size_readout, export_actions
website/              the previous hand-written JS site (retired, kept for
                      reference)
```

The domain core is pure Dart and fully unit-tested; the sizing engine is a pure
function `Sizer.compute(EncodeConfig) -> SizeResult`.

## Develop

```bash
# desktop
flutter pub get
flutter test          # encoders, sizing, render pipeline, providers
flutter run -d macos  # requires CocoaPods (brew install cocoapods)

# web (from site/)
dart pub get
dart pub global run jaspr_cli:jaspr serve   # dev server on :8080
dart pub global run jaspr_cli:jaspr build   # static build -> site/build/jaspr
dart run tool/smoke.dart                    # engine smoke test (every mode)
```

## Sizing notes / standards caveats (surfaced in-app)

- QR capacity follows ISO/IEC 18004 byte-mode tables; the smallest fitting
  version is chosen for the requested EC level.
- Data Matrix uses ECC 200 square sizes; its error correction is **fixed per
  size** and not user-tunable.
- 1D widths are well-founded estimates (the encoder's mode choices can shift the
  width by a few modules); the rendered symbol is authoritative.
