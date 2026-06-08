import 'package:barcode/barcode.dart';

import '../models/symbology.dart';

/// Maps the app's [Symbology] + EC level onto a `barcode` package [Barcode]
/// instance and the matching QR correction level.
class BarcodeFactory {
  BarcodeFactory._();

  static Barcode build(Symbology symbology, {QrEcLevel? ecLevel}) {
    return switch (symbology) {
      Symbology.qrCode => Barcode.qrCode(
          errorCorrectLevel: qrLevel(ecLevel ?? QrEcLevel.medium)),
      Symbology.dataMatrix => Barcode.dataMatrix(),
      // GS1-128: the package handles FNC1 + parenthesised AIs natively.
      Symbology.gs1_128 => Barcode.gs128(keepParenthesis: false),
      Symbology.code128 => Barcode.code128(),
      Symbology.code39 => Barcode.code39(),
      Symbology.ean13 => Barcode.ean13(),
      Symbology.upcA => Barcode.upcA(),
    };
  }

  static BarcodeQRCorrectionLevel qrLevel(QrEcLevel ec) => switch (ec) {
        QrEcLevel.low => BarcodeQRCorrectionLevel.low,
        QrEcLevel.medium => BarcodeQRCorrectionLevel.medium,
        QrEcLevel.quartile => BarcodeQRCorrectionLevel.quartile,
        QrEcLevel.high => BarcodeQRCorrectionLevel.high,
      };
}
