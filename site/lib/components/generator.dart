// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

// The interactive QSeq generator — full desktop parity (all workspaces, logo
// dead-space + image, page-tiled serialized sheets, rulers, serialization log,
// project files, PNG/SVG/PDF) plus the label designer. @client: hydrates in
// the browser AND prerenders on the server, so the first paint is real.
import 'dart:math' as math;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:qseq_core/qseq_core.dart';
import 'package:universal_web/web.dart' as uw;

import '../qseq/download.dart';
import '../qseq/generate.dart';
import '../qseq/label.dart' as lbl;
import '../qseq/project.dart';
import '../qseq/svgkit.dart';

/// CSS pixels per millimetre (the browser's definition of `1mm`).
const double _cssPxPerMm = 96 / 25.4;

@client
class Generator extends StatefulComponent {
  const Generator({super.key});

  @override
  State<Generator> createState() => GeneratorState();
}

class GeneratorState extends State<Generator> {
  // ---- state (mirrors desktop AppSettings) ----
  WebMode mode = WebMode.twoD;
  DataSourceInput data = const DataSourceInput();
  Symbology twoD = Symbology.qrCode;
  Symbology oneDSym = Symbology.gs1_128;
  QrEcLevel ec = QrEcLevel.medium;
  double dpi = 300;
  double xdim = 0.5;
  double barh = 15;
  bool logoOn = false;
  String? logoDataUrl;
  String logoName = '';
  double logoEcShare = logoAutoEcShare; // 0.15–0.5
  bool logoManual = false;
  double logoManualMm = 10;
  LabelArrangement arrangement = LabelArrangement.sideBySide;
  double comboGap = 4;
  double comboPad = 2;
  bool comboSharedHri = true;
  bool labelOn = false; // label designer overlay (any workspace)
  int copies = 12; // sheet-of-copies count
  bool rulersOnScreen = true;
  bool rulersInPdf = false;
  SerialSpec serial = const SerialSpec();
  PageFormat pageFormat = PageFormat.letter;
  PageOrientation orientation = PageOrientation.portrait;
  int columnsOverride = 0;
  int sheetPage = 0;
  final lbl.LabelSpec labelSpec = lbl.LabelSpec();
  String? selectedEl;
  String err = '';

  GenInput get _input => GenInput(
        mode: mode,
        data: data,
        twoD: twoD,
        oneDSym: oneDSym,
        ec: ec,
        dpi: dpi,
        xdim: xdim,
        barh: barh,
        logoOn: logoOn,
        logoDataUrl: logoDataUrl,
        logoEcShare: logoEcShare,
        logoManualMm: logoManual ? logoManualMm : 0,
        arrangement: arrangement,
        gapMm: comboGap,
        padMm: comboPad,
        comboSharedHri: comboSharedHri,
      );

  SheetSpec get _sheet => SheetSpec(
        page: pageFormat,
        orientation: orientation,
        columnsOverride: columnsOverride,
        // Reserve the ruler band INSIDE the page so the printed page keeps
        // its exact standard size (an oversized page gets shrink-to-fit by
        // print drivers — measured ~3–4% small on paper).
        gutterMm: rulersInPdf ? rulerBandMm + 2 : 0,
      );

  /// The run for paged modes: a serialized spec derived from the Serial field.
  /// Its trailing digits are the incrementing counter — 6789, 6790, … — and
  /// any leading text is the fixed prefix. Sheet-of-copies workspaces
  /// increment the same way; they just take their count from Copies.
  SerialSpec get _run {
    final m = RegExp(r'^(.*?)(\d{1,12})$').firstMatch(data.serial);
    return SerialSpec(
      prefix: m == null ? data.serial : m.group(1)!,
      start: m == null ? 1 : int.parse(m.group(2)!),
      count: (mode.isCopies ? copies : serial.count).clamp(1, 2000),
      // padLeft to the typed width so leading zeros survive (0001 → 0002).
      pad: m == null ? 0 : m.group(2)!.length,
    );
  }

  void _set(void Function() fn) => setState(() {
        err = '';
        fn();
      });
  void _d(DataSourceInput Function(DataSourceInput) f) =>
      _set(() => data = f(data));

  /// The overlay shows exactly the workspace's symbols; re-arrange for them.
  void _syncLabelElements() {
    labelSpec.twoDOn = mode.use2D;
    labelSpec.oneDOn = mode.use1D;
    labelSpec.rects.clear();
  }

  // ================= build =================
  @override
  Component build(BuildContext context) {
    final i = _input;
    Artwork art;
    SheetLayout? layout;
    var shownCap = 0;
    try {
      if (labelOn) {
        if (mode.isPaged) {
          layout = lbl.layoutLabelSheet(labelSpec, _run, _sheet);
          sheetPage = sheetPage.clamp(0, layout.pageCount - 1);
          shownCap = 24;
          art = lbl.buildLabelSheetPage(i, labelSpec, _run, layout, sheetPage,
              maxCells: shownCap);
        } else {
          art = lbl.buildLabel(i, labelSpec, selected: selectedEl);
        }
      } else if (mode.isPaged) {
        layout = layoutSheet(i, _run, _sheet);
        sheetPage = sheetPage.clamp(0, layout.pageCount - 1);
        shownCap = 60;
        art = buildSheetPage(i, _run, layout, sheetPage, maxCells: shownCap);
      } else if (mode.isCombo) {
        art = buildCombined(i);
      } else {
        art = buildSingle(i);
      }
    } catch (e) {
      art = Artwork(error: e.toString());
    }
    final showErr = err.isNotEmpty ? err : (art.error ?? '');

    return section(id: 'generator', classes: 'generator', [
      div(classes: 'panel inputs', [
        h2([text('Codes & Labels App')]),
        ..._inputSections(i),
        _downloadButtons(art, layout),
        if (showErr.isNotEmpty) p(classes: 'err', [text(showErr)]),
        if (showErr.isEmpty) p(classes: 'err', []),
      ]),
      div(classes: 'panel preview', [
        _stage(art, layout, shownCap),
        _readout(i, art, layout),
      ]),
      aside(classes: 'panel log', [
        h2([text('Serialization Log')]),
        ..._logPanel(i),
      ]),
    ]);
  }

