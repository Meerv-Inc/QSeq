// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/models/data_source.dart';
import 'package:qr_studio/models/symbology.dart';
import 'package:qr_studio/state/app_controller.dart';
import 'package:qr_studio/state/project_io.dart';

void main() {
  test('project JSON round-trips all parameters', () {
    const s = AppSettings(
      mode: AppMode.comboSerial,
      oneDSymbology: Symbology.code128,
      twoDSymbology: Symbology.dataMatrix,
      ecLevel: QrEcLevel.high,
      dpi: 600,
      xDimensionMm: 0.33,
      logoSideMm: 6,
      logoEcBudget: 0.4,
      logoEcShare: 0.3,
      logoManual: true,
      rulersInExports: false,
      batchCount: 50,
      batchCopies: 9,
      data: DataSourceInput(
        kind: DataSourceKind.sgtin,
        gtin: '80614141123458',
        serial: 'X1',
      ),
    );

    final json = ProjectIo.encode(s);
    // Well-formatted (indented) and human-readable.
    expect(json, contains('\n  "workspace"'));
    expect(json, contains('"mode": "comboSerial"'));

    final back = ProjectIo.decode(json);
    expect(back.mode, AppMode.comboSerial);
    expect(back.oneDSymbology, Symbology.code128);
    expect(back.twoDSymbology, Symbology.dataMatrix);
    expect(back.ecLevel, QrEcLevel.high);
    expect(back.dpi, 600);
    expect(back.logoEcBudget, 0.4);
    expect(back.logoEcShare, 0.3);
    expect(back.logoManual, isTrue);
    expect(back.rulersInExports, isFalse);
    expect(back.rulersOnScreen, isTrue);
    expect(back.batchCount, 50);
    expect(back.batchCopies, 9);
    expect(back.data.gtin, '80614141123458');
  });

  test('decode tolerates a partial, externally-edited file', () {
    final s = ProjectIo.decode('{"workspace":{"mode":"oneD"},'
        '"serialization":{"count":7}}');
    expect(s.mode, AppMode.oneD);
    expect(s.batchCount, 7);
    // Missing fields fall back to defaults.
    expect(s.dpi, const AppSettings().dpi);
  });
}
