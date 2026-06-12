// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:qseq_core/qseq_core.dart';

import '../qseq/download.dart';
import '../qseq/generate.dart';

/// The interactive QSeq generator. Marked @client so it hydrates in the browser,
/// but because the encode+render path is pure Dart it also pre-renders on the
/// server, so the first paint already shows a real symbol.
@client
class Generator extends StatefulComponent {
  const Generator({super.key});

  @override
  State<Generator> createState() => GeneratorState();
}

class GeneratorState extends State<Generator> {
  DataSourceInput data = const DataSourceInput();
  bool oneD = false;
  bool serial = false;
  String sPrefix = '';
  int sStart = 1;
  int sCount = 24;
  int sPad = 5;
  Symbology twoD = Symbology.qrCode;
  Symbology oneDSym = Symbology.gs1_128;
  QrEcLevel ec = QrEcLevel.medium;
  double dpi = 300;
  double xdim = 0.5;
  double barh = 15;

  GenInput get _input => GenInput(
        oneD: oneD,
        data: data,
        twoD: twoD,
        oneDSym: oneDSym,
        ec: ec,
        dpi: dpi,
        xdim: xdim,
        barh: barh,
      );

  void _set(void Function() fn) => setState(fn);
  void _d(DataSourceInput Function(DataSourceInput) f) =>
      setState(() => data = f(data));

  void _downloadSvg(GenOutput out) {
    if (out.svg != null) {
      downloadText('qseq-code.svg', out.svg!, 'image/svg+xml');
    }
  }

  Future<void> _downloadPng(GenOutput out) async {
    if (out.svg == null) return;
    final is2D = !oneD;
    final svgW = is2D ? 300.0 : 360.0;
    final svgH = is2D ? 300.0 : 130.0;
    var targetW = out.size?.outer.widthPx ?? (svgW * 2).round();
    if (targetW < 64) targetW = (svgW * 2).round();
    if (targetW > 5000) targetW = 5000;
    final targetH = (targetW * svgH / svgW).round();
    await downloadSvgPng('qseq-code.png', out.svg!, targetW, targetH);
  }


  @override
  Component build(BuildContext context) {
    final isSheet = serial;
    final out = isSheet ? const GenOutput() : generate(_input);
    final sheet = isSheet
        ? buildSheet(_input,
            prefix: sPrefix,
            start: sStart,
            count: sCount.clamp(1, 48),
            pad: sPad)
        : null;
    final error = isSheet ? sheet!.error : out.error;
    final k = data.kind;
    return section(id: 'generator', classes: 'generator', [
      // ---- inputs ----
      div(classes: 'panel inputs', [
        h2([text('Generator')]),
        _select('Workspace', '${oneD ? '1d' : '2d'}${serial ? 'Serial' : ''}',
            const [
              ('2d', '2D'),
              ('2dSerial', '2D — Serialized sheet'),
              ('1d', '1D'),
              ('1dSerial', '1D — Serialized sheet'),
            ], (v) => _set(() {
                  oneD = v.startsWith('1d');
                  serial = v.endsWith('Serial');
                })),
        _select('Data source', k.name, const [
          ('sgtin', 'SGTIN'),
          ('nsn', 'NATO Stock Number'),
          ('rawText', 'Free text'),
        ], (v) => _d((d) => d.copyWith(kind: DataSourceKind.values.byName(v)))),
        if (k == DataSourceKind.sgtin) ...[
          _text('GTIN (8/12/13/14)', data.gtin,
              (v) => _d((d) => d.copyWith(gtin: v))),
          _text('Serial', data.serial, (v) => _d((d) => d.copyWith(serial: v))),
          _select('SGTIN format', data.sgtinFormat.name, const [
            ('digitalLink', 'GS1 Digital Link'),
            ('elementString', 'GS1 element string'),
            ('epcTagUri', 'EPC Tag URI'),
          ], (v) => _d((d) => d.copyWith(sgtinFormat: SgtinFormat.values.byName(v)))),
          if (data.sgtinFormat == SgtinFormat.epcTagUri)
            _num('Company prefix length', data.companyPrefixLength.toDouble(),
                (v) => _d((d) => d.copyWith(companyPrefixLength: v.round()))),
          if (data.sgtinFormat == SgtinFormat.digitalLink)
            _text('Digital Link domain', data.digitalLinkDomain,
                (v) => _d((d) => d.copyWith(digitalLinkDomain: v))),
        ],
        if (k == DataSourceKind.nsn)
          _text('NATO Stock Number', data.nsn,
              (v) => _d((d) => d.copyWith(nsn: v))),
        if (k == DataSourceKind.rawText)
          _text('Text', data.rawText, (v) => _d((d) => d.copyWith(rawText: v))),
        if (!oneD) ...[
          _select('2D symbology', twoD == Symbology.qrCode ? 'qr' : 'dm', const [
            ('qr', 'QR Code'),
            ('dm', 'Data Matrix'),
          ],
              (v) => _set(() =>
                  twoD = v == 'qr' ? Symbology.qrCode : Symbology.dataMatrix)),
          if (twoD == Symbology.qrCode)
            _select('Error correction', ec.name, const [
              ('low', 'L · 7%'),
              ('medium', 'M · 15%'),
              ('quartile', 'Q · 25%'),
              ('high', 'H · 30%'),
            ], (v) => _set(() => ec = QrEcLevel.values.byName(v))),
        ],
        if (oneD)
          _select('1D symbology', oneDSym.name, const [
            ('gs1_128', 'GS1-128'),
            ('code128', 'Code 128'),
            ('code39', 'Code 39'),
            ('ean13', 'EAN-13'),
            ('upcA', 'UPC-A'),
          ], (v) => _set(() => oneDSym = Symbology.values.byName(v))),
        div(classes: 'grid2', [
          _num('Resolution (DPI)', dpi, (v) => _set(() => dpi = v)),
          _num('X-dimension (mm)', xdim, (v) => _set(() => xdim = v)),
        ]),
        if (oneD) _num('Bar height (mm)', barh, (v) => _set(() => barh = v)),
        if (isSheet) ...[
          _text('Prefix', sPrefix, (v) => _set(() => sPrefix = v)),
          div(classes: 'grid2', [
            _num('Start', sStart.toDouble(),
                (v) => _set(() => sStart = v.round())),
            _num('Count', sCount.toDouble(),
                (v) => _set(() => sCount = v.round())),
          ]),
          _num('Zero-pad', sPad.toDouble(), (v) => _set(() => sPad = v.round())),
        ],
        div(classes: 'downloads', [
          if (!isSheet) ...[
            button([text('Download PNG')],
                classes: 'btn primary',
                disabled: out.svg == null,
                onClick: () => _downloadPng(out)),
            button([text('Download SVG')],
                classes: 'btn',
                disabled: out.svg == null,
                onClick: () => _downloadSvg(out)),
          ] else ...[
            button([text('Download SVG sheet')],
                classes: 'btn primary',
                disabled: sheet!.svg == null,
                onClick: _downloadSheetSvg),
            button([text('Download PNG sheet')],
                classes: 'btn',
                disabled: sheet!.svg == null,
                onClick: _downloadSheetPng),
          ],
        ]),
        if (error != null) p(classes: 'err', [text(error)]),
      ]),
      // ---- preview ----
      div(classes: 'panel preview', [
        div(classes: 'stage', [
          if (isSheet && sheet!.svg != null)
            div(classes: 'card', [RawText(sheet.svg!)])
          else if (!isSheet && out.svg != null)
            div(classes: 'card', [RawText(out.svg!)]),
        ]),
        if (isSheet && sheet!.svg != null && sheet.count < sCount)
          p(classes: 'cap', [
            text('Showing first ${sheet.count} of $sCount · the full sheet exports')
          ]),
        if (!isSheet && out.size != null) _readout(out.size!),
      ]),
    ]);
  }