  // ================= inputs =================
  List<Component> _inputSections(GenInput i) {
    final k = data.kind;
    final resolved = _resolvedPreview();
    return [
      _select('Workspace', mode.name,
          [for (final m in WebMode.values) (m.name, m.title)], (v) => _set(() {
                mode = WebMode.values.byName(v);
                sheetPage = 0;
                selectedEl = null;
                if (labelOn) _syncLabelElements();
              })),
      _check('Label designer — lay the code(s) out on a sized label', labelOn,
          (v) => _set(() {
                labelOn = v;
                selectedEl = null;
                if (v) _syncLabelElements();
              })),
      _select(
          'Data source',
          k.name,
          const [
            ('sgtin', 'SGTIN'),
            ('rawText', 'Free text'),
          ],
          (v) => _d((d) => d.copyWith(kind: DataSourceKind.values.byName(v)))),
      if (k == DataSourceKind.sgtin) ...[
        _text('GTIN (8/12/13/14)', data.gtin,
            (v) => _d((d) => d.copyWith(gtin: v))),
        if (!mode.isSerialized)
          _text('Serial', data.serial, (v) => _d((d) => d.copyWith(serial: v))),
        if (!mode.isCombo && !labelOn)
          _select(
              'SGTIN format',
              data.sgtinFormat.name,
              const [
                ('digitalLink', 'GS1 Digital Link'),
                ('elementString', 'GS1 element string'),
                ('epcTagUri', 'EPC Tag URI'),
              ],
              (v) => _d((d) =>
                  d.copyWith(sgtinFormat: SgtinFormat.values.byName(v)))),
        if (!mode.isCombo &&
            !labelOn &&
            data.sgtinFormat == SgtinFormat.epcTagUri)
          _num('Company prefix length', data.companyPrefixLength.toDouble(),
              (v) => _d((d) =>
                  d.copyWith(companyPrefixLength: v.round().clamp(6, 12))),
              min: 6, max: 12),
        if (mode.isCombo ||
            labelOn ||
            data.sgtinFormat == SgtinFormat.digitalLink) ...[
          _select(
              'Resolver',
              _resolverPreset(data.digitalLinkDomain),
              const [
                ('https://id.gs1.org', 'GS1 · id.gs1.org'),
                ('https://tapdpp.qdat.io', 'QDat.io · tapdpp.qdat.io'),
                ('custom', 'Custom…'),
              ], (v) {
            if (v != 'custom') _d((d) => d.copyWith(digitalLinkDomain: v));
          }),
          _text('Digital Link domain', data.digitalLinkDomain,
              (v) => _d((d) => d.copyWith(digitalLinkDomain: v))),
        ],
      ],
      if (k == DataSourceKind.rawText)
        _text(mode.isSerialized ? 'Text (serial appended)' : 'Text',
            data.rawText, (v) => _d((d) => d.copyWith(rawText: v))),
      resolved,
      // symbology
      if (mode.use2D) ...[
        _select(
            '2D symbology',
            twoD.name,
            const [('qrCode', 'QR Code'), ('dataMatrix', 'Data Matrix')],
            (v) => _set(() => twoD = Symbology.values.byName(v))),
        if (twoD.supportsEcLevel)
          _select(
              'Error correction',
              ec.name,
              [
                for (final e in QrEcLevel.values)
                  (
                    e.name,
                    '${e.label} · ${(e.recoverableFraction * 100).round()}%'
                  )
              ],
              (v) => _set(() => ec = QrEcLevel.values.byName(v))),
      ],
      if (mode.use1D)
        _select(
            '1D symbology',
            oneDSym.name,
            [
              for (final s in Symbology.values.where((s) => !s.is2D))
                (s.name, s.displayName)
            ],
            (v) => _set(() => oneDSym = Symbology.values.byName(v))),
      // combo layout (the label overlay positions elements itself)
      if (mode.isCombo && !labelOn) ...[
        if (mode == WebMode.combo)
          _select(
              'Arrangement',
              arrangement.name,
              [
                for (final a in LabelArrangement.values) (a.name, a.label)
              ],
              (v) =>
                  _set(() => arrangement = LabelArrangement.values.byName(v))),
        _num('Gap between 1D & 2D (mm)', comboGap,
            (v) => _set(() => comboGap = v.clamp(0, 100)), max: 100),
        _check('Digital Link URL spans 1D + 2D (one shared line)',
            comboSharedHri, (v) => _set(() => comboSharedHri = v)),
        if (mode == WebMode.combo)
          _num('Outer padding (mm)', comboPad,
              (v) => _set(() => comboPad = v.clamp(0, 100)), max: 100),
      ],
      // label designer overlay
      if (labelOn) ..._labelSection(i),
      // paged modes: serialization run / sheet of copies + page setup
      if (mode.isPaged) ..._serialSection(),
      // print
      div(classes: 'grid2', [
        _num('Resolution (DPI)', dpi,
            (v) => _set(() => dpi = v.clamp(36, 1200)),
            min: 36, max: 1200),
        _num('X-dimension (mm)', xdim,
            (v) => _set(() => xdim = v.clamp(0.05, 5)),
            min: 0.05, max: 5),
      ]),
      if (mode.use1D)
        _num('Bar height (mm)', barh, (v) => _set(() => barh = v.clamp(1, 300)),
            min: 1, max: 300),
      // rulers
      div(classes: 'serial-block', [
        h3([text('Rulers')]),
        _check('Show rulers around the preview', rulersOnScreen,
            (v) => _set(() => rulersOnScreen = v)),
        _check('Include rulers in the PDF export', rulersInPdf,
            (v) => _set(() => rulersInPdf = v)),
      ]),
      // logo
      if (mode.use2D) ..._logoSection(i),
    ];
  }

