// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/models/data_source.dart';
import 'package:qr_studio/models/symbology.dart';
import 'package:qr_studio/state/app_controller.dart';

void main() {
  test('default 2D workspace sizes a QR Digital Link', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final size = container.read(singleSizeProvider);
    expect(size, isNotNull);
    expect(size!.fits, isTrue);
    expect(size.outer.widthMm, greaterThan(0));
  });

  test('combo mode pairs 1D + 2D for the same SGTIN', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appControllerProvider.notifier).update(
          (s) => s.copyWith(mode: AppMode.combo),
        );

    final label = container.read(combinedLabelProvider);
    expect(label, isNotNull);
    expect(label!.oneD.symbology, Symbology.gs1_128);
    expect(label.twoD.symbology, Symbology.qrCode);
    expect(label.oneD.data, startsWith('(01)'));
    expect(label.twoD.data, contains('/01/'));
    expect(label.outer.widthMm, greaterThan(label.twoDSize.outer.widthMm));
  });

  test('mode capability getters are correct', () {
    expect(AppMode.oneD.use1D, isTrue);
    expect(AppMode.oneD.use2D, isFalse);
    expect(AppMode.twoDSerial.isSerialized, isTrue);
    expect(AppMode.comboSerial.isCombo, isTrue);
    expect(AppMode.comboSerial.isSerialized, isTrue);
  });

  test('NSN data source resolves to the plain 13-digit payload', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appControllerProvider.notifier).update(
          (s) => s.copyWith(
            mode: AppMode.twoD,
            data: const DataSourceInput(kind: DataSourceKind.nsn),
          ),
        );
    final s = container.read(appControllerProvider);
    expect(s.resolved.data, '9515000036945');
  });
}
