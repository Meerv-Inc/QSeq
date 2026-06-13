// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_test/flutter_test.dart';
import 'package:qseq/models/caption.dart';
import 'package:qseq/models/data_source.dart';
import 'package:qseq/models/encode_config.dart';
import 'package:qseq/models/symbology.dart';
import 'package:qseq/render/raster_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('caption derived from SGTIN data source is the serial (bold)', () {
    const d = DataSourceInput(kind: DataSourceKind.sgtin, serial: '6789');
    final cap = d.caption();
    expect(cap.bold, '6789');
    expect(cap.prefix, '');
    expect(cap.isNotEmpty, isTrue);
  });

  test('raw text has no caption', () {
    expect(const DataSourceInput(kind: DataSourceKind.rawText).caption().isEmpty,
        isTrue);
  });

  test('caption band makes the rendered image taller than the symbol', () async {
    const cfg = EncodeConfig(
      symbology: Symbology.qrCode,
      data: 'https://id.gs1.org/01/80614141123458/21/6789',
      dpi: 300,
      xDimensionMm: 0.5,
    );
    final plain = await RasterRenderer.render(cfg);
    final withCap = await RasterRenderer.render(cfg,
        caption: const LabelCaption(bold: '6789'));
    expect(withCap.height, greaterThan(plain.height));
    expect(withCap.width, plain.width);
  });
}
