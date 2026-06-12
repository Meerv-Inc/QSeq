// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

// The label designer: a sized label combining a 2D code (GS1 Digital Link), a
// 1D barcode (element string / NSN), a free-text title, ONE shared
// human-readable line, an optional imported background image (offline
// round-trip), and a dashed cut-frame. Elements have free positions (drag on
// the client, mm inputs everywhere). Pure Dart — prerenders and exports.
import 'dart:math' as math;

import 'package:qseq_core/qseq_core.dart';

import 'generate.dart';
import 'svgkit.dart';

class ElRect {
  double x, y, w, h;
  ElRect(this.x, this.y, this.w, this.h);
  Map<String, double> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};
  static ElRect fromJson(Map<String, dynamic> j) => ElRect(
      (j['x'] as num).toDouble(),
      (j['y'] as num).toDouble(),
      (j['w'] as num).toDouble(),
      (j['h'] as num).toDouble());
  ElRect clone() => ElRect(x, y, w, h);
}

const labelElementKeys = ['title', 'twoD', 'oneD', 'hri'];

class LabelSpec {
  double wMm;
  double hMm;
  String title;
  bool twoDOn, oneDOn, titleOn, hriOn;
  bool frameShown;
  bool framePrinted;
  bool snap;
  String? bgDataUrl;

  /// Font size of the shared HRI (Digital Link printout) in mm.
  /// 0 = auto (derived from the HRI box height).
  double hriFontMm;
  final Map<String, ElRect> rects = {};

  LabelSpec({
    this.wMm = 90,
    this.hMm = 50,
    this.title = '',
    this.twoDOn = true,
    this.oneDOn = true,
    this.titleOn = true,
    this.hriOn = true,
    this.frameShown = true,
    this.framePrinted = false,
    this.snap = true,
    this.bgDataUrl,
    this.hriFontMm = 0,
  });

  bool on(String key) => switch (key) {
        'title' => titleOn,
        'twoD' => twoDOn,
        'oneD' => oneDOn,
        'hri' => hriOn,
        _ => false,
      };

  Map<String, dynamic> toJson() => {
        'wMm': wMm,
        'hMm': hMm,
        'title': title,
        'on': {'twoD': twoDOn, 'oneD': oneDOn, 'title': titleOn, 'hri': hriOn},
        'frameShown': frameShown,
        'framePrinted': framePrinted,
        'snap': snap,
        'hriFontMm': hriFontMm,
        'el': {for (final e in rects.entries) e.key: e.value.toJson()},
      };

  void applyJson(Map<String, dynamic> j) {
    wMm = (j['wMm'] as num?)?.toDouble() ?? wMm;
    hMm = (j['hMm'] as num?)?.toDouble() ?? hMm;
    title = j['title'] as String? ?? title;
    final on = j['on'];
    if (on is Map) {
      twoDOn = on['twoD'] as bool? ?? twoDOn;
      oneDOn = on['oneD'] as bool? ?? oneDOn;
      titleOn = on['title'] as bool? ?? titleOn;
      hriOn = on['hri'] as bool? ?? hriOn;
    }
    frameShown = j['frameShown'] as bool? ?? frameShown;
    framePrinted = j['framePrinted'] as bool? ?? framePrinted;
    snap = j['snap'] as bool? ?? snap;
    hriFontMm =
        ((j['hriFontMm'] as num?)?.toDouble() ?? hriFontMm).clamp(0, 30);
    final el = j['el'];
    if (el is Map) {
      rects.clear();
      el.forEach((k, v) {
        if (v is Map) {
          rects[k as String] = ElRect.fromJson(v.cast<String, dynamic>());
        }
      });
    }
  }
}

/// Per-render payloads for the label: 2D carries the Digital Link URL, 1D the
/// element string (SGTIN) / payload (text); the shared HRI is the URL once.
({String d2, String d1, String hri}) labelTexts(GenInput i,
    {String? serial}) {
  switch (i.data.kind) {
    case DataSourceKind.sgtin:
      final d2 = i.data
          .encodeWith(format: SgtinFormat.digitalLink, serial: serial);
      final d1 = i.data
          .encodeWith(format: SgtinFormat.elementString, serial: serial);
      return (d2: d2, d1: d1, hri: d2);
    case DataSourceKind.rawText:
      final p = i.data.encodeWith(serial: serial);
      return (d2: p, d1: p, hri: p);
  }
}

