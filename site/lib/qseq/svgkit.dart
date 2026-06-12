// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

// Pure-Dart SVG building blocks shared by the single/combined/sheet/label
// composers: XML escaping, monospace wrapping, HRI captions with a bold
// counter, and the mm/inch/vernier rulers. Everything is in millimetre user
// units unless stated otherwise.

String xmlEscape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Wraps [text] to lines of at most [maxChars] characters (monospace model).
List<String> wrapMono(String text, int maxChars) {
  if (maxChars < 4) maxChars = 4;
  final lines = <String>[];
  var rest = text;
  while (rest.length > maxChars) {
    lines.add(rest.substring(0, maxChars));
    rest = rest.substring(maxChars);
  }
  lines.add(rest);
  return lines;
}

/// Approximate advance width of one monospace character, as a fraction of the
/// font size. ui-monospace/Menlo measure ≈ 0.60–0.62 em.
const double monoCharEm = 0.62;

/// An HRI caption: [text] wrapped and centred at [cx], starting [yTop] mm down,
/// constrained to [maxWmm]. Characters from [boldFrom] (index into [text]) to
/// the end render bold — the incrementing counter convention. Pass -1 for no
/// bold segment. Returns the SVG fragment and its height in mm.
({String svg, double heightMm}) captionSvg(
  String text, {
  required double cx,
  required double yTop,
  required double maxWmm,
  double fontMm = 2.2,
  int boldFrom = -1,
}) {
  if (text.isEmpty) return (svg: '', heightMm: 0);
  final charW = fontMm * monoCharEm;
  final maxChars = ((maxWmm - 0.5) / charW).floor();
  final lines = wrapMono(text, maxChars);
  final lineH = fontMm * 1.3;
  final b = StringBuffer();
  var consumed = 0;
  var y = yTop + fontMm; // first baseline
  for (final line in lines) {
    final start = consumed;
    final end = consumed + line.length;
    consumed = end;
    b.write('<text x="${_n(cx)}" y="${_n(y)}" text-anchor="middle" '
        'font-family="ui-monospace,Menlo,Consolas,monospace" '
        'font-size="${_n(fontMm)}" fill="#000">');
    if (boldFrom < 0 || boldFrom >= end) {
      b.write(xmlEscape(line));
    } else if (boldFrom <= start) {
      b.write('<tspan font-weight="bold">${xmlEscape(line)}</tspan>');
    } else {
      final cut = boldFrom - start;
      b
        ..write(xmlEscape(line.substring(0, cut)))
        ..write('<tspan font-weight="bold">'
            '${xmlEscape(line.substring(cut))}</tspan>');
    }
    b.write('</text>');
    y += lineH;
  }
  return (svg: b.toString(), heightMm: lines.length * lineH + 0.6);
}

String _n(double v) {
  final r = (v * 1000).round() / 1000;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
}

String numStr(double v) => _n(v);

// ---- rulers -----------------------------------------------------------------
// Display-pixel SVGs (not mm units): the preview shows the artwork at
// [pxPerMm], so the rulers mark true millimetres/inches at that same scale.
// Mirrors the previous web app's rulerSVG/vernierSVG.

const double rulerBandPx = 44;

String hRulerSvg(double lengthMm, double pxPerMm) =>
    _ruler(lengthMm, pxPerMm, horizontal: true);
String vRulerSvg(double lengthMm, double pxPerMm) =>
    _ruler(lengthMm, pxPerMm, horizontal: false);

String _ruler(double lengthMm, double s, {required bool horizontal}) {
  final lenPx = lengthMm * s;
  final w = horizontal ? lenPx : rulerBandPx;
  final h = horizontal ? rulerBandPx : lenPx;
  final b = StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" '
      'width="${_n(w)}" height="${_n(h)}">');
  void ln(double x1, double y1, double x2, double y2, double sw) =>
      b.write('<line x1="${_n(x1)}" y1="${_n(y1)}" x2="${_n(x2)}" '
          'y2="${_n(y2)}" stroke="#111" stroke-width="$sw"/>');
  void tx(double x, double y, String t) =>
      b.write('<text x="${_n(x)}" y="${_n(y)}" font-size="9" '
          'font-family="monospace" fill="#111">${xmlEscape(t)}</text>');
  // mm ticks along the leading edge
  final mmN = lengthMm.floor();
  for (var i = 0; i <= mmN; i++) {
    final p = i * s;
    final maj = i % 10 == 0, med = i % 5 == 0;
    final tick = maj ? 13.0 : (med ? 8.0 : 4.0);
    final sw = maj ? 1.1 : 0.6;
    if (horizontal) {
      ln(p, 0, p, tick, sw);
      if (maj && i > 0) tx(p + 1.5, 22, '$i');
    } else {
      ln(0, p, tick, p, sw);
      if (maj && i > 0) tx(1.5, p + 10, '$i');
    }
  }
  tx(1.5, horizontal ? 11 : 9, 'mm');
  // 1/16-inch ticks along the trailing edge
  final sixteenth = s * 25.4 / 16;
  final sN = (lenPx / sixteenth).floor();
  for (var j = 0; j <= sN; j++) {
    final p = j * sixteenth;
    final maj = j % 16 == 0, half = j % 8 == 0, q = j % 4 == 0;
    final tick = maj ? 13.0 : (half ? 9.0 : (q ? 6.0 : 3.0));
    final sw = maj ? 1.1 : 0.6;
    if (horizontal) {
      ln(p, rulerBandPx - tick, p, rulerBandPx, sw);
      if (maj && j > 0) tx(p + 1.5, rulerBandPx - 15, '${j ~/ 16}"');
    } else {
      ln(rulerBandPx - tick, p, rulerBandPx, p, sw);
      if (maj && j > 0) tx(rulerBandPx - 20, p + 10, '${j ~/ 16}"');
    }
  }
  b.write('</svg>');
  return b.toString();
}

