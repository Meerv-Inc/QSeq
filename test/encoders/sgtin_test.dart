// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/encoders/gtin.dart';
import 'package:qr_studio/encoders/gs1.dart';
import 'package:qr_studio/encoders/sgtin.dart';

void main() {
  group('Gtin', () {
    test('computes the GS1 mod-10 check digit', () {
      // 8061414112345 -> check digit 8  (GS1 TDS canonical SGTIN example).
      expect(Gtin.checkDigit('8061414112345'), 8);
      // Well-known EAN-13 example 400638133393 -> check 1.
      expect(Gtin.checkDigit('400638133393'), 1);
    });

    test('validates a full GTIN', () {
      expect(Gtin.isValid('80614141123458'), isTrue);
      expect(Gtin.isValid('80614141123455'), isFalse);
    });

    test('normalises shorter GTINs to 14 digits', () {
      // GTIN-13 4006381333931 (valid check) -> padded to 14.
      expect(Gtin.normalize14('4006381333931'), '04006381333931');
    });

    test('rejects bad input', () {
      expect(() => Gtin.normalize14('12345'), throwsFormatException);
      expect(() => Gtin.normalize14('abcd'), throwsFormatException);
      expect(() => Gtin.normalize14('80614141123455'), throwsFormatException);
    });
  });

  group('Sgtin output representations', () {
    final sgtin = Sgtin(gtin: '80614141123458', serial: '6789');

    test('element string', () {
      expect(sgtin.toElementString(), '(01)80614141123458(21)6789');
    });

    test('digital link (default + custom domain)', () {
      expect(sgtin.toDigitalLink(),
          'https://id.gs1.org/01/80614141123458/21/6789');
      expect(sgtin.toDigitalLink(domain: 'https://example.com/'),
          'https://example.com/01/80614141123458/21/6789');
    });

    test('digital link percent-encodes the serial', () {
      final s = Sgtin(gtin: '80614141123458', serial: 'AB/CD 1');
      expect(s.toDigitalLink(),
          'https://id.gs1.org/01/80614141123458/21/AB%2FCD%201');
    });

    test('EPC Tag URI moves the indicator into the item-reference field', () {
      // companyPrefix 0614141 (len 7), itemRef 12345, indicator 8.
      expect(sgtin.toEpcTagUri(companyPrefixLength: 7),
          'urn:epc:id:sgtin:0614141.812345.6789');
    });

    test('EPC Tag URI rejects out-of-range company prefix length', () {
      expect(() => sgtin.toEpcTagUri(companyPrefixLength: 5),
          throwsArgumentError);
      expect(() => sgtin.toEpcTagUri(companyPrefixLength: 13),
          throwsArgumentError);
    });
  });

  group('Gs1 raw encoding', () {
    test('inserts leading FNC1 and no trailing FNC1 after last field', () {
      final raw = Gs1.encode([('01', '80614141123458'), ('21', '6789')]);
      expect(raw, '${Gs1.fnc1}0180614141123458216789');
    });

    test('inserts FNC1 after a variable field followed by more data', () {
      // 21 (serial, variable) followed by 17 (fixed) -> separator after 21.
      final raw = Gs1.encode([('21', '6789'), ('17', '251231')]);
      expect(raw, '${Gs1.fnc1}216789${Gs1.fnc1}17251231');
    });

    test('element string is parenthesised', () {
      expect(Gs1.elementString([('01', '80614141123458'), ('21', '6789')]),
          '(01)80614141123458(21)6789');
    });
  });
}