/// Natural (sized) symbol aspect/extent for layout. Returns width/height mm.
({double w, double h})? naturalSize(GenInput i, Symbology sym, String data) {
  try {
    final s = Sizer.compute(EncodeConfig(
      symbology: sym,
      data: data,
      ecLevel: i.ec,
      dpi: i.dpi,
      xDimensionMm: i.xdim,
      barHeightMm: i.barh,
    ));
    if (!s.fits) return null;
    return (w: s.outer.widthMm, h: s.outer.heightMm);
  } catch (_) {
    return null;
  }
}

/// Default arrangement: title across the top, 2D lower-left, 1D lower-right,
/// shared HRI spanning the bottom. Fills [spec.rects].
void autoArrange(GenInput i, LabelSpec spec) {
  spec.rects.clear();
  final t = labelTexts(i);
  final p = math.min(4.0, math.max(1.5, spec.wMm * 0.04));
  final titleFont = (spec.hMm * 0.09).clamp(2.2, 4.2);
  final hriFont = spec.hriFontMm > 0
      ? spec.hriFontMm.clamp(0.8, 30.0)
      : (spec.hMm * 0.07).clamp(1.8, 3.2);
  final titleH = spec.titleOn ? titleFont * 1.4 : 0.0;
  final hriH = spec.hriOn ? hriFont * 1.3 * 2 + 0.6 : 0.0;
  var top = p;
  if (spec.titleOn) {
    spec.rects['title'] = ElRect(p, top, spec.wMm - 2 * p, titleH);
    top += titleH + p * 0.4;
  }
  final bottom = spec.hMm - p - (hriH > 0 ? hriH + p * 0.4 : 0);
  final bandH = math.max(4.0, bottom - top);
  final n2 = spec.twoDOn ? naturalSize(i, i.twoD, t.d2) : null;
  final n1 = spec.oneDOn ? naturalSize(i, i.oneDSym, t.d1) : null;
  final gap = p;
  double w2 = 0, h2 = 0, w1 = 0, h1 = 0;
  if (n2 != null) {
    final k = bandH / n2.h;
    w2 = n2.w * k;
    h2 = bandH;
  }
  if (n1 != null) {
    final k = bandH / n1.h;
    w1 = n1.w * k;
    h1 = bandH;
  }
  final availW = spec.wMm - 2 * p;
  final totalW = w2 + w1 + ((n2 != null && n1 != null) ? gap : 0);
  if (totalW > availW && totalW > 0) {
    final k = availW / totalW;
    w2 *= k;
    h2 *= k;
    w1 *= k;
    h1 *= k;
  }
  final rowH = math.max(h2, h1);
  final rowY = top + (bandH - rowH) / 2;
  var x = p + (availW - (w2 + w1 + ((n2 != null && n1 != null) ? gap : 0))) / 2;
  if (n2 != null) {
    spec.rects['twoD'] = ElRect(x, rowY + (rowH - h2) / 2, w2, h2);
    x += w2 + gap;
  }
  if (n1 != null) {
    spec.rects['oneD'] = ElRect(x, rowY + (rowH - h1) / 2, w1, h1);
  }
  if (spec.hriOn) {
    spec.rects['hri'] = ElRect(p, spec.hMm - p - hriH, spec.wMm - 2 * p, hriH);
  }
}

void ensureArranged(GenInput i, LabelSpec spec) {
  final missing = labelElementKeys
      .any((k) => spec.on(k) && !spec.rects.containsKey(k));
  if (missing) autoArrange(i, spec);
}

String _dashedRect(
        double x, double y, double w, double h, String color, double sw) =>
    '<rect x="${numStr(x)}" y="${numStr(y)}" width="${numStr(w)}" '
    'height="${numStr(h)}" fill="none" stroke="$color" '
    'stroke-width="${numStr(sw)}" stroke-dasharray="1.6 1.2"/>';