// ---- print rulers (mm units) -------------------------------------------------
// Fragment versions of the rulers in millimetre user units, for composing into
// exported artwork (PDF pages). Drawn at (0,0); the horizontal band runs along
// x, the vertical along y. Same mm/inch/tick layout as the screen rulers.

/// Depth of a print ruler band in mm (≈ the screen band at preview scale).
const double rulerBandMm = 9;

String rulerMmFragment(double lengthMm, {required bool horizontal}) {
  final b = StringBuffer();
  void ln(double x1, double y1, double x2, double y2, double sw) =>
      b.write('<line x1="${_n(x1)}" y1="${_n(y1)}" x2="${_n(x2)}" '
          'y2="${_n(y2)}" stroke="#111" stroke-width="${_n(sw)}"/>');
  void tx(double x, double y, String t) =>
      b.write('<text x="${_n(x)}" y="${_n(y)}" font-size="1.9" '
          'font-family="monospace" fill="#111">${xmlEscape(t)}</text>');
  // mm ticks along the leading edge
  final mmN = lengthMm.floor();
  for (var i = 0; i <= mmN; i++) {
    final p = i.toDouble();
    final maj = i % 10 == 0, med = i % 5 == 0;
    final tick = maj ? 2.8 : (med ? 1.8 : 1.0);
    final sw = maj ? 0.22 : 0.12;
    if (horizontal) {
      ln(p, 0, p, tick, sw);
      if (maj && i > 0) tx(p + 0.4, 4.6, '$i');
    } else {
      ln(0, p, tick, p, sw);
      if (maj && i > 0) tx(0.4, p + 2.1, '$i');
    }
  }
  tx(0.4, horizontal ? 2.3 : 1.9, 'mm');
  // 1/16-inch ticks along the trailing edge
  const sixteenth = 25.4 / 16;
  final sN = (lengthMm / sixteenth).floor();
  for (var j = 0; j <= sN; j++) {
    final p = j * sixteenth;
    final maj = j % 16 == 0, half = j % 8 == 0, q = j % 4 == 0;
    final tick = maj ? 2.8 : (half ? 1.9 : (q ? 1.3 : 0.7));
    final sw = maj ? 0.22 : 0.12;
    if (horizontal) {
      ln(p, rulerBandMm - tick, p, rulerBandMm, sw);
      if (maj && j > 0) tx(p + 0.4, rulerBandMm - 3.1, '${j ~/ 16}"');
    } else {
      ln(rulerBandMm - tick, p, rulerBandMm, p, sw);
      if (maj && j > 0) tx(rulerBandMm - 4.4, p + 2.1, '${j ~/ 16}"');
    }
  }
  return b.toString();
}

/// Vernier corner in mm units: 10 divisions over 9 mm → 0.1 mm reading.
String vernierMmFragment() {
  final b = StringBuffer();
  const x0 = 0.5, y0 = 1.8, u = 0.9;
  b.write('<line x1="$x0" y1="$y0" x2="${_n(x0 + 10 * u)}" y2="$y0" '
      'stroke="#111" stroke-width="0.22"/>');
  for (var k = 0; k <= 10; k++) {
    b.write('<line x1="${_n(x0 + k * u)}" y1="$y0" x2="${_n(x0 + k * u)}" '
        'y2="${_n(y0 + 1.3)}" stroke="#111" '
        'stroke-width="${k % 5 == 0 ? 0.22 : 0.1}"/>');
  }
  b.write('<text x="0.5" y="${_n(rulerBandMm - 0.8)}" font-size="1.4" '
      'font-family="monospace" fill="#111">vern 0.1mm</text>');
  return b.toString();
}

/// Vernier corner block: 10 divisions over 9 mm → 0.1 mm reading.
String vernierSvg(double pxPerMm) {
  const band = rulerBandPx;
  final b = StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" '
      'width="$band" height="$band">');
  final scale =
      (band - 6) / (9 * pxPerMm) < 1 ? (band - 6) / (9 * pxPerMm) : 1.0;
  const x0 = 2.0, y0 = 8.0;
  final u = 0.9 * pxPerMm * scale;
  b.write('<line x1="$x0" y1="$y0" x2="${_n(x0 + 10 * u)}" y2="$y0" '
      'stroke="#111" stroke-width="1.1"/>');
  for (var k = 0; k <= 10; k++) {
    b.write('<line x1="${_n(x0 + k * u)}" y1="$y0" x2="${_n(x0 + k * u)}" '
        'y2="${_n(y0 + 6)}" stroke="#111" '
        'stroke-width="${k % 5 == 0 ? 1.1 : 0.5}"/>');
  }
  b.write('<text x="2" y="${band - 4}" font-size="7" '
      'font-family="monospace" fill="#111">vern 0.1mm</text></svg>');
  return b.toString();
}
