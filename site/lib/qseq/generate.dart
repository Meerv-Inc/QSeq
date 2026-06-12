// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

// The web rendering engine: pure-Dart composition of mm-true SVG artwork from
// qseq_core (encoders + sizing) and the `barcode` package. Runs identically on
// the server (prerender) and the client (hydrated interactivity). Mirrors the
// desktop renderers: quiet zones, module-snapped logo knockout, HRI captions
// with the bold counter, combined labels, and page-tiled serialized sheets.
import 'dart:math' as math;

import 'package:barcode/barcode.dart';
import 'package:qseq_core/qseq_core.dart';

import 'svgkit.dart';

/// The web workspaces — the desktop [AppMode]s plus the label designer.
enum WebMode {
  twoD('2D'),
  twoDSerial('2D — Serialized sheet'),
  oneD('1D'),
  oneDSerial('1D — Serialized sheet'),
  combo('Combined 1D + 2D'),
  comboSerial('Combined — Serialized sheet'),
  label('Label designer'),
  labelSerial('Label — Serialized sheet');

  const WebMode(this.title);
  final String title;

  bool get use1D =>
      this == oneD || this == oneDSerial || isCombo || isLabel;
  bool get use2D =>
      this == twoD || this == twoDSerial || isCombo || isLabel;
  bool get isSerialized =>
      this == oneDSerial ||
      this == twoDSerial ||
      this == comboSerial ||
      this == labelSerial;
  bool get isCombo => this == combo || this == comboSerial;
  bool get isLabel => this == label || this == labelSerial;
}

/// Share of the EC capacity the auto-sized centre logo consumes (desktop's
/// kLogoAutoEcShare).
const double logoAutoEcShare = 0.15;

/// Everything the engine needs, mirrored from the form state.
class GenInput {
  final WebMode mode;
  final DataSourceInput data;
  final Symbology twoD;
  final Symbology oneDSym;
  final QrEcLevel ec;
  final double dpi;
  final double xdim;
  final double barh;
  final bool logoOn;
  final String? logoDataUrl; // picked logo image (data URL), 2D dead-space
  final LabelArrangement arrangement; // combo
  final double gapMm; // combo: gap between 1D and 2D
  final double padMm; // combo: outer padding

  const GenInput({
    required this.mode,
    required this.data,
    this.twoD = Symbology.qrCode,
    this.oneDSym = Symbology.gs1_128,
    this.ec = QrEcLevel.medium,
    this.dpi = 300,
    this.xdim = 0.5,
    this.barh = 15,
    this.logoOn = false,
    this.logoDataUrl,
    this.arrangement = LabelArrangement.sideBySide,
    this.gapMm = 4,
    this.padMm = 2,
  });
}

Barcode barcodeFor(Symbology s, QrEcLevel ec) => switch (s) {
      Symbology.qrCode => Barcode.qrCode(errorCorrectLevel: _ec(ec)),
      Symbology.dataMatrix => Barcode.dataMatrix(),
      Symbology.gs1_128 => Barcode.gs128(),
      Symbology.code128 => Barcode.code128(),
      Symbology.code39 => Barcode.code39(),
      Symbology.ean13 => Barcode.ean13(),
      Symbology.upcA => Barcode.upcA(),
    };

BarcodeQRCorrectionLevel _ec(QrEcLevel l) => switch (l) {
      QrEcLevel.low => BarcodeQRCorrectionLevel.low,
      QrEcLevel.medium => BarcodeQRCorrectionLevel.medium,
      QrEcLevel.quartile => BarcodeQRCorrectionLevel.quartile,
      QrEcLevel.high => BarcodeQRCorrectionLevel.high,
    };

/// One rendered symbol: an SVG fragment positioned at (0,0) in mm units, its
/// outer extent (quiet zones included), and the sizing result behind it.
class SymbolRender {
  final String fragment;
  final double wMm;
  final double hMm;
  final SizeResult size;
  final String data;
  const SymbolRender(this.fragment, this.wMm, this.hMm, this.size, this.data);
}

EncodeConfig _cfg(GenInput i, Symbology sym, String data,
        {double logoSideMm = 0}) =>
    EncodeConfig(
      symbology: sym,
      data: data,
      ecLevel: i.ec,
      dpi: i.dpi,
      xDimensionMm: i.xdim,
      barHeightMm: i.barh,
      logoSideMm: logoSideMm,
    );

