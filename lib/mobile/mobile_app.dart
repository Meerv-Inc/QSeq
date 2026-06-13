// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

// Touch-first front-end for iOS / Android. Reuses the same pure-Dart core as
// the desktop and web (lib/models encoders + BarcodeFactory over the `barcode`
// package), wrapped in Material 3 instead of macos_ui.
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

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
    super.dispose();
  }

  void _update(DataSourceInput Function(DataSourceInput) f) =>
      setState(() => _data = f(_data));

  @override
  Widget build(BuildContext context) {
    final resolved = _data.resolve();
    final payload = resolved.data;
    final error = resolved.error;
    final isSgtin = _data.kind == DataSourceKind.sgtin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QSeq'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Preview(symbology: _sym, ec: _ec, payload: payload, error: error),
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
            const SizedBox(height: 20),

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
  const _Preview(
      {required this.symbology,
      required this.ec,
      required this.payload,
      required this.error});

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
      child = symbology.is2D
          ? AspectRatio(aspectRatio: 1, child: code)
          : SizedBox(height: 120, child: code);
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