  Component _resolvedPreview() {
    String value;
    var isError = false;
    try {
      if (labelOn || mode.isCombo) {
        value = lbl.labelTexts(_input).d2;
      } else {
        final r = data.resolve();
        isError = r.data == null;
        value = r.data ?? r.error ?? '';
      }
    } catch (e) {
      isError = true;
      value = e is FormatException ? e.message : e.toString();
    }
    return div(
        classes: 'resolved${isError ? ' bad' : ''}', [text(value)]);
  }

  List<Component> _serialSection() => [
        div(classes: 'serial-block', [
          h3([text(mode.isSerialized ? 'Serialization' : 'Sheet of copies')]),
          _text('Serial — start of serialization (counter printed bold)',
              data.serial, (v) => _set(() {
                    data = data.copyWith(serial: v);
                    sheetPage = 0;
                  })),
          p(classes: 'hint', [
            text('The trailing digits increment per item — 6789, 6790, … — '
                'and any leading text stays as a fixed prefix. Every '
                'generated identifier is listed in the Serialization Log.')
          ]),
          if (mode.isCopies)
            _num(
                'Copies (each one incremented)',
                copies.toDouble(),
                (v) => _set(() {
                      copies = v.round().clamp(1, 2000);
                      sheetPage = 0;
                    }),
                min: 1,
                max: 2000),
          if (mode.isSerialized)
            _num(
                'Count',
                serial.count.toDouble(),
                (v) => _set(() {
                      serial = SerialSpec(count: v.round().clamp(1, 2000));
                      sheetPage = 0;
                    }),
                min: 1,
                max: 2000),
          _select('Page size', pageFormat.name,
              [for (final p in PageFormat.values) (p.name, p.label)],
              (v) => _set(() {
                    pageFormat = PageFormat.values.byName(v);
                    sheetPage = 0;
                  })),
          if (!pageFormat.isContinuous)
            _select(
                'Orientation',
                orientation.name,
                const [
                  ('portrait', 'Portrait'),
                  ('landscape', 'Landscape'),
                ],
                (v) => _set(() {
                      orientation = PageOrientation.values.byName(v);
                      sheetPage = 0;
                    })),
          _num('Columns (0 = auto-fit)', columnsOverride.toDouble(),
              (v) => _set(() {
                    columnsOverride = v.round().clamp(0, 50);
                    sheetPage = 0;
                  }),
              max: 50),
        ]),
      ];

  List<Component> _logoSection(GenInput i) {
    // The EC readout for every dead-space size: the size in mm, the share of
    // the error-correction capacity it consumes, and the scanability
    // consequence.
    String sizeTxt = '';
    String noteTxt = '';
    String noteCls = 'ok';
    if (logoOn) {
      try {
        final t = labelOn || mode.isCombo
            ? lbl.labelTexts(i).d2
            : (data.resolve().data ?? '');
        final mm = activeLogoMm(i, t);
        if (mm > 0) {
          sizeTxt = 'Dead-space ≈ ${mm.toStringAsFixed(1)} mm';
          final share = logoEcShareUsed(i, t, mm);
          if (share != null) {
            sizeTxt = '$sizeTxt · uses ≈ ${(share * 100).round()}% of the '
                'symbol\'s error-correction capacity.';
            if (share >= 1) {
              noteCls = 'bad';
              noteTxt =
                  'The dead-space destroys more data than the error correction '
                  'can recover — the code will NOT scan. Shrink the dead-space '
                  'or raise the error-correction level.';
            } else if (share > 0.5) {
              noteCls = 'warn';
              noteTxt =
                  'Over half the error correction is spent on the dead-space. '
                  'A perfect print will scan, but little margin is left for '
                  'real-world damage — print defects, scuffs, fading or '
                  'curvature can make the code unreadable.';
            } else {
              noteTxt =
                  'At least half the error correction stays available to '
                  'absorb real-world damage (print defects, scuffs, fading) — '
                  'readability stays robust.';
            }
          }
        }
      } catch (_) {}
    }
    return [
      _check('Logo', logoOn, (v) => _set(() => logoOn = v)),
      if (logoOn) ...[
        _select(
            'Dead-space size',
            logoManual ? 'manual' : '${(logoEcShare * 100).round()}',
            const [
              ('15', '15% of error correction'),
              ('20', '20% of error correction'),
              ('30', '30% of error correction'),
              ('40', '40% of error correction'),
              ('50', '50% of error correction'),
              ('manual', 'Manual…'),
            ], (v) {
          _set(() {
            if (v == 'manual') {
              logoManual = true;
            } else {
              logoManual = false;
              logoEcShare = int.parse(v) / 100;
            }
          });
        }),
        if (logoManual)
          _num('Dead-space side (mm)', logoManualMm,
              (v) => _set(() => logoManualMm = v.clamp(1, 100)),
              min: 1, max: 100),
        div(classes: 'downloads', [
          button([text('Open logo image…')],
              classes: 'btn', onClick: _openLogo),
          button([text('Remove logo')], classes: 'btn',
              onClick: () => _set(() {
                    logoDataUrl = null;
                    logoName = '';
                  })),
          span(classes: 'muted small', [
            text(logoName.isEmpty ? 'No logo image' : 'Logo: $logoName')
          ]),
        ]),
        if (sizeTxt.isNotEmpty) p(classes: 'muted small', [text(sizeTxt)]),
        if (noteTxt.isNotEmpty) p(classes: 'logonote $noteCls', [text(noteTxt)]),
      ],
    ];
  }