/// Renders the label to a full SVG document.
/// [forExport]: white base, frame only when framePrinted, no selection chrome.
/// On screen: bg/frame/selection handles as configured.
Artwork buildLabel(GenInput i, LabelSpec spec,
    {String? serial, bool forExport = false, String? selected}) {
  try {
    ensureArranged(i, spec);
    final t = labelTexts(i, serial: serial);
    final b = StringBuffer();
    if (forExport || spec.bgDataUrl == null) {
      b.write('<rect width="${numStr(spec.wMm)}" '
          'height="${numStr(spec.hMm)}" fill="#fff"/>');
    } else {
      b.write('<rect width="${numStr(spec.wMm)}" '
          'height="${numStr(spec.hMm)}" fill="#fff"/>');
    }
    if (spec.bgDataUrl != null) {
      b.write('<image x="0" y="0" width="${numStr(spec.wMm)}" '
          'height="${numStr(spec.hMm)}" preserveAspectRatio="none" '
          'href="${spec.bgDataUrl}"/>');
    }
    // codes
    if (spec.twoDOn) {
      final r = spec.rects['twoD'];
      if (r != null) {
        final logo = activeLogoMm(i, t.d2);
        final s = renderSymbol(i, i.twoD, t.d2, logoSideMm: logo);
        final k = r.w / s.wMm;
        r.h = s.hMm * k; // keep true aspect
        b.write('<g transform="translate(${numStr(r.x)},${numStr(r.y)}) '
            'scale(${numStr(k)})">${s.fragment}</g>');
      }
    }
    if (spec.oneDOn) {
      final r = spec.rects['oneD'];
      if (r != null) {
        final s = renderSymbol(i, i.oneDSym, t.d1);
        final k = r.w / s.wMm;
        r.h = s.hMm * k;
        b.write('<g transform="translate(${numStr(r.x)},${numStr(r.y)}) '
            'scale(${numStr(k)})">${s.fragment}</g>');
      }
    }
    // title
    if (spec.titleOn && spec.title.isNotEmpty) {
      final r = spec.rects['title'];
      if (r != null) {
        final font = math.max(1.5, r.h / 1.4);
        b.write('<text x="${numStr(r.x + r.w / 2)}" '
            'y="${numStr(r.y + font)}" text-anchor="middle" '
            'font-family="system-ui,-apple-system,Segoe UI,sans-serif" '
            'font-weight="600" font-size="${numStr(font)}" fill="#000">'
            '${xmlEscape(spec.title)}</text>');
      }
    }
    // shared HRI
    if (spec.hriOn) {
      final r = spec.rects['hri'];
      if (r != null) {
        final font = spec.hriFontMm > 0
            ? spec.hriFontMm.clamp(0.8, 30.0)
            : math.max(1.2, math.min(3.2, r.h / 2.6));
        final cap = captionSvg(t.hri,
            cx: r.x + r.w / 2, yTop: r.y, maxWmm: r.w, fontMm: font);
        b.write(cap.svg);
      }
    }
    // dashed frame
    final showFrame = forExport ? spec.framePrinted : spec.frameShown;
    if (showFrame) {
      final sw = math.max(0.15, spec.wMm * 0.002);
      b.write(_dashedRect(sw / 2, sw / 2, spec.wMm - sw, spec.hMm - sw,
          forExport ? '#000' : '#39c1ff', sw));
    }
    // selection chrome (screen only)
    if (!forExport && selected != null && spec.on(selected)) {
      final r = spec.rects[selected];
      if (r != null) {
        const hs = 2.4; // handle size mm
        b
          ..write(_dashedRect(r.x, r.y, r.w, r.h, '#2aa6ff', 0.3))
          ..write('<rect x="${numStr(r.x + r.w - hs)}" '
              'y="${numStr(r.y + r.h - hs)}" width="$hs" height="$hs" '
              'fill="#2aa6ff"/>');
      }
    }
    return Artwork(
        svg: svgDoc(b.toString(), spec.wMm, spec.hMm),
        wMm: spec.wMm,
        hMm: spec.hMm,
        data: t.hri);
  } catch (e) {
    return Artwork(
        error:
            e is FormatException ? e.message : e.toString());
  }
}

