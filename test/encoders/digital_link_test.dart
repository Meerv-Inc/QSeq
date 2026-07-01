// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_test/flutter_test.dart';
import 'package:qseq/encoders/digital_link.dart';
import 'package:qseq/encoders/sgtin.dart';

void main() {
  group('DigitalLink.parse — round trip with Sgtin', () {
    test('parses a valid SGTIN digital link as valid', () {
      final sgtin = Sgtin(gtin: '80614141123458', serial: '6789');
      final r = DigitalLink.parse(sgtin.toDigitalLink());
      expect(r.isValid, isTrue, reason: r.issues.join('; '));
      expect(r.identifier?.ai, '01');
      expect(r.identifier?.value, '80614141123458');
      expect(r.qualifiers, hasLength(1));
      expect(r.qualifiers.single.ai, '21');
      expect(r.qualifiers.single.value, '6789');
    });

    test('trace explains why the identifier and qualifier passed', () {
      final sgtin = Sgtin(gtin: '80614141123458', serial: '6789');
      final r = DigitalLink.parse(sgtin.toDigitalLink());
      expect(
        r.trace.any(
          (l) => l.startsWith('✓') && l.contains('01') && l.contains('GTIN'),
        ),
        isTrue,
        reason: r.trace.join('\n'),
      );
      expect(
        r.trace.any(
          (l) => l.startsWith('✓') && l.contains('21') && l.contains('SERIAL'),
        ),
        isTrue,
        reason: r.trace.join('\n'),
      );
      expect(r.trace.last, '✓ RESULT: VALID');
    });

    test('parses a valid SGTIN digital link with a custom domain', () {
      final sgtin = Sgtin(gtin: '80614141123458', serial: '6789');
      final r = DigitalLink.parse(
        sgtin.toDigitalLink(domain: 'https://example.com'),
      );
      expect(r.isValid, isTrue, reason: r.issues.join('; '));
      expect(r.uri?.host, 'example.com');
    });

    test('round-trips a percent-encoded serial back to its raw value', () {
      // '/' needs percent-encoding in the URI but is itself a valid GS1
      // AI-82 character, so the round-tripped serial still validates clean.
      final sgtin = Sgtin(gtin: '80614141123458', serial: 'AB/CD1');
      final r = DigitalLink.parse(sgtin.toDigitalLink());
      expect(r.isValid, isTrue, reason: r.issues.join('; '));
      expect(r.qualifiers.single.value, 'AB/CD1');
    });
  });

  group('DigitalLink.parse — plain GTIN link', () {
    test('a bare /01/<gtin> link is valid with no qualifiers', () {
      final r = DigitalLink.parse('https://id.gs1.org/01/80614141123458');
      expect(r.isValid, isTrue, reason: r.issues.join('; '));
      expect(r.identifier?.ai, '01');
      expect(r.qualifiers, isEmpty);
    });
  });

  group('DigitalLink.parse — structural errors', () {
    test('flags a bad GTIN check digit', () {
      final r = DigitalLink.parse('https://id.gs1.org/01/80614141123455');
      expect(r.isValid, isFalse);
      expect(r.issues.any((i) => i.message.contains('check digit')), isTrue);
      expect(
        r.trace.any((l) => l.startsWith('✗') && l.contains('check digit')),
        isTrue,
        reason: r.trace.join('\n'),
      );
      expect(r.trace.last, startsWith('✗ RESULT: INVALID'));
    });

    test('flags qualifiers out of canonical order', () {
      // Canonical order is 22 (CPV) -> 10 (lot) -> 21 (serial); this has
      // serial before lot.
      final r = DigitalLink.parse(
        'https://id.gs1.org/01/80614141123458/21/6789/10/LOT1',
      );
      expect(r.isValid, isFalse);
      expect(r.issues.any((i) => i.message.contains('out of order')), isTrue);
    });

    test('flags a qualifier not valid for the primary identifier', () {
      // 414 (GLN) does not take a 21 (serial) qualifier.
      final r = DigitalLink.parse(
        'https://id.gs1.org/414/1234567890128/21/6789',
      );
      expect(r.isValid, isFalse);
      expect(
        r.issues.any((i) => i.message.contains('not a valid qualifier')),
        isTrue,
      );
    });

    test('flags a duplicate qualifier', () {
      final r = DigitalLink.parse(
        'https://id.gs1.org/01/80614141123458/21/6789/21/9999',
      );
      expect(r.isValid, isFalse);
      expect(r.issues.any((i) => i.message.contains('more than once')), isTrue);
    });

    test('flags an odd number of path segments', () {
      final r = DigitalLink.parse('https://id.gs1.org/01/80614141123458/21');
      expect(r.isValid, isFalse);
      expect(r.issues.any((i) => i.message.contains('odd number')), isTrue);
    });

    test('flags an unrecognized primary identifier AI', () {
      final r = DigitalLink.parse('https://id.gs1.org/999/12345');
      expect(r.isValid, isFalse);
      expect(
        r.issues.any((i) => i.message.contains('primary identifier')),
        isTrue,
      );
    });

    test('flags a URI with no path at all', () {
      final r = DigitalLink.parse('https://id.gs1.org');
      expect(r.isValid, isFalse);
      expect(r.identifier, isNull);
    });

    test('malformed input does not throw and is reported invalid', () {
      expect(() => DigitalLink.parse('not a uri at all'), returnsNormally);
      final r = DigitalLink.parse('not a uri at all');
      expect(r.isValid, isFalse);
    });
  });

  group('DigitalLink.parse — path stem', () {
    test('captures a custom resolver prefix separately from the AI path', () {
      final r = DigitalLink.parse(
        'https://example.com/some/prefix/01/80614141123458',
      );
      expect(r.isValid, isTrue, reason: r.issues.join('; '));
      expect(r.pathStem, 'some/prefix');
      expect(r.identifier?.value, '80614141123458');
    });
  });

  group('DigitalLink.parse — query string', () {
    test('parses a valid GS1 attribute in the query string', () {
      final r = DigitalLink.parse(
        'https://id.gs1.org/01/80614141123458?17=251231',
      );
      expect(r.isValid, isTrue, reason: r.issues.join('; '));
      expect(r.attributes['17']?.value, '251231');
    });

    test('flags an invalid GS1 attribute value', () {
      final r = DigitalLink.parse(
        'https://id.gs1.org/01/80614141123458?17=abc',
      );
      expect(r.isValid, isFalse);
    });

    test('buckets a non-GS1 query param into "other" without an issue', () {
      final r = DigitalLink.parse(
        'https://id.gs1.org/01/80614141123458?utm_source=email',
      );
      expect(r.isValid, isTrue, reason: r.issues.join('; '));
      expect(r.other['utm_source'], 'email');
    });

    test('warns (but does not invalidate) an unrecognized numeric AI', () {
      final r = DigitalLink.parse(
        'https://id.gs1.org/01/80614141123458?9999=x',
      );
      expect(r.isValid, isTrue, reason: r.issues.join('; '));
      expect(
        r.issues.any((i) => i.severity == DigitalLinkSeverity.warning),
        isTrue,
      );
    });
  });
}
