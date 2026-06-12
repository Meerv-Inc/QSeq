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
  LabelArrangement arrangement = LabelArrangement.sideBySide;
  double comboGap = 4;
  double comboPad = 2;
  bool comboSharedHri = true;
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
        arrangement: arrangement,
        gapMm: comboGap,
        padMm: comboPad,
        comboSharedHri: comboSharedHri,
      );

  SheetSpec get _sheet => SheetSpec(
        page: pageFormat,
        orientation: orientation,
        columnsOverride: columnsOverride,
      );

  void _set(void Function() fn) => setState(() {
        err = '';
        fn();
      });
  void _d(DataSourceInput Function(DataSourceInput) f) =>
      _set(() => data = f(data));

  // ================= build =================
  @override
  Component build(BuildContext context) {
    final i = _input;
    Artwork art;
    SheetLayout? layout;
    var shownCap = 0;
    try {
      if (mode.isLabel) {
        if (mode == WebMode.label) {
          art = lbl.buildLabel(i, labelSpec, selected: selectedEl);
        } else {
          layout = lbl.layoutLabelSheet(labelSpec, serial, _sheet);
          sheetPage = sheetPage.clamp(0, layout.pageCount - 1);
          shownCap = 24;
          art = lbl.buildLabelSheetPage(i, labelSpec, serial, layout, sheetPage,
              maxCells: shownCap);
        }
      } else if (mode.isSerialized) {
        layout = layoutSheet(i, serial, _sheet);
        sheetPage = sheetPage.clamp(0, layout.pageCount - 1);
        shownCap = 60;
        art = buildSheetPage(i, serial, layout, sheetPage, maxCells: shownCap);
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
        h2([text('Generator')]),
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
              })),
      _select(
          'Data source',
          k.name,
          const [
            ('sgtin', 'SGTIN'),
            ('nsn', 'NATO Stock Number'),
            ('rawText', 'Free text'),
          ],
          (v) => _d((d) => d.copyWith(kind: DataSourceKind.values.byName(v)))),
      if (k == DataSourceKind.sgtin) ...[
        _text('GTIN (8/12/13/14)', data.gtin,
            (v) => _d((d) => d.copyWith(gtin: v))),
        if (!mode.isSerialized)
          _text('Serial', data.serial, (v) => _d((d) => d.copyWith(serial: v))),
        if (!mode.isCombo && !mode.isLabel)
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
            !mode.isLabel &&
            data.sgtinFormat == SgtinFormat.epcTagUri)
          _num('Company prefix length', data.companyPrefixLength.toDouble(),
              (v) => _d((d) =>
                  d.copyWith(companyPrefixLength: v.round().clamp(6, 12)))),
        if (mode.isCombo ||
            mode.isLabel ||
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
      if (k == DataSourceKind.nsn)
        _text('NATO Stock Number', data.nsn,
            (v) => _d((d) => d.copyWith(nsn: v))),
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
      // combo layout
      if (mode.isCombo) ...[
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
            (v) => _set(() => comboGap = v.clamp(0, 100))),
        _check('Digital Link URL spans 1D + 2D (one shared line)',
            comboSharedHri, (v) => _set(() => comboSharedHri = v)),
        if (mode == WebMode.combo)
          _num('Outer padding (mm)', comboPad,
              (v) => _set(() => comboPad = v.clamp(0, 100))),
      ],
      // label designer
      if (mode.isLabel) ..._labelSection(i),
      // serialization
      if (mode.isSerialized) ..._serialSection(),
      // print
      div(classes: 'grid2', [
        _num('Resolution (DPI)', dpi,
            (v) => _set(() => dpi = v.clamp(36, 1200))),
        _num('X-dimension (mm)', xdim,
            (v) => _set(() => xdim = v.clamp(0.05, 5))),
      ]),
      if (mode.use1D)
        _num('Bar height (mm)', barh, (v) => _set(() => barh = v.clamp(1, 300))),
      // logo
      if (mode.use2D) ..._logoSection(i),
    ];
  }

  Component _resolvedPreview() {
    String value;
    var isError = false;
    try {
      if (mode.isLabel || mode.isCombo) {
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
          h3([text('Serialization')]),
          _text('Serial prefix (printed normal)', serial.prefix,
              (v) => _set(() {
                    serial = SerialSpec(
                        prefix: v,
                        start: serial.start,
                        count: serial.count,
                        pad: serial.pad);
                    sheetPage = 0;
                  })),
          div(classes: 'grid2', [
            _num(
                'Start (printed bold)',
                serial.start.toDouble(),
                (v) => _set(() {
                      serial = SerialSpec(
                          prefix: serial.prefix,
                          start: v.round().clamp(0, 1000000000),
                          count: serial.count,
                          pad: serial.pad);
                      sheetPage = 0;
                    })),
            _num(
                'Count',
                serial.count.toDouble(),
                (v) => _set(() {
                      serial = SerialSpec(
                          prefix: serial.prefix,
                          start: serial.start,
                          count: v.round().clamp(1, 2000),
                          pad: serial.pad);
                      sheetPage = 0;
                    })),
          ]),
          _num(
              'Zero-pad digits',
              serial.pad.toDouble(),
              (v) => _set(() {
                    serial = SerialSpec(
                        prefix: serial.prefix,
                        start: serial.start,
                        count: serial.count,
                        pad: v.round().clamp(0, 20));
                    sheetPage = 0;
                  })),
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
                  })),
        ]),
      ];

  List<Component> _logoSection(GenInput i) {
    String autoTxt = '';
    if (logoOn) {
      try {
        final t = mode.isLabel || mode.isCombo
            ? lbl.labelTexts(i).d2
            : (data.resolve().data ?? '');
        final mm = autoLogoMm(i, t);
        if (mm > 0) autoTxt = ' (≈ ${mm.toStringAsFixed(1)} mm)';
      } catch (_) {}
    }
    return [
      label(classes: 'check', [
        input(
            attributes: const {'type': 'checkbox'},
            checked: logoOn,
            onChange: (bool v) => _set(() => logoOn = v)),
        text(
            ' Reserve a centre logo dead-space — auto-sized to 15% of the error-correction capacity$autoTxt'),
      ]),
      div(classes: 'downloads', [
        button([text('Open logo image…')], classes: 'btn', onClick: _openLogo),
        button([text('Remove logo')], classes: 'btn', onClick: () => _set(() {
              logoDataUrl = null;
              logoName = '';
            })),
        span(classes: 'muted small',
            [text(logoName.isEmpty ? 'No logo image' : 'Logo: $logoName')]),
      ]),
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
              'handle to resize. The 2D carries the Digital Link URL, the 1D '
              'the GS1 element string; one shared human-readable line spans '
              'the labelSpec.')
        ]),
        div(classes: 'grid2', [
          _num('Label width (mm)', labelSpec.wMm, (v) => _set(() {
                labelSpec.wMm = v.clamp(10, 2000);
                labelSpec.rects.clear();
              })),
          _num('Label height (mm)', labelSpec.hMm, (v) => _set(() {
                labelSpec.hMm = v.clamp(10, 2000);
                labelSpec.rects.clear();
              })),
        ]),
        div(classes: 'label-toggles', [
          _check('2D code', labelSpec.twoDOn, (v) => _set(() {
                labelSpec.twoDOn = v;
                labelSpec.rects.clear();
              })),
          _check('1D barcode', labelSpec.oneDOn, (v) => _set(() {
                labelSpec.oneDOn = v;
                labelSpec.rects.clear();
              })),
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
                (v) => _set(() => sel.x = v.clamp(0, labelSpec.wMm - 1))),
            _num('Y (mm)', sel.y,
                (v) => _set(() => sel.y = v.clamp(0, labelSpec.hMm - 1))),
            _num('Width (mm)', sel.w,
                (v) => _set(() => sel.w = v.clamp(3, labelSpec.wMm))),
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
  Component _downloadButtons(Artwork art, SheetLayout? layout) {
    final ok = art.ok;
    return div(classes: 'downloads', [
      button([text('Download PNG')],
          classes: 'btn primary',
          disabled: !ok,
          onClick: () => _downloadPng(art)),
      button([text('Download PDF')],
          classes: 'btn',
          disabled: !ok,
          onClick: () => _downloadPdf(layout)),
      if (!mode.isSerialized)
        button([text('Download SVG')],
            classes: 'btn',
            disabled: !ok,
            onClick: () =>
                downloadText('qseq-code.svg', art.svg, 'image/svg+xml')),
      button([text('Save project')], classes: 'btn', onClick: _saveProject),
      button([text('Open project')], classes: 'btn', onClick: _openProject),
    ]);
  }

  Future<void> _downloadPng(Artwork art) async {
    if (!art.ok) return;
    var w = (art.wMm / 25.4 * dpi).round();
    var h = (art.hMm / 25.4 * dpi).round();
    const cap = 8000;
    final big = math.max(w, h);
    if (big > cap) {
      w = (w * cap / big).round();
      h = (h * cap / big).round();
    }
    final name = mode.isSerialized
        ? 'qseq-sheet.png'
        : (mode.isLabel ? 'qseq-labelSpec.png' : 'qseq-code.png');
    await downloadSvgPng(name, art.svg, math.max(16, w), math.max(16, h));
  }

  Future<void> _downloadPdf(SheetLayout? layout) async {
    final i = _input;
    final pages = <PdfPageImage>[];
    Future<void> addPage(Artwork a) async {
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
      if (mode.isSerialized && layout != null) {
        for (var p = 0; p < layout.pageCount; p++) {
          await addPage(mode.isLabel
              ? lbl.buildLabelSheetPage(i, labelSpec, serial, layout, p)
              : buildSheetPage(i, serial, layout, p));
        }
      } else if (mode == WebMode.label) {
        await addPage(lbl.buildLabel(i, labelSpec, forExport: true));
      } else if (mode == WebMode.combo) {
        await addPage(buildCombined(i));
      } else {
        await addPage(buildSingle(i));
      }
      final name =
          mode.isSerialized ? 'qseq-sheet.pdf' : (mode.isLabel ? 'qseq-labelSpec.pdf' : 'qseq-code.pdf');
      final saved = await savePdfPages(name, pages);
      if (!saved) {
        setState(() => err = 'PDF library still loading — try again.');
      }
    } catch (e) {
      setState(() =>
          err = e is FormatException ? e.message : e.toString());
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
      ss: serial,
      sheet: _sheet,
      label: labelSpec,
      logoSideMm: logoOn ? 1 : 0,
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
      data = p.data;
      twoD = p.twoD;
      oneDSym = p.oneD;
      ec = p.ec;
      dpi = p.dpi;
      xdim = p.xdim;
      barh = p.barh;
      logoOn = p.logoOn;
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
    final zoom =
        ((600 - rulerBandPx - 16) / artPxW).clamp(0.15, 2.5).toDouble();
    final isLabelEditor = mode == WebMode.label;
    final children = <Component>[
      div(
        styles: Styles(raw: {
          'display': 'grid',
          'grid-template-columns': '${artPxW}px ${rulerBandPx}px',
          'grid-template-rows': '${artPxH}px ${rulerBandPx}px',
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
          RawText(vRulerSvg(art.hMm, _cssPxPerMm)),
          RawText(hRulerSvg(art.wMm, _cssPxPerMm)),
          RawText(vernierSvg(_cssPxPerMm)),
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
    if (mode != WebMode.label) return;
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
    if (mode.isSerialized && layout != null) {
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
      if (mode.isLabel) {
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
      entries = mode.isSerialized
          ? serialLog(i, serial)
          : (mode.isLabel || mode.isCombo
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

  Component _select(String lbl0, String value, List<(String, String)> opts,
      void Function(String) on) {
    return label([
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
      label([text(lbl0), input(value: value, onInput: on)]);

  Component _num(String lbl0, double value, void Function(double) on) {
    return label([
      text(lbl0),
      input(
        attributes: const {'type': 'number', 'step': 'any'},
        value: _fmt(value),
        onInput: (String v) {
          final n = double.tryParse(v);
          if (n != null) on(n);
        },
      ),
    ]);
  }

  Component _check(String lbl0, bool value, void Function(bool) on) =>
      label(classes: 'check', [
        input(
            attributes: const {'type': 'checkbox'},
            checked: value,
            onChange: on),
        text(' $lbl0'),
      ]);

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