/// The recoverable EC fraction of the chosen 2D symbology — QR's level, or
/// Data Matrix's fixed ECC 200 fraction (taken from its size table via Sizer).
double recoverableFraction(GenInput i, SizeResult size) {
  if (i.twoD == Symbology.qrCode) return i.ec.recoverableFraction;
  final b = size.logoBudget;
  // budgetFraction = frac × safety margin (0.5), so invert the margin.
  return b == null ? 0.30 : b.budgetFraction / LogoEc.defaultSafetyMargin;
}

/// The centre-logo side (mm) auto-sized to [logoAutoEcShare] of the active 2D
/// symbol's EC capacity (mirrors the desktop autoLogoSideProvider).
double autoLogoMm(GenInput i, String data) {
  try {
    final size = Sizer.compute(_cfg(i, i.twoD, data));
    if (!size.fits) return 0;
    final quiet = i.twoD.quietZoneModules;
    final totalModules = size.outer.widthPx ~/ size.moduleDots;
    final symModules = totalModules - 2 * quiet;
    final effX = Dpi.effectiveXDimensionMm(i.xdim, i.dpi);
    final symMm = symModules * effX;
    return symMm * math.sqrt(recoverableFraction(i, size) * logoAutoEcShare);
  } catch (_) {
    return 0;
  }
}

/// Renders one symbol to an mm-true SVG fragment: white outer rect (quiet
/// zone), the barcode body, and — for 2D with a logo — a module-snapped centre
/// knockout with the picked logo image inside.
SymbolRender renderSymbol(GenInput i, Symbology sym, String data,
    {double logoSideMm = 0}) {
  final size = Sizer.compute(_cfg(i, sym, data, logoSideMm: logoSideMm));
  if (!size.fits) {
    throw FormatException(
        size.warnings.isNotEmpty ? size.warnings.first : 'Data does not fit');
  }
  final effX = Dpi.effectiveXDimensionMm(i.xdim, i.dpi);
  final outW = size.outer.widthMm, outH = size.outer.heightMm;
  final totalModulesW = size.outer.widthPx ~/ size.moduleDots;
  final b = StringBuffer()
    ..write('<rect x="0" y="0" width="${numStr(outW)}" '
        'height="${numStr(outH)}" fill="#fff"/>');
  final bc = barcodeFor(sym, i.ec);
  if (sym.is2D) {
    final quiet = sym.quietZoneModules;
    final symModules = totalModulesW - 2 * quiet;
    final symMm = symModules * effX;
    final q = quiet * effX;
    final body =
        bc.toSvg(data, width: symMm, height: symMm, drawText: false, fullSvg: false);
    b.write('<g transform="translate(${numStr(q)},${numStr(q)})">$body</g>');
    if (logoSideMm > 0 && symModules > 2) {
      // Centre knockout snapped to whole modules (desktop _centredModuleHole).
      var n = (logoSideMm / effX).round();
      if (n > 0) {
        if ((symModules - n) % 2 != 0) n++;
        n = n.clamp(1, symModules);
        final off = (symModules - n) / 2 * effX;
        final hx = q + off, hs = n * effX;
        b.write('<rect x="${numStr(hx)}" y="${numStr(hx)}" '
            'width="${numStr(hs)}" height="${numStr(hs)}" fill="#fff"/>');
        if (i.logoDataUrl != null) {
          final pad = effX * 0.6;
          final ix = hx + pad, isz = hs - 2 * pad;
          if (isz > 0.5) {
            b.write('<image x="${numStr(ix)}" y="${numStr(ix)}" '
                'width="${numStr(isz)}" height="${numStr(isz)}" '
                'preserveAspectRatio="xMidYMid meet" '
                'href="${i.logoDataUrl}"/>');
          }
        }
      }
    }
  } else {
    final quietL = sym.quietZoneModules * effX;
    final quietR = sym.quietZoneRightModules * effX;
    final symW = outW - quietL - quietR;
    final body = bc.toSvg(data,
        width: symW, height: outH, drawText: false, fullSvg: false);
    b.write('<g transform="translate(${numStr(quietL)},0)">$body</g>');
  }
  return SymbolRender(b.toString(), outW, outH, size, data);
}

