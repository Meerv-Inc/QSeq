// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_test/flutter_test.dart';
import 'package:qseq/models/label_spec.dart';

void main() {
  group('autoArrangeLabel', () {
    test('places 2D and 1D side by side by default', () {
      final spec = LabelSpec();
      autoArrangeLabel(spec, (w: 20, h: 20), (w: 40, h: 10));
      expect(labelLayoutIsSideBySide(spec), isTrue);
    });

    test('stacked2D forces the 2D element above the 1D element', () {
      final spec = LabelSpec();
      autoArrangeLabel(spec, (w: 60, h: 15), (w: 40, h: 10),
          stacked2D: true);
      final twoD = spec.rects['twoD']!, oneD = spec.rects['oneD']!;
      expect(twoD.y + twoD.h, lessThanOrEqualTo(oneD.y + 0.01));
      expect(labelLayoutIsSideBySide(spec), isFalse);
    });

    test('stacked2D elements stay within the label width', () {
      final spec = LabelSpec(wMm: 40, hMm: 60);
      autoArrangeLabel(spec, (w: 60, h: 15), (w: 40, h: 10),
          stacked2D: true);
      final twoD = spec.rects['twoD']!, oneD = spec.rects['oneD']!;
      expect(twoD.x, greaterThanOrEqualTo(0));
      expect(twoD.x + twoD.w, lessThanOrEqualTo(spec.wMm + 0.01));
      expect(oneD.x, greaterThanOrEqualTo(0));
      expect(oneD.x + oneD.w, lessThanOrEqualTo(spec.wMm + 0.01));
    });
  });

  group('labelLayoutIsSideBySide', () {
    test('false when either rect is missing', () {
      final spec = LabelSpec();
      expect(labelLayoutIsSideBySide(spec), isFalse);
    });

    test('detects a stale side-by-side layout after switching to PDF417 — '
        're-running autoArrangeLabel with stacked2D fixes it', () {
      final spec = LabelSpec();
      // Simulate a design made while 2D was QR/Data Matrix.
      autoArrangeLabel(spec, (w: 20, h: 20), (w: 40, h: 10));
      expect(labelLayoutIsSideBySide(spec), isTrue);

      // Switching the 2D symbology to PDF417 doesn't move the rects by
      // itself — re-arranging with stacked2D is what fixes it.
      autoArrangeLabel(spec, (w: 60, h: 15), (w: 40, h: 10),
          stacked2D: true);
      expect(labelLayoutIsSideBySide(spec), isFalse);
    });
  });
}
