// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_test/flutter_test.dart';
import 'package:qseq/encoders/gs1_keys.dart';
import 'package:qseq/encoders/gtin.dart';

void main() {
  group('Gs1Keys.grai', () {
    test('builds a 14-digit check-digited key with no serial', () {
      final g = Gs1Keys.grai(companyPrefix: '0614141', assetType: '00001');
      expect(g.value.length, 14);
      expect(Gtin.isValid(g.value), isTrue);
      expect(g.type.ai, '8003');
      expect(g.toElementString(), '(8003)${g.value}');
      expect(g.toDigitalLink(), 'https://id.gs1.org/8003/${g.value}');
    });

    test('appends an alphanumeric serial for an individual asset', () {
      final g = Gs1Keys.grai(
        companyPrefix: '0614141',
        assetType: '00001',
        serial: 'XYZ001',
      );
      expect(g.value.length, 20); // 14 + 6
      expect(g.value.endsWith('XYZ001'), isTrue);
      expect(Gtin.isValid(g.value.substring(0, 14)), isTrue);
    });

    test('rejects a wrong-length company prefix + asset type', () {
      expect(
        () => Gs1Keys.grai(companyPrefix: '061414', assetType: '00001'),
        throwsFormatException,
      );
    });

    test('rejects an oversized serial', () {
      expect(
        () => Gs1Keys.grai(
          companyPrefix: '0614141',
          assetType: '00001',
          serial: 'A' * 17,
        ),
        throwsFormatException,
      );
    });

    test('Gs1KeyType.grai supports a serial', () {
      expect(Gs1KeyType.grai.supportsSerial, isTrue);
    });
  });

  group('Gs1Keys.gdti', () {
    test('builds a 13-digit check-digited key', () {
      final g = Gs1Keys.gdti(companyPrefix: '0614141', docType: '00001');
      expect(g.value.length, 13);
      expect(Gtin.isValid(g.value), isTrue);
      expect(g.type.ai, '253');
    });

    test('appends an alphanumeric serial', () {
      final g = Gs1Keys.gdti(
        companyPrefix: '0614141',
        docType: '00001',
        serial: 'AB12',
      );
      expect(g.value.length, 17); // 13 + 4
    });
  });

  group('Gs1Keys.gcn', () {
    test('builds a 13-digit check-digited key', () {
      final g = Gs1Keys.gcn(companyPrefix: '0614141', couponRef: '00001');
      expect(g.value.length, 13);
      expect(Gtin.isValid(g.value), isTrue);
      expect(g.type.ai, '255');
    });

    test('accepts a numeric serial', () {
      final g = Gs1Keys.gcn(
        companyPrefix: '0614141',
        couponRef: '00001',
        serial: '123456',
      );
      expect(g.value.length, 19); // 13 + 6
    });

    test('rejects a non-numeric serial (GCN serial is digits-only)', () {
      expect(
        () => Gs1Keys.gcn(
          companyPrefix: '0614141',
          couponRef: '00001',
          serial: 'ABC123',
        ),
        throwsFormatException,
      );
    });
  });

  group('Gs1Keys.gln', () {
    test('builds a 13-digit check-digited location number', () {
      final g = Gs1Keys.gln(companyPrefix: '0614141', locationRef: '00001');
      expect(g.value.length, 13);
      expect(Gtin.isValid(g.value), isTrue);
      expect(g.type.ai, '414');
    });
  });

  group('Gs1Keys.sscc', () {
    test('builds an 18-digit check-digited SSCC', () {
      final g = Gs1Keys.sscc(
        extensionDigit: 3,
        companyPrefix: '0614141',
        serialRef: '000000001',
      );
      expect(g.value.length, 18);
      expect(Gtin.isValid(g.value), isTrue);
      expect(g.value.startsWith('3'), isTrue);
      expect(g.type.ai, '00');
    });

    test('rejects an out-of-range extension digit', () {
      expect(
        () => Gs1Keys.sscc(
          extensionDigit: 10,
          companyPrefix: '0614141',
          serialRef: '000000001',
        ),
        throwsArgumentError,
      );
      expect(
        () => Gs1Keys.sscc(
          extensionDigit: -1,
          companyPrefix: '0614141',
          serialRef: '000000001',
        ),
        throwsArgumentError,
      );
    });
  });

  group('Gs1Keys.gsrn', () {
    test('defaults to the provider AI (8017)', () {
      final g = Gs1Keys.gsrn(
        companyPrefix: '0614141',
        serviceRef: '0000000001',
      );
      expect(g.value.length, 18);
      expect(Gtin.isValid(g.value), isTrue);
      expect(g.type.ai, '8017');
    });

    test('recipient: true selects AI 8018', () {
      final g = Gs1Keys.gsrn(
        companyPrefix: '0614141',
        serviceRef: '0000000001',
        recipient: true,
      );
      expect(g.type.ai, '8018');
    });
  });

  group('Gs1Keys.gsin', () {
    test('builds a 17-digit check-digited GSIN', () {
      final g = Gs1Keys.gsin(companyPrefix: '0614141', shipperRef: '000000001');
      expect(g.value.length, 17);
      expect(Gtin.isValid(g.value), isTrue);
      expect(g.type.ai, '402');
    });
  });

  group('Gs1Keys.giai', () {
    test('concatenates prefix + asset reference with no check digit', () {
      final g = Gs1Keys.giai(companyPrefix: '0614141', assetRef: 'FORKLIFT-42');
      expect(g.value, '0614141FORKLIFT-42');
      expect(g.type.ai, '8004');
    });

    test('rejects a value over 30 characters', () {
      expect(
        () => Gs1Keys.giai(companyPrefix: '0614141', assetRef: 'X' * 25),
        throwsFormatException,
      );
    });

    test('rejects an unsupported character (e.g. a space)', () {
      expect(
        () => Gs1Keys.giai(companyPrefix: '0614141', assetRef: 'A B'),
        throwsFormatException,
      );
    });
  });

  group('Gs1Keys.ginc', () {
    test('accepts a free-form value', () {
      final g = Gs1Keys.ginc(value: 'CONSIGN-0001');
      expect(g.value, 'CONSIGN-0001');
      expect(g.type.ai, '401');
    });

    test('rejects an empty value', () {
      expect(() => Gs1Keys.ginc(value: ''), throwsFormatException);
    });
  });

  group('Gs1Keys.cpid', () {
    test('concatenates prefix + component reference', () {
      final g = Gs1Keys.cpid(companyPrefix: '0614141', componentRef: 'PART9');
      expect(g.value, '0614141PART9');
      expect(g.type.ai, '8010');
    });
  });

  group('Gs1Keys.gmn', () {
    test('accepts a free-form model number up to 25 characters', () {
      final g = Gs1Keys.gmn(value: 'MODEL-X1');
      expect(g.value, 'MODEL-X1');
      expect(g.type.ai, '8013');
    });

    test('rejects a value over 25 characters', () {
      expect(() => Gs1Keys.gmn(value: 'M' * 26), throwsFormatException);
    });
  });

  group('gs1KeyStructureDescription', () {
    test('describes GTIN/SGTIN for null and mentions its digit lengths', () {
      final d = gs1KeyStructureDescription(null);
      expect(d, contains('GTIN'));
      expect(d, contains('14'));
    });

    test('gives a non-empty description for every key type', () {
      for (final t in Gs1KeyType.values) {
        expect(gs1KeyStructureDescription(t), isNotEmpty);
      }
      // GSRN Provider/Recipient share identical structure, so they share one
      // description; every other type has its own distinct text.
      final descriptions = Gs1KeyType.values.map(gs1KeyStructureDescription);
      expect(descriptions.toSet().length, Gs1KeyType.values.length - 1);
    });

    test('mentions the check digit total for GRAI', () {
      expect(
        gs1KeyStructureDescription(Gs1KeyType.grai),
        contains('14 digits'),
      );
    });
  });
}