  List<Component> _labelSection(GenInput i) {
    final wpx = (labelSpec.wMm * dpi / 25.4).round();
    final hpx = (labelSpec.hMm * dpi / 25.4).round();
    final sel = selectedEl != null ? labelSpec.rects[selectedEl] : null;
    return [
      div(classes: 'serial-block', [
        h3([text('Label')]),
        p(classes: 'hint', [
          text('Click an element to select it; drag to move, drag the corner '
              'handle to resize. The label shows this workspace\'s code(s): '
              'the 2D carries the Digital Link URL, the 1D the GS1 element '
              'string; one shared human-readable line spans the label.')
        ]),
        div(classes: 'grid2', [
          _num('Label width (mm)', labelSpec.wMm, (v) => _set(() {
                labelSpec.wMm = v.clamp(10, 2000);
                labelSpec.rects.clear();
              }), min: 10, max: 2000),
          _num('Label height (mm)', labelSpec.hMm, (v) => _set(() {
                labelSpec.hMm = v.clamp(10, 2000);
                labelSpec.rects.clear();
              }), min: 10, max: 2000),
        ]),
        div(classes: 'label-toggles', [
          _check('Title', labelSpec.titleOn, (v) => _set(() {
                labelSpec.titleOn = v;
                labelSpec.rects.clear();
              })),
          _check('Shared text (HRI)', labelSpec.hriOn, (v) => _set(() {
                labelSpec.hriOn = v;
                labelSpec.rects.clear();
              })),
        ]),
        _text('Title text', labelSpec.title,
            (v) => _set(() => labelSpec.title = v)),
        if (labelSpec.hriOn)
          _num('HRI font size (mm, 0 = auto)', labelSpec.hriFontMm,
              (v) => _set(() => labelSpec.hriFontMm = v.clamp(0, 30)),
              max: 30),
        div(classes: 'label-toggles', [
          _check('Show label frame', labelSpec.frameShown,
              (v) => _set(() => labelSpec.frameShown = v)),
          _check('Print frame (cut guide)', labelSpec.framePrinted,
              (v) => _set(() => labelSpec.framePrinted = v)),
          _check('Snap to grid', labelSpec.snap,
              (v) => _set(() => labelSpec.snap = v)),
        ]),
        if (sel != null)
          div(classes: 'grid3', [
            _num('$selectedEl X (mm)', sel.x,
                (v) => _set(() => sel.x = v.clamp(0, labelSpec.wMm - 1)),
                max: labelSpec.wMm - 1),
            _num('Y (mm)', sel.y,
                (v) => _set(() => sel.y = v.clamp(0, labelSpec.hMm - 1)),
                max: labelSpec.hMm - 1),
            _num('Width (mm)', sel.w,
                (v) => _set(() => sel.w = v.clamp(3, labelSpec.wMm)),
                min: 3, max: labelSpec.wMm),
          ]),
        div(classes: 'downloads', [
          button([text('Auto-arrange')], classes: 'btn',
              onClick: () => _set(() => labelSpec.rects.clear())),
          button([text('Export label template')],
              classes: 'btn', onClick: _exportTemplate),
        ]),
        div(classes: 'downloads', [
          button([text('Import background…')],
              classes: 'btn', onClick: _importBg),
          button([text('Remove background')], classes: 'btn',
              onClick: () => _set(() => labelSpec.bgDataUrl = null)),
        ]),
        p(classes: 'muted small', [
          text(labelSpec.bgDataUrl != null
              ? 'Background loaded — design at $wpx × $hpx px '
                  '(${numStr(labelSpec.wMm)}×${numStr(labelSpec.hMm)} mm @ ${dpi.toInt()} DPI).'
              : 'Round-trip: export the template, paint your background at '
                  '$wpx × $hpx px (${numStr(labelSpec.wMm)}×${numStr(labelSpec.hMm)} mm '
                  '@ ${dpi.toInt()} DPI), then import it — QSeq overlays the '
                  'codes on top.')
        ]),
      ]),
    ];
  }