String svgDoc(String content, double wMm, double hMm) =>
    '<svg xmlns="http://www.w3.org/2000/svg" width="${numStr(wMm)}mm" '
    'height="${numStr(hMm)}mm" viewBox="0 0 ${numStr(wMm)} ${numStr(hMm)}">'
    '$content</svg>';

/// A finished artwork: full SVG document + physical size + sizing metadata.
class Artwork {
  final String svg;
  final double wMm;
  final double hMm;
  final SizeResult? size; // primary symbol's sizing (single modes)
  final SizeResult? size2; // secondary (combo: 1D)
  final String data;
  final String? error;
  const Artwork(
      {this.svg = '',
      this.wMm = 0,
      this.hMm = 0,
      this.size,
      this.size2,
      this.data = '',
      this.error});
  bool get ok => error == null && svg.isNotEmpty;
}

String _errMsg(Object e) =>
    e is FormatException ? e.message : e.toString().replaceFirst('Exception: ', '');

double _activeLogoMm(GenInput i, String twoDData) =>
    i.logoOn ? autoLogoMm(i, twoDData) : 0;

/// Single static code (2D or 1D) with the full HRI spelled out underneath.
Artwork buildSingle(GenInput i) {
  final r = i.data.resolve();
  if (r.error != null) return Artwork(error: r.error);
  final data = r.data ?? '';
  if (data.isEmpty) return const Artwork(error: 'No data to encode.');
  try {
    final sym = i.mode.use1D && !i.mode.use2D ? i.oneDSym : i.twoD;
    final logo = sym.is2D ? _activeLogoMm(i, data) : 0.0;
    final s = renderSymbol(i, sym, data, logoSideMm: logo);
    final cap = captionSvg(data,
        cx: s.wMm / 2, yTop: s.hMm + 2.0, maxWmm: s.wMm - 1);
    final h = s.hMm + (cap.heightMm > 0 ? 2.0 + cap.heightMm : 0);
    final content = '<rect width="${numStr(s.wMm)}" height="${numStr(h)}" '
        'fill="#fff"/>${s.fragment}${cap.svg}';
    return Artwork(
        svg: svgDoc(content, s.wMm, h),
        wMm: s.wMm,
        hMm: h,
        size: s.size,
        data: data);
  } catch (e) {
    return Artwork(error: _errMsg(e));
  }
}

/// Combined label: 2D (Digital Link) + 1D (element string) for the same item,
/// stacked or side-by-side with a gap and outer padding (desktop CombinedLabel).
Artwork buildCombined(GenInput i, {String? serialOverride}) {
  try {
    final d2 = i.data
        .encodeWith(format: SgtinFormat.digitalLink, serial: serialOverride);
    final d1 = i.data
        .encodeWith(format: SgtinFormat.elementString, serial: serialOverride);
    final logo = _activeLogoMm(i, d2);
    final two = renderSymbol(i, i.twoD, d2, logoSideMm: logo);
    final one = renderSymbol(i, i.oneDSym, d1);
    final g = i.gapMm.clamp(0, 100).toDouble();
    final p = i.padMm.clamp(0, 100).toDouble();
    double w, h, x2, y2, x1, y1;
    if (i.arrangement == LabelArrangement.stacked) {
      w = math.max(two.wMm, one.wMm) + 2 * p;
      h = two.hMm + one.hMm + g + 2 * p;
      x2 = (w - two.wMm) / 2;
      y2 = p;
      x1 = (w - one.wMm) / 2;
      y1 = p + two.hMm + g;
    } else {
      w = two.wMm + one.wMm + g + 2 * p;
      h = math.max(two.hMm, one.hMm) + 2 * p;
      x2 = p;
      y2 = (h - two.hMm) / 2;
      x1 = p + two.wMm + g;
      y1 = (h - one.hMm) / 2;
    }
    // Shared HRI: the Digital Link URL once, under the whole label.
    final cap =
        captionSvg(d2, cx: w / 2, yTop: h + 1.0, maxWmm: w - 2);
    final totalH = h + (cap.heightMm > 0 ? 1.0 + cap.heightMm : 0);
    final b = StringBuffer()
      ..write('<rect width="${numStr(w)}" height="${numStr(totalH)}" fill="#fff"/>')
      ..write('<g transform="translate(${numStr(x2)},${numStr(y2)})">'
          '${two.fragment}</g>')
      ..write('<g transform="translate(${numStr(x1)},${numStr(y1)})">'
          '${one.fragment}</g>')
      ..write(cap.svg);
    return Artwork(
        svg: svgDoc(b.toString(), w, totalH),
        wMm: w,
        hMm: totalH,
        size: two.size,
        size2: one.size,
        data: d2);
  } catch (e) {
    return Artwork(error: _errMsg(e));
  }
}