  void _downloadSheetSvg() {
    final s = buildSheet(_input,
        prefix: sPrefix, start: sStart, count: sCount, pad: sPad);
    if (s.svg != null) downloadText('qseq-sheet.svg', s.svg!, 'image/svg+xml');
  }

  Future<void> _downloadSheetPng() async {
    final s = buildSheet(_input,
        prefix: sPrefix, start: sStart, count: sCount, pad: sPad);
    if (s.svg == null) return;
    var w = s.width.round();
    var h = s.height.round();
    const maxDim = 4000;
    final big = w > h ? w : h;
    if (big > maxDim) {
      final k = maxDim / big;
      w = (w * k).round();
      h = (h * k).round();
    }
    await downloadSvgPng('qseq-sheet.png', s.svg!, w, h);
  }

  // ---- input helpers (reuse the existing .inputs CSS) ----
  Component _select(String lbl, String value, List<(String, String)> opts,
      void Function(String) on) {
    return label([
      text(lbl),
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

  Component _text(String lbl, String value, void Function(String) on) {
    return label([
      text(lbl),
      input(value: value, onInput: on),
    ]);
  }

  Component _num(String lbl, double value, void Function(double) on) {
    return label([
      text(lbl),
      input(
        attributes: const {'type': 'number'},
        value: _fmt(value),
        onInput: (String v) {
          final n = double.tryParse(v);
          if (n != null) on(n);
        },
      ),
    ]);
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Component _readout(SizeResult r) {
    final cells = <Component>[];
    void kv(String k, String v) => cells.add(div([
          div(classes: 'k', [text(k)]),
          div(classes: 'v', [text(v)]),
        ]));
    if (!oneD) {
      kv('Outer size', r.outer.mm);
      kv('', r.outer.inch);
      kv('Geometry', r.geometryLabel);
    } else {
      kv('Symbology', r.symbology.displayName);
      kv('Outer width',
          '${r.outer.widthMm.toStringAsFixed(1)} mm · ${r.outer.widthInch.toStringAsFixed(2)} in');
      kv('Geometry', r.geometryLabel);
    }
    kv('Bytes',
        r.bytesCapacity != null ? '${r.bytesRequested} / ${r.bytesCapacity}' : '${r.bytesRequested}');
    cells.add(div(classes: 'full', [
      text('Module ${r.moduleDots} dots @ ${dpi.toInt()} DPI · print at '
          '${dpi.toInt()} DPI for exact size')
    ]));
    return div(classes: 'readout', cells);
  }
}
