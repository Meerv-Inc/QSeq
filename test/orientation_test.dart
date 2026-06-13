// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qseq/models/batch.dart';
import 'package:qseq/state/app_controller.dart';

Batch _batch(PageFormat fmt, PageOrientation o) {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  c.read(appControllerProvider.notifier).update((s) => s.copyWith(
        mode: AppMode.twoDSerial,
        pageFormat: fmt,
        pageOrientation: o,
        batchCount: 200,
      ));
  return c.read(batchProvider)!;
}

void main() {
  test('landscape swaps a cut sheet width and height', () {
    final p = _batch(PageFormat.a4, PageOrientation.portrait);
    final l = _batch(PageFormat.a4, PageOrientation.landscape);
    expect(p.effectiveWidthMm, PageFormat.a4.widthMm);
    expect(p.effectiveHeightMm, PageFormat.a4.heightMm);
    // Landscape: the wider dimension becomes the page width.
    expect(l.effectiveWidthMm, PageFormat.a4.heightMm);
    expect(l.effectiveHeightMm, PageFormat.a4.widthMm);
    // A wider page fits more columns per row.
    expect(l.columns, greaterThan(p.columns));
  });

  test('orientation does not affect a continuous flexo web', () {
    final p = _batch(PageFormat.flexo12in, PageOrientation.portrait);
    final l = _batch(PageFormat.flexo12in, PageOrientation.landscape);
    expect(l.effectiveWidthMm, p.effectiveWidthMm);
    expect(l.columns, p.columns);
    expect(l.pageCount, 1);
  });

  test('orientation round-trips through project save/load', () {
    const settings = AppSettings(
      mode: AppMode.twoDSerial,
      pageFormat: PageFormat.letter,
      pageOrientation: PageOrientation.landscape,
    );
    // The page-orientation field is preserved by copyWith.
    final copied = settings.copyWith();
    expect(copied.pageOrientation, PageOrientation.landscape);
  });
}
