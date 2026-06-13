// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_test/flutter_test.dart';
import 'package:qseq/render/qr_structure.dart';

void main() {
  group('QrStructure', () {
    test('flags finder, timing and dark module', () {
      final s = QrStructure(7); // 45×45
      expect(s.isFunction(0, 0), isTrue); // top-left finder
      expect(s.isFunction(0, 44), isTrue); // top-right finder
      expect(s.isFunction(44, 0), isTrue); // bottom-left finder
      expect(s.isFunction(6, 20), isTrue); // horizontal timing
      expect(s.isFunction(20, 6), isTrue); // vertical timing
    });

    test('flags the central alignment pattern a centred logo would hit', () {
      // v7 alignment centres are 6/22/38; the centre module is 22.
      final s = QrStructure(7);
      expect(s.isFunction(22, 22), isTrue); // alignment centre
      expect(s.isFunction(20, 24), isTrue); // within the 5×5 block
      expect(s.isFunction(25, 25), isFalse); // just outside it -> data
    });

    test('version 1 has no alignment pattern', () {
      final s = QrStructure(1); // 21×21
      // Centre of v1 is data, not an alignment pattern.
      expect(s.isFunction(10, 10), isFalse);
      expect(s.isFunction(0, 0), isTrue); // still has finders
    });

    test('does not flag a typical interior data module', () {
      final s = QrStructure(10);
      expect(s.isFunction(15, 12), isFalse);
    });
  });
}
