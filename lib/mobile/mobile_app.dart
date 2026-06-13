// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

// Touch-first front-end for iOS / Android. Reuses the same pure-Dart core as
// the desktop and web (lib/models encoders + BarcodeFactory over the `barcode`
// package), wrapped in Material 3 instead of macos_ui. Print-true PDF export
// and share/print come from the `pdf` + `printing` packages.
import 'dart:io';
import 'dart:typed_data';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/data_source.dart';
import '../models/symbology.dart';
import '../render/barcode_factory.dart';

/// Meerv brand green — used as the Material colour seed.
const _seed = Color(0xFF1C7552);

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QSeq',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          colorSchemeSeed: _seed, useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(
          colorSchemeSeed: _seed, useMaterial3: true, brightness: Brightness.dark),
      home: const GeneratorScreen(),
    );
  }
}

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  Symbology _sym = Symbology.qrCode;
  QrEcLevel _ec = QrEcLevel.medium;
  DataSourceInput _data = const DataSourceInput();

  /// Printed size of the symbol, in millimetres (the long edge for 1D).
  double _sizeMm = 40;

  // Centre-logo dead-space (2D only). The square knockout is sized as a
  // fraction of the symbol; an optional picked image fills it.
  bool _logoOn = false;
  double _logoFrac = 0.18;
  Uint8List? _logoBytes;

  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (mounted) setState(() => _logoBytes = bytes);
  }

  // Serialized sheet (SGTIN): tile `count` codes, incrementing the serial.
  bool _serialOn = false;
  final _count = TextEditingController(text: '24');
  int get _countValue => (int.tryParse(_count.text) ?? 24).clamp(1, 1000);

  bool get _sheetMode => _serialOn && _data.kind == DataSourceKind.sgtin;

  /// The base serial advanced by [i] — increments the trailing digits,
  /// preserving any leading prefix and the zero-padding width.
  String _serialAt(int i) {
    final base = _data.serial;
    final m = RegExp(r'^(.*?)(\d+)$').firstMatch(base);
    if (m == null) return '$base${i + 1}';
    final n = int.parse(m.group(2)!) + i;
    return '${m.group(1)}${n.toString().padLeft(m.group(2)!.length, '0')}';
  }

  late final _gtin = TextEditingController(text: _data.gtin);
  late final _serial = TextEditingController(text: _data.serial);
  late final _domain = TextEditingController(text: _data.digitalLinkDomain);
  late final _text = TextEditingController(text: _data.rawText);

  @override
  void dispose() {
    _gtin.dispose();
    _serial.dispose();
    _domain.dispose();
    _text.dispose();
    _count.dispose();
    _title.dispose();
    super.dispose();
  }

  void _update(DataSourceInput Function(DataSourceInput) f) =>
      setState(() => _data = f(_data));

  // --- PDF (print-true) -----------------------------------------------------

  Future<Uint8List> _buildPdf(String payload) async {
    final doc = pw.Document(title: 'QSeq');
    final w = _sizeMm;
    final h = _sym.is2D ? _sizeMm : _sizeMm * 0.5;
    const margin = 8.0;
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
            (w + margin * 2) * PdfPageFormat.mm, (h + margin * 2 + 6) * PdfPageFormat.mm),
        margin: pw.EdgeInsets.all(margin * PdfPageFormat.mm),
        build: (context) {
          final code = pw.BarcodeWidget(
            barcode: BarcodeFactory.build(_sym, ecLevel: _ec),
            data: payload,
            width: w * PdfPageFormat.mm,
            height: h * PdfPageFormat.mm,
            drawText: !_sym.is2D,
          );
          if (!(_logoOn && _sym.is2D)) return pw.Center(child: code);
          final box = w * _logoFrac * PdfPageFormat.mm;
          return pw.Center(
            child: pw.Stack(alignment: pw.Alignment.center, children: [
              code,
              pw.Container(
                width: box,
                height: box,
                color: PdfColors.white,
                padding: pw.EdgeInsets.all(box * 0.08),
                child: _logoBytes != null
                    ? pw.Image(pw.MemoryImage(_logoBytes!), fit: pw.BoxFit.contain)
                    : null,
              ),
            ]),
          );
        },
      ),
    );
    return doc.save();
  }

  /// A page-tiled serialized sheet — one code per incremented serial, flowing
  /// across as many Letter pages as needed.
  Future<Uint8List> _buildSheetPdf() async {
    final doc = pw.Document(title: 'QSeq sheet');
    final s = _sizeMm * PdfPageFormat.mm;
    final tiles = <pw.Widget>[];
    for (var i = 0; i < _countValue; i++) {
      final serial = _serialAt(i);
      tiles.add(pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.SizedBox(
          width: s,
          height: _sym.is2D ? s : s * 0.5,
          child: pw.BarcodeWidget(
            barcode: BarcodeFactory.build(_sym, ecLevel: _ec),
            data: _data.encodeWith(serial: serial),
            drawText: !_sym.is2D,
          ),
        ),
        pw.SizedBox(height: 1 * PdfPageFormat.mm),
        pw.Text(serial, style: const pw.TextStyle(fontSize: 6)),
      ]));
    }
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: pw.EdgeInsets.all(10 * PdfPageFormat.mm),
      build: (context) => [
        pw.Wrap(
          spacing: 5 * PdfPageFormat.mm,
          runSpacing: 5 * PdfPageFormat.mm,
          alignment: pw.WrapAlignment.center,
          children: tiles,
        ),
      ],
    ));
    return doc.save();
  }

  // Label designer (SGTIN): a sized label pairing the 2D Digital Link, the
  // GS1-128 element string, and a free-text title.
  bool _labelOn = false;
  final _title = TextEditingController(text: 'QSeq');
  bool get _labelMode => _labelOn && _data.kind == DataSourceKind.sgtin;

  Future<Uint8List> _buildLabelPdf() async {
    final doc = pw.Document(title: 'QSeq label');
    final dl = _data.encodeWith(format: SgtinFormat.digitalLink);
    final es = _data.encodeWith(format: SgtinFormat.elementString);
    final wMm = _sizeMm * 2.2;
    final hMm = _sizeMm;
    const pad = 3.0;
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(
          (wMm + pad * 2) * PdfPageFormat.mm, (hMm + pad * 2) * PdfPageFormat.mm),
      margin: pw.EdgeInsets.all(pad * PdfPageFormat.mm),
      build: (context) => pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
        padding: const pw.EdgeInsets.all(4),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.AspectRatio(
            aspectRatio: 1,
            child: pw.BarcodeWidget(
                barcode: BarcodeFactory.build(Symbology.qrCode, ecLevel: _ec),
                data: dl,
                drawText: false),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(_title.text,
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Expanded(
                    child: pw.BarcodeWidget(
                        barcode: BarcodeFactory.build(Symbology.gs1_128),
                        data: es,
                        drawText: true),
                  ),
                ]),
          ),
        ]),
      ),
    ));
    return doc.save();
  }

  String get _pdfName =>
      _labelMode ? 'qseq-label.pdf' : (_sheetMode ? 'qseq-sheet.pdf' : 'qseq-code.pdf');

  Widget _labelPreviewCard() {
    final String dl, es;
    try {
      dl = _data.encodeWith(format: SgtinFormat.digitalLink);
      es = _data.encodeWith(format: SgtinFormat.elementString);
    } catch (e) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: AspectRatio(
          aspectRatio: 2.4,
          child: Container(
            decoration:
                BoxDecoration(border: Border.all(color: Colors.black, width: 0.5)),
            padding: const EdgeInsets.all(8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AspectRatio(
                aspectRatio: 1,
                child: BarcodeWidget(
                    barcode:
                        BarcodeFactory.build(Symbology.qrCode, ecLevel: _ec),
                    data: dl,
                    color: Colors.black,
                    backgroundColor: Colors.white,
                    drawText: false),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_title.text,
                          style: const TextStyle(
                              color: Colors.black, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Expanded(
                        child: BarcodeWidget(
                            barcode: BarcodeFactory.build(Symbology.gs1_128),
                            data: es,
                            color: Colors.black,
                            backgroundColor: Colors.white,
                            drawText: true),
                      ),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _withPdf(String? payload, Future<void> Function(Uint8List) use) async {
    if (payload == null) return;
    try {
      await use(_labelMode
          ? await _buildLabelPdf()
          : _sheetMode
              ? await _buildSheetPdf()
              : await _buildPdf(payload));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  /// Rasterise the print-true PDF to a PNG and share it through the OS sheet.
  Future<void> _sharePng(String? payload) async {
    await _withPdf(payload, (pdf) async {
      final dpi = (_sizeMm > 0 ? 2400 / _sizeMm : 300).clamp(150, 1200).toDouble();
      final raster = await Printing.raster(pdf, dpi: dpi).first;
      final png = await raster.toPng();
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/qseq-code.png').writeAsBytes(png);
      await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _data.resolve();
    final payload = resolved.data;
    final error = resolved.error;
    final isSgtin = _data.kind == DataSourceKind.sgtin;
    final canExport = payload != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QSeq'),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share),
            enabled: canExport,
            tooltip: 'Export',
            onSelected: (v) {
              switch (v) {
                case 'png':
                  _sharePng(payload);
                case 'pdf':
                  _withPdf(payload,
                      (b) => Printing.sharePdf(bytes: b, filename: _pdfName));
                case 'print':
                  _withPdf(payload, (b) => Printing.layoutPdf(onLayout: (_) => b));
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                  value: 'png',
                  child: ListTile(
                      leading: Icon(Icons.image), title: Text('Share PNG'))),
              PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                      leading: Icon(Icons.picture_as_pdf),
                      title: Text('Share PDF'))),
              PopupMenuItem(
                  value: 'print',
                  child: ListTile(
                      leading: Icon(Icons.print), title: Text('Print'))),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (_labelMode)
              _labelPreviewCard()
            else
              _Preview(
                  symbology: _sym,
                  ec: _ec,
                  payload: payload,
                  error: error,
                  logoOn: _logoOn && _sym.is2D,
                  logoFrac: _logoFrac,
                  logoBytes: _logoBytes),
            const SizedBox(height: 8),
            if (payload != null)
              Center(
                child: SelectableText(
                  payload,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            const SizedBox(height: 20),

            // Symbology
            DropdownButtonFormField<Symbology>(
              initialValue: _sym,
              decoration: const InputDecoration(
                  labelText: 'Symbology', border: OutlineInputBorder()),
              items: [
                for (final s in Symbology.values)
                  DropdownMenuItem(value: s, child: Text(s.displayName)),
              ],
              onChanged: (v) => setState(() => _sym = v ?? _sym),
            ),
            if (_sym.supportsEcLevel) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<QrEcLevel>(
                initialValue: _ec,
                decoration: const InputDecoration(
                    labelText: 'Error correction',
                    border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: QrEcLevel.low, child: Text('L · 7%')),
                  DropdownMenuItem(
                      value: QrEcLevel.medium, child: Text('M · 15%')),
                  DropdownMenuItem(
                      value: QrEcLevel.quartile, child: Text('Q · 25%')),
                  DropdownMenuItem(value: QrEcLevel.high, child: Text('H · 30%')),
                ],
                onChanged: (v) => setState(() => _ec = v ?? _ec),
              ),
            ],
            const SizedBox(height: 12),

            // Printed size — keeps the PDF print-true.
            Row(
              children: [
                const Text('Printed size'),
                Expanded(
                  child: Slider(
                    value: _sizeMm,
                    min: 10,
                    max: 120,
                    divisions: 110,
                    label: '${_sizeMm.round()} mm',
                    onChanged: (v) => setState(() => _sizeMm = v),
                  ),
                ),
                SizedBox(
                    width: 56,
                    child: Text('${_sizeMm.round()} mm',
                        textAlign: TextAlign.end)),
              ],
            ),
            const SizedBox(height: 12),

            // Centre logo (2D only)
            if (_sym.is2D) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Centre logo dead-space'),
                value: _logoOn,
                onChanged: (v) => setState(() => _logoOn = v),
              ),
              if (_logoOn) ...[
                Row(children: [
                  const Text('Logo size'),
                  Expanded(
                    child: Slider(
                      value: _logoFrac,
                      min: 0.10,
                      max: 0.28,
                      divisions: 18,
                      label: '${(_logoFrac * 100).round()}%',
                      onChanged: (v) => setState(() => _logoFrac = v),
                    ),
                  ),
                  SizedBox(
                      width: 44,
                      child: Text('${(_logoFrac * 100).round()}%',
                          textAlign: TextAlign.end)),
                ]),
                Row(children: [
                  OutlinedButton.icon(
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Pick image')),
                  const SizedBox(width: 8),
                  if (_logoBytes != null)
                    TextButton(
                        onPressed: () => setState(() => _logoBytes = null),
                        child: const Text('Clear')),
                ]),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      'Tip: set error correction to H so the code still scans.',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
              const SizedBox(height: 12),
            ],

            // Data source
            SegmentedButton<DataSourceKind>(
              segments: const [
                ButtonSegment(value: DataSourceKind.sgtin, label: Text('SGTIN')),
                ButtonSegment(
                    value: DataSourceKind.rawText, label: Text('Free text')),
              ],
              selected: {_data.kind},
              onSelectionChanged: (s) => _update((d) => d.copyWith(kind: s.first)),
            ),
            const SizedBox(height: 16),

            if (isSgtin) ...[
              _field(_gtin, 'GTIN (8 / 12 / 13 / 14)',
                  (v) => _update((d) => d.copyWith(gtin: v)),
                  keyboard: TextInputType.number),
              _field(_serial, 'Serial',
                  (v) => _update((d) => d.copyWith(serial: v))),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Serialized sheet'),
                subtitle:
                    const Text('Tile many codes, incrementing the serial'),
                value: _serialOn,
                onChanged: (v) => setState(() => _serialOn = v),
              ),
              if (_serialOn)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: TextField(
                    controller: _count,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        labelText: 'Count (codes)',
                        border: OutlineInputBorder()),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Label designer'),
                subtitle: const Text('Sized label: QR + GS1-128 + title'),
                value: _labelOn,
                onChanged: (v) => setState(() => _labelOn = v),
              ),
              if (_labelOn)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: TextField(
                    controller: _title,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        labelText: 'Title', border: OutlineInputBorder()),
                  ),
                ),
              DropdownButtonFormField<SgtinFormat>(
                initialValue: _data.sgtinFormat,
                decoration: const InputDecoration(
                    labelText: 'SGTIN format', border: OutlineInputBorder()),
                items: [
                  for (final f in SgtinFormat.values)
                    DropdownMenuItem(value: f, child: Text(f.label)),
                ],
                onChanged: (v) => _update(
                    (d) => d.copyWith(sgtinFormat: v ?? d.sgtinFormat)),
              ),
              if (_data.sgtinFormat == SgtinFormat.digitalLink) ...[
                const SizedBox(height: 12),
                _field(_domain, 'Digital Link domain',
                    (v) => _update((d) => d.copyWith(digitalLinkDomain: v))),
              ],
            ] else
              _field(_text, 'Text',
                  (v) => _update((d) => d.copyWith(rawText: v))),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      ValueChanged<String> onChanged,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        onChanged: onChanged,
        decoration:
            InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}

/// The live barcode preview — always black-on-white for scannability.
class _Preview extends StatelessWidget {
  final Symbology symbology;
  final QrEcLevel ec;
  final String? payload;
  final String? error;
  final bool logoOn;
  final double logoFrac;
  final Uint8List? logoBytes;
  const _Preview(
      {required this.symbology,
      required this.ec,
      required this.payload,
      required this.error,
      required this.logoOn,
      required this.logoFrac,
      required this.logoBytes});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget child;
    if (payload == null) {
      child = Padding(
        padding: const EdgeInsets.all(24),
        child: Text(error ?? 'Enter data to encode',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.error)),
      );
    } else {
      final code = BarcodeWidget(
        barcode: BarcodeFactory.build(symbology, ecLevel: ec),
        data: payload!,
        color: Colors.black,
        backgroundColor: Colors.white,
        drawText: !symbology.is2D,
        errorBuilder: (context, e) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(e,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error)),
        ),
      );
      if (logoOn && symbology.is2D) {
        child = AspectRatio(
          aspectRatio: 1,
          child: Stack(alignment: Alignment.center, children: [
            Positioned.fill(child: code),
            FractionallySizedBox(
              widthFactor: logoFrac,
              heightFactor: logoFrac,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(4),
                child: logoBytes != null
                    ? Image.memory(logoBytes!, fit: BoxFit.contain)
                    : null,
              ),
            ),
          ]),
        );
      } else {
        child = symbology.is2D
            ? AspectRatio(aspectRatio: 1, child: code)
            : SizedBox(height: 120, child: code);
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(minHeight: 220),
        child: Center(child: child),
      ),
    );
  }
}
