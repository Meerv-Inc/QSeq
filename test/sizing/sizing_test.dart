// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_test/flutter_test.dart';
import 'package:qseq/models/encode_config.dart';
import 'package:qseq/models/symbology.dart';
import 'package:qseq/sizing/datamatrix_capacity.dart';
import 'package:qseq/sizing/dpi.dart';
import 'package:qseq/sizing/logo_ec.dart';
import 'package:qseq/sizing/qr_capacity.dart';
import 'package:qseq/sizing/sizer.dart';

void main() {
  group('QrCapacity', () {
    test('module count = 17 + 4*version', () {
      expect(QrCapacity.moduleCount(1), 21);
      expect(QrCapacity.moduleCount(40), 177);
    });

    test('picks the smallest version that fits the byte count', () {
      // 14 bytes fits v1-M (16); 17 bytes needs v2-M (28). v1-M cap is 14.
      expect(QrCapacity.minVersionForBytes(14, QrEcLevel.medium), 1);
      expect(QrCapacity.minVersionForBytes(15, QrEcLevel.medium), 2);
    });

    test('higher EC lowers capacity, forcing larger versions', () {
      final atL = QrCapacity.minVersionForBytes(100, QrEcLevel.low);
      final atH = QrCapacity.minVersionForBytes(100, QrEcLevel.high);
      expect(atH! >= atL!, isTrue);
    });

    test('returns null when data cannot fit', () {
      expect(QrCapacity.minVersionForBytes(100000, QrEcLevel.high), isNull);
    });
  });

  group('DataMatrixCapacity', () {
    test('selects the smallest square symbol', () {
      expect(DataMatrixCapacity.minSizeForBytes(1)!.modules, 10);
      final s = DataMatrixCapacity.minSizeForBytes(40)!;
      expect(s.modules, greaterThanOrEqualTo(24));
    });

    test('correction fraction is within the ECC 200 range', () {
      for (final s in DataMatrixCapacity.squareSizes) {
        expect(s.correctionFraction, inInclusiveRange(0.25, 0.65));
      }
    });
  });

  group('Dpi', () {
    test('rounds modules to whole dots and reports physical size', () {
      // 0.5 mm module at 300 dpi -> 0.5/25.4*300 = 5.905 -> 6 dots.
      expect(Dpi.moduleDots(0.5, 300), 6);
      final s = PhysicalSize.fromModules(
          widthModules: 10, heightModules: 10, moduleDots: 6, dpi: 300);
      expect(s.widthPx, 60);
      // 60 px / 300 dpi = 0.2 in = 5.08 mm.
      expect(s.widthMm, closeTo(5.08, 0.001));
    });
  });

  group('LogoEc budget', () {
    test('small logo fits; oversized logo fails with a max-safe hint', () {
      final ok = LogoEc.evaluate(
          logoSideMm: 5,
          symbolSideMm: 40,
          recoverableFraction: 0.30); // QR-H
      expect(ok.fits, isTrue);

      final tooBig = LogoEc.evaluate(
          logoSideMm: 30, symbolSideMm: 40, recoverableFraction: 0.30);
      expect(tooBig.fits, isFalse);
      expect(tooBig.maxSafeLogoMm, lessThan(30));
      // budget = 0.30*0.5 = 0.15 -> max side = 40*sqrt(0.15) ~= 15.49 mm.
      expect(tooBig.maxSafeLogoMm, closeTo(15.49, 0.1));
    });
  });

  group('Sizer end-to-end', () {
    test('QR outer size grows with the quiet zone and reports capacity', () {
      const cfg = EncodeConfig(
        symbology: Symbology.qrCode,
        data: 'https://id.gs1.org/01/80614141123458/21/6789',
        ecLevel: QrEcLevel.medium,
        dpi: 300,
        xDimensionMm: 0.5,
      );
      final r = Sizer.compute(cfg);
      expect(r.fits, isTrue);
      expect(r.bytesCapacity, greaterThanOrEqualTo(r.bytesRequested));
      // side modules include 2*4 quiet zone.
      expect(r.geometryLabel, contains('Version'));
      expect(r.outer.widthPx, greaterThan(0));
    });

    test('oversized QR data is reported as not fitting', () {
      final cfg = EncodeConfig(
        symbology: Symbology.qrCode,
        data: 'x' * 5000,
        ecLevel: QrEcLevel.high,
      );
      final r = Sizer.compute(cfg);
      expect(r.fits, isFalse);
      expect(r.warnings.first, contains('exceeds'));
    });

    test('Data Matrix flags fixed correction', () {
      const cfg = EncodeConfig(
          symbology: Symbology.dataMatrix, data: '01234567890');
      final r = Sizer.compute(cfg);
      expect(r.fits, isTrue);
      expect(r.warnings.any((w) => w.contains('ECC 200')), isTrue);
    });

    test('1D logo triggers the bars caveat', () {
      const cfg = EncodeConfig(
        symbology: Symbology.code128,
        data: '12345678',
        logoSideMm: 5,
      );
      final r = Sizer.compute(cfg);
      expect(r.logoBudget, isNull);
      expect(r.warnings.any((w) => w.contains('1D code')), isTrue);
    });

    test('EAN-13 uses asymmetric quiet zones (11 left + 7 right)', () {
      const cfg = EncodeConfig(
        symbology: Symbology.ean13,
        data: '4006381333931',
        dpi: 300,
        xDimensionMm: 0.33,
      );
      final r = Sizer.compute(cfg);
      final dots = Dpi.moduleDots(0.33, 300);
      // 95 symbol modules + 11 left + 7 right = 113 modules (GS1), not the
      // symmetric 95 + 2*11 = 117 the old single-quiet-zone code produced.
      expect(r.outer.widthPx, 113 * dots);
    });
  });
}