  // ================= downloads =================
  // Export progress: a label + bar shown while a download is being prepared
  // (multi-page PDFs and big rasters take seconds). busyFrac < 0 renders an
  // indeterminate sweep.
  String? busyLabel;
  double busyFrac = -1;

  /// Updates the progress UI and yields a macrotask so the browser paints it
  /// before the next CPU-heavy render step.
  Future<void> _busy(String label, [double frac = -1]) async {
    setState(() {
      busyLabel = label;
      busyFrac = frac;
    });
    await Future<void>.delayed(const Duration(milliseconds: 18));
  }

  void _busyDone() => setState(() => busyLabel = null);

  Component _downloadButtons(Artwork art, SheetLayout? layout) {
    final ok = art.ok && busyLabel == null;
    return Component.fragment([
      div(classes: 'downloads', [
        button([text('Download PNG')],
            classes: 'btn primary',
            disabled: !ok,
            onClick: () => _downloadPng(art, layout)),
        button([text('Download PDF')],
            classes: 'btn',
            disabled: !ok,
            onClick: () => _downloadPdf(layout)),
        if (!mode.isPaged)
          button([text('Download SVG')],
              classes: 'btn',
              disabled: !ok,
              onClick: () =>
                  downloadText('qseq-code.svg', art.svg, 'image/svg+xml')),
        button([text('Save project')], classes: 'btn', onClick: _saveProject),
        button([text('Open project')], classes: 'btn', onClick: _openProject),
      ]),
      if (busyLabel != null)
        div(classes: 'progress', [
          div(classes: 'plabel', [text(busyLabel!)]),
          div(classes: 'pbar', [
            div(const [],
                classes: 'pfill${busyFrac < 0 ? ' indet' : ''}',
                styles: busyFrac < 0
                    ? null
                    : Styles(raw: {
                        'width':
                            '${(busyFrac * 100).clamp(0, 100).toStringAsFixed(1)}%'
                      })),
          ]),
        ]),
    ]);
  }

  Future<void> _downloadPng(Artwork art, SheetLayout? layout) async {
    if (busyLabel != null) return;
    try {
      await _busy('Preparing PNG…', 0.1);
      var a = art;
      // The on-screen preview caps how many cells it renders; re-render the
      // current page in full for the export.
      if (mode.isPaged && layout != null) {
        a = labelOn
            ? lbl.buildLabelSheetPage(
                _input, labelSpec, _run, layout, sheetPage)
            : buildSheetPage(_input, _run, layout, sheetPage);
      }
      if (!a.ok) return;
      var w = (a.wMm / 25.4 * dpi).round();
      var h = (a.hMm / 25.4 * dpi).round();
      const cap = 8000;
      final big = math.max(w, h);
      if (big > cap) {
        w = (w * cap / big).round();
        h = (h * cap / big).round();
      }
      final name = mode.isPaged
          ? 'qseq-sheet.png'
          : (labelOn ? 'qseq-label.png' : 'qseq-code.png');
      await _busy('Rasterizing $w × $h px…', 0.5);
      await downloadSvgPng(name, a.svg, math.max(16, w), math.max(16, h));
    } finally {
      _busyDone();
    }
  }

  Future<void> _downloadPdf(SheetLayout? layout) async {
    if (busyLabel != null) return;
    final i = _input;
    final pages = <PdfPageImage>[];
    Future<void> addPage(Artwork a0) async {
      // Sheets keep their standard page size and draw rulers in the reserved
      // gutter; single codes grow the (paper-smaller) page by the band.
      final a = !rulersInPdf
          ? a0
          : (mode.isPaged && layout != null
              ? withPrintRulersInside(a0)
              : withPrintRulers(a0));
      if (!a.ok) throw FormatException(a.error ?? 'render failed');
      var w = (a.wMm / 25.4 * dpi).round();
      var h = (a.hMm / 25.4 * dpi).round();
      const cap = 6000;
      final big = math.max(w, h);
      if (big > cap) {
        w = (w * cap / big).round();
        h = (h * cap / big).round();
      }
      final url = await rasterizeSvg(a.svg, math.max(16, w), math.max(16, h));
      if (url == null) throw const FormatException('rasterize failed');
      pages.add(PdfPageImage(a.wMm, a.hMm, url));
    }

    try {
      if (mode.isPaged && layout != null) {
        for (var p = 0; p < layout.pageCount; p++) {
          await _busy(
              'Preparing PDF — page ${p + 1} of ${layout.pageCount}…',
              p / layout.pageCount);
          await addPage(labelOn
              ? lbl.buildLabelSheetPage(i, labelSpec, _run, layout, p)
              : buildSheetPage(i, _run, layout, p));
        }
      } else {
        await _busy('Preparing PDF…', 0.3);
        if (labelOn) {
          await addPage(lbl.buildLabel(i, labelSpec, forExport: true));
        } else if (mode == WebMode.combo) {
          await addPage(buildCombined(i));
        } else {
          await addPage(buildSingle(i));
        }
      }
      await _busy('Assembling PDF…', 0.97);
      final name = mode.isPaged
          ? 'qseq-sheet.pdf'
          : (labelOn ? 'qseq-label.pdf' : 'qseq-code.pdf');
      final saved = await savePdfPages(name, pages, (done, total) {
        // Keep the tab responsive and show real progress while jsPDF ingests
        // each page of a large serialized sheet.
        if (total > 1) {
          setState(() {
            busyLabel = 'Assembling PDF — page $done of $total…';
            busyFrac = done / total;
          });
        }
      });
      if (!saved) {
        setState(() => err = 'PDF library still loading — try again.');
      }
    } catch (e) {
      final s = e.toString();
      final tooBig = e is RangeError ||
          s.toLowerCase().contains('string length') ||
          s.toLowerCase().contains('array length') ||
          s.toLowerCase().contains('allocation');
      setState(() => err = e is FormatException
          ? e.message
          : tooBig
              ? 'This sheet is too large to build as a single PDF in the '
                  'browser. Use fewer codes per sheet or a lower DPI, then '
                  'export again.'
              : s);
    } finally {
      _busyDone();
    }
  }

