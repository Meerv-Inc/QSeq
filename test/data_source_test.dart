// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_test/flutter_test.dart';
import 'package:qseq/encoders/gs1_keys.dart';
import 'package:qseq/encoders/gtin.dart';
import 'package:qseq/models/data_source.dart';
import 'package:qseq/models/symbology.dart';

void main() {
  group('DataSourceInput — GS1 key types', () {
    test('resolve() builds a GRAI element string with a serial', () {
      const d = DataSourceInput(
        gs1KeyType: Gs1KeyType.grai,
        gs1CompanyPrefix: '0614141',
        gs1Reference: '00001',
        gs1KeySerial: 'XYZ001',
        sgtinFormat: SgtinFormat.elementString,
      );
      final r = d.resolve();
      expect(r.error, isNull);
      expect(r.data, startsWith('(8003)'));
      expect(r.data, endsWith('XYZ001'));
    });

    test('resolve() builds a GRAI digital link, dropping the serial when '
        'serialize is off', () {
      const d = DataSourceInput(
        gs1KeyType: Gs1KeyType.grai,
        gs1CompanyPrefix: '0614141',
        gs1Reference: '00001',
        gs1KeySerial: 'XYZ001',
        serialize: false,
      );
      final r = d.resolve();
      expect(r.error, isNull);
      expect(r.data, 'https://id.gs1.org/8003/${r.data!.split('/').last}');
      expect(r.data, isNot(contains('XYZ001')));
    });

    test('resolve() surfaces a FormatException as a resolve error', () {
      const d = DataSourceInput(
        gs1KeyType: Gs1KeyType.grai,
        gs1CompanyPrefix: '061414', // one digit short
        gs1Reference: '00001',
      );
      final r = d.resolve();
      expect(r.data, isNull);
      expect(r.error, isNotNull);
    });

    test('resolve() builds a GLN (no serial concept)', () {
      const d = DataSourceInput(
        gs1KeyType: Gs1KeyType.gln,
        gs1CompanyPrefix: '0614141',
        gs1Reference: '00001',
      );
      final r = d.resolve();
      expect(r.error, isNull);
      expect(r.data, startsWith('https://id.gs1.org/414/'));
    });

    test('resolve() builds an opaque GINC from gs1OpaqueValue', () {
      const d = DataSourceInput(
        gs1KeyType: Gs1KeyType.ginc,
        gs1OpaqueValue: 'CONSIGN-0001',
        sgtinFormat: SgtinFormat.elementString,
      );
      final r = d.resolve();
      expect(r.data, '(401)CONSIGN-0001');
    });

    test('payloadFor uses the full Digital Link for 2D but the bare key '
        'for a plain 1D symbology (GSIN has no serial to drop either way)', () {
      const d = DataSourceInput(
        gs1KeyType: Gs1KeyType.gsin,
        gs1CompanyPrefix: '0614141',
        gs1Reference: '000000001',
      );
      final forQr = d.payloadFor(Symbology.qrCode);
      final forCode128 = d.payloadFor(Symbology.code128);
      expect(forQr, startsWith('https://id.gs1.org/402/'));
      expect(forCode128, isNotNull);
      expect(forCode128, isNot(contains('https://')));
      expect(forQr, endsWith(forCode128!));
    });

    test('caption() shows the GRAI serial only when serialize is on', () {
      const on = DataSourceInput(
        gs1KeyType: Gs1KeyType.grai,
        gs1KeySerial: 'XYZ001',
      );
      expect(on.caption().bold, 'XYZ001');

      const off = DataSourceInput(
        gs1KeyType: Gs1KeyType.grai,
        gs1KeySerial: 'XYZ001',
        serialize: false,
      );
      expect(off.caption().bold, isEmpty);

      const gln = DataSourceInput(gs1KeyType: Gs1KeyType.gln);
      expect(gln.caption().bold, isEmpty);
    });

    test('gs1RawOrNull encodes the GS1 key under its own AI', () {
      const d = DataSourceInput(
        gs1KeyType: Gs1KeyType.gdti,
        gs1CompanyPrefix: '0614141',
        gs1Reference: '00001',
        sgtinFormat: SgtinFormat.elementString,
      );
      final raw = d.gs1RawOrNull();
      expect(raw, isNotNull);
      expect(raw, startsWith('${String.fromCharCode(0xF1)}253'));
    });

    test('an existing plain GTIN/SGTIN DataSourceInput is unaffected', () {
      const d = DataSourceInput(gtin: '80614141123458', serial: '6789');
      final r = d.resolve();
      expect(r.error, isNull);
      expect(r.data, 'https://id.gs1.org/01/80614141123458/21/6789');
      expect(Gtin.isValid(d.gtin), isTrue);
    });

    test('payloadFor(Code 39) drops to the bare value — no parens, no '
        'lower-case, no URL scheme (Code 39 cannot encode any of those)', () {
      const d = DataSourceInput(
        gs1KeyType: Gs1KeyType.grai,
        gs1CompanyPrefix: '0614141',
        gs1Reference: '00001',
        gs1KeySerial: 'XYZ001',
        sgtinFormat: SgtinFormat.elementString,
      );
      final payload = d.payloadFor(Symbology.code39);
      expect(payload, isNotNull);
      expect(payload, isNot(contains('(')));
      expect(payload, isNot(contains(':')));
      expect(payload, equals(payload!.toUpperCase()));
      // Serial is dropped for non-GS1-128 1D symbologies, matching the
      // existing bare-GTIN-14 behaviour for plain GTIN.
      expect(payload, isNot(contains('XYZ001')));
      expect(payload.length, 14);
    });

    test('payloadFor(GS1-128) still uses the full element string', () {
      const d = DataSourceInput(
        gs1KeyType: Gs1KeyType.grai,
        gs1CompanyPrefix: '0614141',
        gs1Reference: '00001',
        gs1KeySerial: 'XYZ001',
      );
      final expected = Gs1Keys.grai(
        companyPrefix: '0614141',
        assetType: '00001',
        serial: 'XYZ001',
      );
      expect(d.payloadFor(Symbology.gs1_128), expected.toElementString());
    });

    test('payloadFor(2D) still uses the full Digital Link', () {
      const d = DataSourceInput(
        gs1KeyType: Gs1KeyType.grai,
        gs1CompanyPrefix: '0614141',
        gs1Reference: '00001',
        gs1KeySerial: 'XYZ001',
      );
      final payload = d.payloadFor(Symbology.qrCode);
      expect(payload, startsWith('https://id.gs1.org/8003/'));
      expect(payload, endsWith('XYZ001'));
    });
  });
}