// ---- serialized sheets -------------------------------------------------------

class SerialSpec {
  final String prefix;
  final int start;
  final int count;
  final int pad;
  const SerialSpec(
      {this.prefix = '', this.start = 1, this.count = 24, this.pad = 5});
  String serialAt(int n) => '$prefix${counterAt(n)}';
  String counterAt(int n) => (start + n).toString().padLeft(pad, '0');
}

class SheetSpec {
  final PageFormat page;
  final PageOrientation orientation;
  final int columnsOverride; // 0 = auto-fit
  const SheetSpec(
      {this.page = PageFormat.letter,
      this.orientation = PageOrientation.portrait,
      this.columnsOverride = 0});

  double get pageWmm => !page.isContinuous &&
          orientation == PageOrientation.landscape
      ? page.heightMm
      : page.widthMm;
  double get pageHmm => page.isContinuous
      ? double.infinity
      : (orientation == PageOrientation.landscape
          ? page.widthMm
          : page.heightMm);
}

const double _sheetMarginMm = 8;
const double _cellGapMm = 3;
const double _inCellGapMm = 4; // between the 2D and 1D within a combo cell

/// One sheet cell's content rendered once (per serial). Cells are uniform; the
/// width is probed from the first and last serials (longest 1D data wins).
class _Cell {
  final String svgFragment; // positioned at (0,0)
  final double wMm;
  final double hMm;
  const _Cell(this.svgFragment, this.wMm, this.hMm);
}

class SheetLayout {
  final SheetSpec spec;
  final double cellW;
  final double cellH;
  final int cols;
  final int rows; // per page (continuous: all rows)
  final int perPage;
  final int pageCount;
  final bool continuous;
  final double pageWmm;
  final double pageHmm; // finite extent (continuous: computed)
  final int count;
  const SheetLayout(
      this.spec,
      this.cellW,
      this.cellH,
      this.cols,
      this.rows,
      this.perPage,
      this.pageCount,
      this.continuous,
      this.pageWmm,
      this.pageHmm,
      this.count);
}

_Cell _sheetCell(GenInput i, SerialSpec ss, int n,
    {required double cellW}) {
  final serial = ss.serialAt(n);
  final counter = ss.counterAt(n);
  final b = StringBuffer();
  var y = 0.0;
  void addSymbol(SymbolRender s, String data) {
    final x = (cellW - s.wMm) / 2;
    b.write('<g transform="translate(${numStr(x)},${numStr(y)})">'
        '${s.fragment}</g>');
    y += s.hMm;
    final boldFrom = data.lastIndexOf(counter);
    final cap = captionSvg(data,
        cx: cellW / 2,
        yTop: y + 1.2,
        maxWmm: cellW - 1,
        fontMm: 2.0,
        boldFrom: boldFrom);
    y += 1.2 + cap.heightMm;
    b.write(cap.svg);
  }

  if (i.mode.use2D) {
    final d2 = i.mode.isCombo || i.data.kind == DataSourceKind.sgtin
        ? i.data.encodeWith(
            format: i.mode.isCombo ? SgtinFormat.digitalLink : null,
            serial: serial)
        : i.data.encodeWith(serial: serial);
    final logo = _activeLogoMm(i, d2);
    addSymbol(renderSymbol(i, i.twoD, d2, logoSideMm: logo), d2);
  }
  if (i.mode.use1D) {
    if (i.mode.use2D) y += _inCellGapMm;
    final d1 = i.mode.isCombo
        ? i.data.encodeWith(format: SgtinFormat.elementString, serial: serial)
        : i.data.encodeWith(serial: serial);
    addSymbol(renderSymbol(i, i.oneDSym, d1), d1);
  }
  return _Cell(b.toString(), cellW, y);
}

