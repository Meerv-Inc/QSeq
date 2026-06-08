// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/models/encode_config.dart';
import 'package:qr_studio/models/symbology.dart';
import 'package:qr_studio/render/raster_renderer.dart';
import 'package:qr_studio/render/ruler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('addRulers enlarges the image by one band on each axis', () async {
    const cfg = EncodeConfig(
      symbology: Symbology.qrCode,
      data: 'https://id.gs1.org/01/80614141123458/21/6789',
      dpi: 300,
      xDimensionMm: 0.5,
    );
    final code = await RasterRenderer.render(cfg);
    final ruled = await Ruler.addRulers(code, cfg.dpi);
    final bandPx = (Ruler.bandMm * 300 / 25.4).round();
    expect(ruled.width, code.width + bandPx);
    expect(ruled.height, code.height + bandPx);

    final png = await Ruler.png(ruled);
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });
}
