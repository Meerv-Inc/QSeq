# QSeq

*© 2026 Meerv Inc.*

A native **macOS** (Flutter) generator for Barcodes, QR Codes and Data Matrix
codes, built for GS1 supply-chain and defense logistics use. Its defining
feature is a **live physical-size calculator**: the printed outer perimeter is
shown as a function of the centre logo dead-space, the byte count, the printing
resolution (DPI) and the error-correction level.

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
- **Batch sheets:** fill a page (A4 / US Letter) with sequentially-numbered
  codes, each captioned with its serial — the **incrementing digits in bold** —
  auto-tiled into a grid and exported as a multi-page PDF.
- **Combined 1D + 2D label:** pairs a GS1-128 (SGTIN element string) with a
  QR/Data Matrix (GS1 Digital Link) for the same item on one larger label,
  stacked or side-by-side, with the combined outer size computed.
- **Exports:** PNG at exact DPI (with a pHYs chunk so print software reads the
  true physical size), SVG / PDF vector, and copy-to-clipboard.

## Architecture

```
lib/
  encoders/   gtin, sgtin (3 output forms), gs1 (FNC1), nsn
  sizing/     qr_capacity, datamatrix_capacity, linear_metrics,
              logo_ec (dead-space budget), dpi, sizer (dispatch -> SizeResult)
  render/     barcode_factory, raster_renderer (pixel-exact PNG + pHYs),
              label_renderer (combined), svg_exporter, pdf_exporter, clipboard
  models/     symbology, encode_config, size_result, data_source, combined_label
  state/      app_controller (Riverpod) + derived size providers
  ui/         home_page (macos_ui shell), inputs_panel, preview_pane,
              size_readout, export_actions
```

The domain core (`encoders/`, `sizing/`) is pure Dart and fully unit-tested; the
sizing engine is a pure function `Sizer.compute(EncodeConfig) -> SizeResult`.

## Develop

```bash
flutter pub get
flutter test          # 34 tests: encoders, sizing, render pipeline, providers
flutter run -d macos  # requires CocoaPods (brew install cocoapods)
```

## Sizing notes / standards caveats (surfaced in-app)

- QR capacity follows ISO/IEC 18004 byte-mode tables; the smallest fitting
  version is chosen for the requested EC level.
- Data Matrix uses ECC 200 square sizes; its error correction is **fixed per
  size** and not user-tunable.
- 1D widths are well-founded estimates (the encoder's mode choices can shift the
  width by a few modules); the rendered symbol is authoritative.