/// Probes cell dimensions and computes the page grid.
SheetLayout layoutSheet(GenInput i, SerialSpec ss, SheetSpec spec) {
  final count = ss.count.clamp(1, 2000);
  // Probe first and last serial: the longest data makes the widest 1D symbol.
  double probeW = 10;
  for (final n in [0, count - 1]) {
    final serial = ss.serialAt(n);
    if (i.mode.use2D) {
      final d2 = i.mode.isCombo
          ? i.data.encodeWith(format: SgtinFormat.digitalLink, serial: serial)
          : i.data.encodeWith(serial: serial);
      probeW =
          math.max(probeW, Sizer.compute(_cfg(i, i.twoD, d2)).outer.widthMm);
    }
    if (i.mode.use1D) {
      final d1 = i.mode.isCombo
          ? i.data.encodeWith(format: SgtinFormat.elementString, serial: serial)
          : i.data.encodeWith(serial: serial);
      probeW = math.max(
          probeW, Sizer.compute(_cfg(i, i.oneDSym, d1)).outer.widthMm);
    }
  }
  final cellW = probeW;
  final probeCell = _sheetCell(i, ss, count - 1, cellW: cellW);
  final cellH = probeCell.hMm;
  final contentW = spec.pageWmm - 2 * _sheetMarginMm;
  var cols = spec.columnsOverride > 0
      ? spec.columnsOverride
      : math.max(
          1, ((contentW + _cellGapMm) / (cellW + _cellGapMm)).floor());
  cols = math.max(1, cols);
  final continuous = spec.page.isContinuous;
  int rows, perPage, pageCount;
  double pageHmm;
  if (continuous) {
    perPage = count;
    rows = (count / cols).ceil();
    pageCount = 1;
    pageHmm = 2 * _sheetMarginMm + rows * (cellH + _cellGapMm) - _cellGapMm;
  } else {
    final contentH = spec.pageHmm - 2 * _sheetMarginMm;
    rows = math.max(
        1, ((contentH + _cellGapMm) / (cellH + _cellGapMm)).floor());
    perPage = cols * rows;
    pageCount = math.max(1, (count / perPage).ceil());
    pageHmm = spec.pageHmm;
  }
  return SheetLayout(spec, cellW, cellH, cols, rows, perPage, pageCount,
      continuous, spec.pageWmm, pageHmm, count);
}

/// Renders one page of the sheet ([page] is 0-based). [maxCells] caps the
/// on-screen render; exports pass null to emit every cell.
Artwork buildSheetPage(GenInput i, SerialSpec ss, SheetLayout L, int page,
    {int? maxCells}) {
  try {
    final start = L.continuous ? 0 : page * L.perPage;
    final onPage =
        L.continuous ? L.count : math.min(L.perPage, L.count - start);
    final shown = maxCells == null ? onPage : math.min(onPage, maxCells);
    final b = StringBuffer()
      ..write('<rect width="${numStr(L.pageWmm)}" '
          'height="${numStr(L.pageHmm)}" fill="#fff"/>');
    for (var k = 0; k < shown; k++) {
      final cell = _sheetCell(i, ss, start + k, cellW: L.cellW);
      final x = _sheetMarginMm + (k % L.cols) * (L.cellW + _cellGapMm);
      final y = _sheetMarginMm + (k ~/ L.cols) * (L.cellH + _cellGapMm);
      b.write('<g transform="translate(${numStr(x)},${numStr(y)})">'
          '${cell.svgFragment}</g>');
    }
    return Artwork(
        svg: svgDoc(b.toString(), L.pageWmm, L.pageHmm),
        wMm: L.pageWmm,
        hMm: L.pageHmm,
        data: '');
  } catch (e) {
    return Artwork(error: _errMsg(e));
  }
}

/// All encoded payloads for the serialization log.
List<String> serialLog(GenInput i, SerialSpec ss) {
  final out = <String>[];
  try {
    final count = ss.count.clamp(1, 2000);
    for (var n = 0; n < count; n++) {
      final serial = ss.serialAt(n);
      if (i.mode.use2D) {
        out.add(i.mode.isCombo
            ? i.data
                .encodeWith(format: SgtinFormat.digitalLink, serial: serial)
            : i.data.encodeWith(serial: serial));
      } else {
        out.add(i.data.encodeWith(serial: serial));
      }
    }
  } catch (_) {}
  return out;
}
