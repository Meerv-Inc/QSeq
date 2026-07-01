// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:barcode/barcode.dart';

import '../models/symbology.dart';
import '../sizing/pdf417_capacity.dart';

/// Maps the app's [Symbology] + EC level onto a `barcode` package [Barcode]
/// instance and the matching QR correction level.
class BarcodeFactory {
  BarcodeFactory._();

  static Barcode build(
    Symbology symbology, {
    QrEcLevel? ecLevel,
    Pdf417EcLevel? pdf417EcLevel,
  }) {
    return switch (symbology) {
      Symbology.qrCode => Barcode.qrCode(
        errorCorrectLevel: qrLevel(ecLevel ?? QrEcLevel.medium),
      ),
      Symbology.dataMatrix => Barcode.dataMatrix(),
      Symbology.pdf417 => Barcode.pdf417(
        securityLevel: pdf417Level(pdf417EcLevel ?? Pdf417EcLevel.level2),
        moduleHeight: Pdf417Capacity.moduleHeight,
        preferredRatio: Pdf417Capacity.preferredRatio,
      ),
      // GS1-128: the package handles FNC1 + parenthesised AIs natively.
      Symbology.gs1_128 => Barcode.gs128(keepParenthesis: false),
      Symbology.code128 => Barcode.code128(),
      Symbology.code39 => Barcode.code39(),
      Symbology.ean13 => Barcode.ean13(),
      Symbology.ean8 => Barcode.ean8(),
      Symbology.upcA => Barcode.upcA(),
    };
  }

  static BarcodeQRCorrectionLevel qrLevel(QrEcLevel ec) => switch (ec) {
    QrEcLevel.low => BarcodeQRCorrectionLevel.low,
    QrEcLevel.medium => BarcodeQRCorrectionLevel.medium,
    QrEcLevel.quartile => BarcodeQRCorrectionLevel.quartile,
    QrEcLevel.high => BarcodeQRCorrectionLevel.high,
  };

  static Pdf417SecurityLevel pdf417Level(Pdf417EcLevel ec) =>
      Pdf417SecurityLevel.values[ec.index];
}
