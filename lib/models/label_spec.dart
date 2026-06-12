// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

// The label designer model: a sized label combining a 2D code (GS1 Digital
// Link), a 1D barcode (element string / NSN), a free-text title and ONE shared
// human-readable line, each with a free mm-position. Ported from the web app
// (site/lib/qseq/label.dart) — the JSON shape matches, so .qseq files made on
// either surface round-trip. Pure Dart (no Flutter): rendering lives in the
// UI / export layers.
import 'dart:math' as math;

import '../sizing/sizer.dart';
import 'data_source.dart';
import 'encode_config.dart';
import 'symbology.dart';

/// A free mm-rect for one label element.
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

  /// Background image file (desktop uses a path; the web uses a data URL and
  /// does not persist it — this field is desktop-extra in the JSON).
  String? bgImagePath;

  /// Font size of the shared HRI (Digital Link printout) in mm; 0 = auto.
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
    this.bgImagePath,
    this.hriFontMm = 0,
  });

  LabelSpec clone() {
    final c = LabelSpec(
      wMm: wMm,
      hMm: hMm,
      title: title,
      twoDOn: twoDOn,
      oneDOn: oneDOn,
      titleOn: titleOn,
      hriOn: hriOn,
      frameShown: frameShown,
      framePrinted: framePrinted,
      snap: snap,
      bgImagePath: bgImagePath,
      hriFontMm: hriFontMm,
    );
    for (final e in rects.entries) {
      c.rects[e.key] = e.value.clone();
    }
    return c;
  }

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
        if (bgImagePath != null) 'bgImagePath': bgImagePath,
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
    bgImagePath = j['bgImagePath'] as String? ?? bgImagePath;
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

/// Per-render payloads for the label: the 2D carries the Digital Link URL, the
/// 1D the element string (SGTIN) / payload (text); the shared HRI is the
/// URL once.
({String d2, String d1, String hri}) labelTexts(DataSourceInput data,
    {String? serial}) {
  switch (data.kind) {
    case DataSourceKind.sgtin:
      final d2 =
          data.encodeWith(format: SgtinFormat.digitalLink, serial: serial);
      final d1 =
          data.encodeWith(format: SgtinFormat.elementString, serial: serial);
      return (d2: d2, d1: d1, hri: d2);
    case DataSourceKind.rawText:
      final p = data.encodeWith(serial: serial);
      return (d2: p, d1: p, hri: p);
  }
}

/// Natural (sized) symbol extent in mm for layout, or null when it can't be
/// sized (bad data).
({double w, double h})? naturalLabelSymbolSize({
  required Symbology symbology,
  required String data,
  required QrEcLevel ecLevel,
  required double dpi,
  required double xDimensionMm,
  required double barHeightMm,
}) {
  try {
    final s = Sizer.compute(EncodeConfig(
      symbology: symbology,
      data: data,
      ecLevel: ecLevel,
      dpi: dpi,
      xDimensionMm: xDimensionMm,
      barHeightMm: barHeightMm,
    ));
    if (!s.fits) return null;
    return (w: s.outer.widthMm, h: s.outer.heightMm);
  } catch (_) {
    return null;
  }
}

/// Default arrangement: title across the top, 2D lower-left, 1D lower-right,
/// shared HRI spanning the bottom. Fills [spec.rects]. [n2]/[n1] are the
/// natural sizes of the enabled symbols (null = element absent).
void autoArrangeLabel(
    LabelSpec spec, ({double w, double h})? n2, ({double w, double h})? n1) {
  spec.rects.clear();
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