/// The offline round-trip template: transparent canvas, dashed frame, and
/// keep-out boxes where each enabled element will land — the designer paints
/// the background to this exact size and re-imports it.
Artwork buildLabelTemplate(GenInput i, LabelSpec spec) {
  ensureArranged(i, spec);
  final b = StringBuffer();
  final sw = math.max(0.15, spec.wMm * 0.002);
  b.write(_dashedRect(
      sw / 2, sw / 2, spec.wMm - sw, spec.hMm - sw, '#000', sw));
  for (final k in labelElementKeys) {
    if (!spec.on(k)) continue;
    final r = spec.rects[k];
    if (r == null) continue;
    b
      ..write('<rect x="${numStr(r.x)}" y="${numStr(r.y)}" '
          'width="${numStr(r.w)}" height="${numStr(r.h)}" '
          'fill="rgba(0,0,0,0.06)"/>')
      ..write(_dashedRect(r.x, r.y, r.w, r.h, 'rgba(0,0,0,0.55)', sw * 0.8));
  }
  return Artwork(
      svg: svgDoc(b.toString(), spec.wMm, spec.hMm),
      wMm: spec.wMm,
      hMm: spec.hMm);
}

/// Tiles the composed label per serial across the page (label sheet).
SheetLayout layoutLabelSheet(LabelSpec spec, SerialSpec ss, SheetSpec sheet) {
  final count = ss.count.clamp(1, 2000);
  final cellW = spec.wMm, cellH = spec.hMm;
  final contentW = sheet.pageWmm - 2 * 8 - sheet.gutterMm;
  var cols = sheet.columnsOverride > 0
      ? sheet.columnsOverride
      : math.max(1, ((contentW + 3) / (cellW + 3)).floor());
  cols = math.max(1, cols);
  final continuous = sheet.page.isContinuous;
  int rows, perPage, pageCount;
  double pageHmm;
  if (continuous) {
    perPage = count;
    rows = (count / cols).ceil();
    pageCount = 1;
    pageHmm = 16 + sheet.gutterMm + rows * (cellH + 3) - 3;
  } else {
    final contentH = sheet.pageHmm - 16 - sheet.gutterMm;
    rows = math.max(1, ((contentH + 3) / (cellH + 3)).floor());
    perPage = cols * rows;
    pageCount = math.max(1, (count / perPage).ceil());
    pageHmm = sheet.pageHmm;
  }
  return SheetLayout(sheet, cellW, cellH, cols, rows, perPage, pageCount,
      continuous, sheet.pageWmm, pageHmm, count);
}

Artwork buildLabelSheetPage(
    GenInput i, LabelSpec spec, SerialSpec ss, SheetLayout L, int page,
    {int? maxCells}) {
  try {
    ensureArranged(i, spec);
    final start = L.continuous ? 0 : page * L.perPage;
    final onPage =
        L.continuous ? L.count : math.min(L.perPage, L.count - start);
    final shown = maxCells == null ? onPage : math.min(onPage, maxCells);
    final b = StringBuffer()
      ..write('<rect width="${numStr(L.pageWmm)}" '
          'height="${numStr(L.pageHmm)}" fill="#fff"/>');
    for (var k = 0; k < shown; k++) {
      final inner =
          buildLabel(i, spec, serial: ss.serialAt(start + k), forExport: true);
      if (!inner.ok) return inner;
      // strip the outer <svg …> wrapper, keep the content
      final content = inner.svg
          .replaceFirst(RegExp(r'^<svg[^>]*>'), '')
          .replaceFirst(RegExp(r'</svg>$'), '');
      final x = 8 + (k % L.cols) * (L.cellW + 3);
      final y = 8 + (k ~/ L.cols) * (L.cellH + 3);
      b.write('<g transform="translate(${numStr(x)},${numStr(y)})">'
          '$content</g>');
    }
    return Artwork(
        svg: svgDoc(b.toString(), L.pageWmm, L.pageHmm),
        wMm: L.pageWmm,
        hMm: L.pageHmm);
  } catch (e) {
    return Artwork(
        error: e is FormatException ? e.message : e.toString());
  }
}