  Future<void> _exportTemplate() async {
    final a = lbl.buildLabelTemplate(_input, labelSpec);
    final w = (a.wMm / 25.4 * dpi).round();
    final h = (a.hMm / 25.4 * dpi).round();
    final url = await rasterizeSvg(a.svg, w, h, transparent: true);
    if (url != null) {
      // re-download via anchor: rasterizeSvg gives a data URL
      downloadText('qseq-label-template.svg', a.svg, 'image/svg+xml');
      await downloadSvgPng('qseq-label-template.png', a.svg, w, h);
    } else {
      downloadText('qseq-label-template.svg', a.svg, 'image/svg+xml');
    }
  }

  Future<void> _importBg() async {
    final url = await pickFile(accept: 'image/*');
    if (url != null) _set(() => labelSpec.bgDataUrl = url);
  }

  Future<void> _openLogo() async {
    final url = await pickFile(accept: 'image/*');
    if (url != null) {
      _set(() {
        logoDataUrl = url;
        logoOn = true;
        logoName = 'image';
      });
    }
  }

  void _saveProject() {
    final json = projectJson(
      i: _input,
      ss: _run,
      sheet: _sheet,
      label: labelSpec,
      logoSideMm: logoOn ? 1 : 0,
      labelOn: labelOn,
      copies: copies,
    );
    downloadText('design.qseq', json, 'application/json');
  }

  Future<void> _openProject() async {
    final text = await pickFile(
        accept: '.qseq,.json,application/json', asText: true);
    if (text == null) return;
    final p = parseProject(text);
    if (p == null) {
      setState(() => err = 'Could not read that project file.');
      return;
    }
    _set(() {
      mode = p.mode;
      labelOn = p.labelOn;
      copies = p.copies;
      data = p.data;
      twoD = p.twoD;
      oneDSym = p.oneD;
      ec = p.ec;
      dpi = p.dpi;
      xdim = p.xdim;
      barh = p.barh;
      logoOn = p.logoOn;
      logoEcShare = p.logoEcShare;
      logoManual = p.logoManualMm > 0;
      if (p.logoManualMm > 0) logoManualMm = p.logoManualMm;
      arrangement = p.arrangement;
      comboGap = p.gapMm;
      comboPad = p.padMm;
      comboSharedHri = p.comboSharedHri;
      serial = p.serial;
      pageFormat = p.sheet.page;
      orientation = p.sheet.orientation;
      columnsOverride = p.sheet.columnsOverride;
      sheetPage = 0;
      if (p.labelJson != null) labelSpec.applyJson(p.labelJson!);
    });
  }

  // ================= preview stage =================
  Component _stage(Artwork art, SheetLayout? layout, int shownCap) {
    if (!art.ok) {
      return div(classes: 'stage', [
        div(classes: 'card', [p([text('—')])])
      ]);
    }
    // Fit: scale the css-mm artwork so (artwork + rulers) ≈ 600px wide.
    final artPxW = art.wMm * _cssPxPerMm;
    final artPxH = art.hMm * _cssPxPerMm;
    final band = rulersOnScreen ? rulerBandPx : 0;
    final zoom = ((600 - band - 16) / artPxW).clamp(0.15, 2.5).toDouble();
    final isLabelEditor = labelOn && !mode.isPaged;
    final children = <Component>[
      div(
        styles: Styles(raw: {
          'display': 'grid',
          'grid-template-columns':
              '${artPxW}px${rulersOnScreen ? ' ${rulerBandPx}px' : ''}',
          'grid-template-rows':
              '${artPxH}px${rulersOnScreen ? ' ${rulerBandPx}px' : ''}',
          'gap': '14px',
          'background': '#fff',
          'padding': '8px',
          'border-radius': '8px',
        }),
        [
          div(
            id: 'artwork',
            styles: isLabelEditor
                ? const Styles(raw: {'touch-action': 'none', 'cursor': 'grab'})
                : null,
            events: isLabelEditor
                ? {
                    'pointerdown': (uw.Event e) => _labelPointer(e, 0),
                    'pointermove': (uw.Event e) => _labelPointer(e, 1),
                    'pointerup': (uw.Event e) => _labelPointer(e, 2),
                    'pointercancel': (uw.Event e) => _labelPointer(e, 2),
                  }
                : null,
            [RawText(art.svg)],
          ),
          if (rulersOnScreen) ...[
            RawText(vRulerSvg(art.hMm, _cssPxPerMm)),
            RawText(hRulerSvg(art.wMm, _cssPxPerMm)),
            RawText(vernierSvg(_cssPxPerMm)),
          ],
        ],
      ),
    ];
    final pageTabs = <Component>[];
    if (layout != null) {
      final onPage = layout.continuous
          ? layout.count
          : math.min(layout.perPage, layout.count - sheetPage * layout.perPage);
      if (shownCap > 0 && onPage > shownCap) {
        pageTabs.add(p(classes: 'cap muted small', [
          text('Showing first $shownCap of $onPage on this page · '
              'all ${layout.count} export to PDF')
        ]));
      }
      if (layout.continuous) {
        pageTabs.add(div(classes: 'pagetabs', [
          span(classes: 'pageinfo', [
            text('${layout.spec.page.label} · ${layout.count} '
                'code${layout.count > 1 ? 's' : ''} on one endless page')
          ])
        ]));
      } else if (layout.pageCount > 1) {
        pageTabs.add(div(classes: 'pagetabs', [
          span(classes: 'pageinfo',
              [text('${layout.spec.page.label} · ${layout.pageCount} pages')]),
          for (var p = 0; p < layout.pageCount; p++)
            button([text('${p + 1}')],
                classes: 'ptab${p == sheetPage ? ' active' : ''}',
                onClick: () => _set(() => sheetPage = p)),
        ]));
      }
    }
    return div(classes: 'stage', [
      div(
          classes: 'card',
          styles: Styles(raw: {'zoom': zoom.toStringAsFixed(3)}),
          children),
      ...pageTabs,
    ]);
  }

