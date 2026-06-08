// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/models/batch.dart';
import 'package:qr_studio/state/app_controller.dart';

void main() {
  test('serialized 2D sheet generates sequential bold-counter serials', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appControllerProvider.notifier).update(
          (s) => s.copyWith(
            mode: AppMode.twoDSerial,
            batchPrefix: 'LOT-',
            batchStart: 8,
            batchCount: 5,
            batchPadding: 4,
          ),
        );

    final batch = container.read(batchProvider)!;
    expect(batch.items.length, 5);
    expect(batch.hasTwoD, isTrue);
    expect(batch.hasOneD, isFalse);

    final first = batch.items.first;
    expect(first.prefix, 'LOT-');
    expect(first.counter, '0008');
    expect(first.serial, 'LOT-0008');
    expect(first.twoDData, contains('LOT-0008'));

    expect(batch.items.last.counter, '0012');
    expect(batch.columns, greaterThan(0));
    expect(batch.pageCount, greaterThanOrEqualTo(1));
  });

  test('serialized combo sheet carries both 1D element string and 2D link', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appControllerProvider.notifier).update(
          (s) => s.copyWith(
            mode: AppMode.comboSerial,
            batchPrefix: '',
            batchStart: 1,
            batchCount: 3,
            batchPadding: 5,
          ),
        );

    final batch = container.read(batchProvider)!;
    expect(batch.hasOneD, isTrue);
    expect(batch.hasTwoD, isTrue);
    final first = batch.items.first;
    expect(first.oneDData, startsWith('(01)')); // element string
    expect(first.twoDData, contains('/21/00001')); // digital link w/ serial
  });

  test('serial log enumerates every serial', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appControllerProvider.notifier).update(
          (s) => s.copyWith(mode: AppMode.oneDSerial, batchCount: 4),
        );
    expect(container.read(serialLogProvider).length, 4);
  });

  test('PageFormat dimensions are correct', () {
    expect(PageFormat.a4.widthMm, 210);
    expect(PageFormat.letter.heightMm, closeTo(279.4, 0.01));
  });
}
