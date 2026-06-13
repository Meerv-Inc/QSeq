// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qseq/models/batch.dart';
import 'package:qseq/state/app_controller.dart';

void main() {
  test('serialized 2D sheet increments from the data serial itself', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // The run derives from the Serial field: trailing digits are the counter
    // (leading zeros preserved), leading text is the fixed prefix.
    container.read(appControllerProvider.notifier).update(
          (s) => s.copyWith(
            mode: AppMode.twoDSerial,
            batchCount: 5,
            data: s.data.copyWith(serial: 'LOT-0008'),
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
            batchCount: 3,
            data: s.data.copyWith(serial: '00001'),
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

  test('sheet of copies increments too, counted by Copies', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appControllerProvider.notifier).update(
          (s) => s.copyWith(mode: AppMode.twoDSheet, batchCopies: 7),
        );
    final batch = container.read(batchProvider)!;
    expect(batch.items.length, 7);
    // Default serial 6789 → 6789..6795, each distinct.
    expect(batch.items.first.serial, '6789');
    expect(batch.items.last.serial, '6795');
    expect(container.read(serialLogProvider).toSet().length, 7);
  });

  test('PageFormat dimensions are correct', () {
    expect(PageFormat.a4.widthMm, 210);
    expect(PageFormat.letter.heightMm, closeTo(279.4, 0.01));
  });
}