  // ---- label drag (0=down, 1=move, 2=up) ----
  String? _dragKey;
  bool _dragResize = false;
  double _grabDx = 0, _grabDy = 0;

  void _labelPointer(uw.Event e, int phase) {
    if (!labelOn || mode.isPaged) return;
    final me = e as uw.MouseEvent;
    final target = e.currentTarget as uw.Element?;
    if (target == null) return;
    final rect = target.getBoundingClientRect();
    // The wrapper is inside a zoomed card: rect already reflects the zoom.
    final sx = rect.width / labelSpec.wMm;
    final sy = rect.height / labelSpec.hMm;
    if (sx <= 0 || sy <= 0) return;
    final mx = (me.clientX - rect.left) / sx;
    final my = (me.clientY - rect.top) / sy;
    if (phase == 0) {
      e.preventDefault();
      String? hit;
      for (final k in const ['title', 'hri', 'twoD', 'oneD']) {
        if (!labelSpec.on(k)) continue;
        final r = labelSpec.rects[k];
        if (r == null) continue;
        if (mx >= r.x && mx <= r.x + r.w && my >= r.y && my <= r.y + r.h) {
          hit = k;
          break;
        }
      }
      _dragKey = hit;
      _dragResize = false;
      if (hit != null) {
        final r = labelSpec.rects[hit]!;
        final tol = math.max(2.5, 14 / sx);
        _dragResize = (mx - (r.x + r.w)).abs() <= tol &&
            (my - (r.y + r.h)).abs() <= tol;
        _grabDx = mx - r.x;
        _grabDy = my - r.y;
      }
      setState(() => selectedEl = hit);
    } else if (phase == 1) {
      final k = _dragKey;
      if (k == null) return;
      final r = labelSpec.rects[k];
      if (r == null) return;
      e.preventDefault();
      setState(() {
        if (_dragResize) {
          var nw = math.max(3.0, mx - r.x);
          if (labelSpec.snap) nw = nw.roundToDouble();
          r.w = math.min(nw, labelSpec.wMm - r.x);
        } else {
          var nx = mx - _grabDx;
          var ny = my - _grabDy;
          if (labelSpec.snap) {
            nx = nx.roundToDouble();
            ny = ny.roundToDouble();
          }
          const sn = 1.6;
          if (nx.abs() < sn) nx = 0;
          if ((nx + r.w - labelSpec.wMm).abs() < sn) nx = labelSpec.wMm - r.w;
          if ((nx + r.w / 2 - labelSpec.wMm / 2).abs() < sn) {
            nx = labelSpec.wMm / 2 - r.w / 2;
          }
          if (ny.abs() < sn) ny = 0;
          if ((ny + r.h - labelSpec.hMm).abs() < sn) ny = labelSpec.hMm - r.h;
          r.x = nx.clamp(0, math.max(0, labelSpec.wMm - r.w));
          r.y = ny.clamp(0, math.max(0, labelSpec.hMm - r.h));
        }
      });
    } else {
      _dragKey = null;
    }
  }

