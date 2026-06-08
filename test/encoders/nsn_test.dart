// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/encoders/nsn.dart';

void main() {
  group('Nsn', () {
    test('parses plain and dashed forms identically', () {
      final a = Nsn('9515000036945');
      final b = Nsn('9515-00-003-6945');
      expect(a.digits, b.digits);
      expect(a.digits, '9515000036945');
    });

    test('decomposes into NSC / NCB / NIIN parts', () {
      final n = Nsn('9515-00-003-6945');
      expect(n.nsc, '9515');
      expect(n.supplyGroup, '95');
      expect(n.supplyClass, '15');
      expect(n.ncb, '00');
      expect(n.niin, '000036945');
      expect(n.itemNumber, '0036945');
    });

    test('formats with dashes and exposes a plain payload', () {
      final n = Nsn('9515000036945');
      expect(n.formatted, '9515-00-003-6945');
      expect(n.payload, '9515000036945');
    });

    test('rejects wrong length or non-numeric input', () {
      expect(() => Nsn('12345'), throwsFormatException);
      expect(() => Nsn('9515-00-003-694X'), throwsFormatException);
      expect(Nsn.tryParse('not an nsn'), isNull);
      expect(Nsn.tryParse('9515000036945'), isNotNull);
    });
  });
}
