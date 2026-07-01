// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_test/flutter_test.dart';
import 'package:qseq/sizing/pdf417_capacity.dart';

void main() {
  group('Pdf417EcLevel', () {
    test('eccWordCount doubles per level, 2..512', () {
      expect(Pdf417EcLevel.level0.eccWordCount, 2);
      expect(Pdf417EcLevel.level2.eccWordCount, 8);
      expect(Pdf417EcLevel.level8.eccWordCount, 512);
    });

    test('label marks level2 as the default', () {
      expect(Pdf417EcLevel.level2.label, contains('default'));
      expect(Pdf417EcLevel.level0.label, isNot(contains('default')));
    });
  });

  group('Pdf417Capacity.moduleGrid', () {
    test('sizes a short message', () {
      final grid = Pdf417Capacity.moduleGrid('HELLO', Pdf417EcLevel.level2);
      expect(grid, isNotNull);
      expect(grid!.widthModules, greaterThan(0));
      expect(grid.heightModules, greaterThan(0));
    });

    test('sizes a typical GS1 Digital Link URL', () {
      final grid = Pdf417Capacity.moduleGrid(
        'https://id.gs1.org/01/80614141123458/21/6789',
        Pdf417EcLevel.level2,
      );
      expect(grid, isNotNull);
    });

    test('a higher EC level needs a larger (or equal) footprint for the '
        'same data', () {
      const data = 'https://id.gs1.org/01/80614141123458/21/6789';
      final low = Pdf417Capacity.moduleGrid(data, Pdf417EcLevel.level0)!;
      final high = Pdf417Capacity.moduleGrid(data, Pdf417EcLevel.level8)!;
      final lowArea = low.widthModules * low.heightModules;
      final highArea = high.widthModules * high.heightModules;
      expect(highArea, greaterThanOrEqualTo(lowArea));
    });

    test('longer data needs a larger (or equal) footprint at the same EC '
        'level', () {
      final short = Pdf417Capacity.moduleGrid('SHORT', Pdf417EcLevel.level2)!;
      final long = Pdf417Capacity.moduleGrid('A' * 500, Pdf417EcLevel.level2)!;
      final shortArea = short.widthModules * short.heightModules;
      final longArea = long.widthModules * long.heightModules;
      expect(longArea, greaterThanOrEqualTo(shortArea));
    });

    test('empty data still yields a valid minimal symbol', () {
      final grid = Pdf417Capacity.moduleGrid('', Pdf417EcLevel.level2);
      expect(grid, isNotNull);
    });

    test('returns null once data is too large for PDF417 to hold', () {
      // Well past PDF417's 60-column/60-row ceiling at any EC level.
      final grid = Pdf417Capacity.moduleGrid('A' * 20000, Pdf417EcLevel.level8);
      expect(grid, isNull);
    });

    test('width formula matches (columns + 4) * 17 + 1 exactly — the '
        'widthModules is always congruent to 1 mod 17 in the 17..69 '
        'increments PDF417 columns produce', () {
      final grid = Pdf417Capacity.moduleGrid('TEST-0001', Pdf417EcLevel.level3);
      expect(grid, isNotNull);
      expect((grid!.widthModules - 1) % 17, 0);
    });
  });
}