  // ================= readout =================
  Component _readout(GenInput i, Artwork art, SheetLayout? layout) {
    final cells = <Component>[];
    void kv(String k, String v) => cells.add(div([
          div(classes: 'k', [text(k)]),
          div(classes: 'v', [text(v)]),
        ]));
    void full(String cls, String t) =>
        cells.add(div(classes: 'full $cls', [text(t)]));

    if (!art.ok) {
      full('bad', art.error ?? '—');
      return div(classes: 'readout', cells);
    }
    final wIn = art.wMm / 25.4, hIn = art.hMm / 25.4;
    if (mode.isPaged && layout != null) {
      kv('Page', '${numStr(layout.pageWmm)} × ${layout.continuous ? '∞' : numStr(layout.pageHmm)} mm');
      kv('Cell',
          '${layout.cellW.toStringAsFixed(1)} × ${layout.cellH.toStringAsFixed(1)} mm');
      kv('Grid',
          '${layout.cols} col${layout.cols > 1 ? 's' : ''} · ${layout.pageCount} page${layout.pageCount > 1 ? 's' : ''}');
      kv('Codes', '${layout.count}');
    } else {
      kv('Outer size',
          '${art.wMm.toStringAsFixed(1)} × ${art.hMm.toStringAsFixed(1)} mm');
      kv('', '${wIn.toStringAsFixed(2)} × ${hIn.toStringAsFixed(2)} in');
      kv('At ${dpi.toInt()} DPI',
          '${(art.wMm / 25.4 * dpi).round()} × ${(art.hMm / 25.4 * dpi).round()} px');
      final s = art.size;
      if (s != null) {
        kv('Geometry', s.geometryLabel);
        kv(
            'Bytes',
            s.bytesCapacity != null
                ? '${s.bytesRequested} / ${s.bytesCapacity}'
                : '${s.bytesRequested}');
        final b = s.logoBudget;
        if (b != null && logoOn) {
          full(
              b.fits ? 'ok' : 'bad',
              'Logo ${(b.logoAreaFraction * 100).toStringAsFixed(1)}% of '
              '${(b.budgetFraction * 100).toStringAsFixed(1)}% budget · '
              'max safe ≈ ${b.maxSafeLogoMm.toStringAsFixed(1)} mm '
              '${b.fits ? '✓' : '✗'}');
        }
        for (final w in s.warnings) {
          full('warn', w);
        }
        full('',
            'Module ${s.moduleDots} dots @ ${dpi.toInt()} DPI · print at ${dpi.toInt()} DPI for exact size');
      }
      if (labelOn) {
        full('',
            '2D → Digital Link URL · 1D → GS1 element string · one shared HRI');
      }
    }
    return div(classes: 'readout', cells);
  }

  // ================= serialization log =================
  List<Component> _logPanel(GenInput i) {
    List<String> entries;
    try {
      entries = mode.isPaged
          ? serialLog(i, _run)
          : (labelOn || mode.isCombo
              ? [lbl.labelTexts(i).d2]
              : [data.resolve().data ?? '']);
      entries = entries.where((e) => e.isNotEmpty).toList();
    } catch (_) {
      entries = [];
    }
    if (entries.isEmpty) {
      return [
        p(classes: 'muted small', [text('')]),
        div(classes: 'loglist', [
          div(classes: 'empty', [text('No codes.')])
        ]),
      ];
    }
    const renderCap = 300;
    final shown = entries.take(renderCap).toList();
    final w = '${entries.length}'.length;
    return [
      p(classes: 'muted small', [
        text('${entries.length} code${entries.length > 1 ? 's' : ''} · '
            'full encoded link'
            '${entries.length > renderCap ? ' · showing first $renderCap' : ''}')
      ]),
      div(classes: 'loglist scrolly', [
        for (var n = 0; n < shown.length; n++)
          div(classes: 'row', [
            span(classes: 'n', [text('${n + 1}'.padLeft(w))]),
            if (shown[n].startsWith('http'))
              a(href: shown[n], target: Target.blank, [text(shown[n])])
            else
              span([text(shown[n])]),
          ]),
      ]),
    ];
  }

  // ================= small control helpers =================
  static const _knownResolvers = {
    'https://id.gs1.org',
    'https://tapdpp.qdat.io',
  };
  String _resolverPreset(String domain) =>
      _knownResolvers.contains(domain) ? domain : 'custom';

  // Every control is keyed by its label: unkeyed positional diffing would
  // re-purpose a DOM element for a *different* control when the surrounding
  // list changes (e.g. switching workspaces re-purposed the "SGTIN format"
  // <select> as the "Resolver" one, leaving it with no selection).
  Component _select(String lbl0, String value, List<(String, String)> opts,
      void Function(String) on) {
    return label(key: ValueKey('ctl-$lbl0'), [
      text(lbl0),
      select(
        [
          for (final o in opts)
            option([text(o.$2)], value: o.$1, selected: o.$1 == value)
        ],
        value: value,
        onInput: (v) {
          if (v.isNotEmpty) on(v.first);
        },
      ),
    ]);
  }

  Component _text(String lbl0, String value, void Function(String) on) =>
      label(key: ValueKey('ctl-$lbl0'),
          [text(lbl0), input(value: value, onInput: on)]);

  Component _num(String lbl0, double value, void Function(double) on,
      {double min = 0, double max = 1000000000}) {
    return label(key: ValueKey('ctl-$lbl0'), [
      text(lbl0),
      input(
        attributes: const {'type': 'number', 'step': 'any'},
        value: _fmt(value),
        // Jaspr decodes the input event by the DOM type: number inputs deliver
        // a num (NaN while the field is empty/partial), not a String.
        // Live-update only changed, in-range values — updating state mid-typing
        // re-renders and overwrites the half-typed text (e.g. "6…00" would
        // clamp to 36 before the user finishes typing 600).
        onInput: (num v) {
          final d = v.toDouble();
          if (!d.isNaN && d != value && d >= min && d <= max) on(d);
        },
        // Commit on blur/Enter: clamp out-of-range input, restore the last
        // value if the field was left empty.
        onChange: (num v) {
          final d = v.toDouble();
          on(d.isNaN ? value : d.clamp(min, max));
        },
      ),
    ]);
  }

  Component _check(String lbl0, bool value, void Function(bool) on) =>
      label(key: ValueKey('ctl-$lbl0'), classes: 'check', [
        input(
            attributes: const {'type': 'checkbox'},
            checked: value,
            onChange: on),
        text(' $lbl0'),
      ]);

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
