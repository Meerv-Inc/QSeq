import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/encoders/sgtin.dart';
import 'package:qr_studio/models/batch.dart';
import 'package:qr_studio/models/symbology.dart';
import 'package:qr_studio/render/batch_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('batch PDF builds valid multi-code bytes', () async {
    final batch = Batch.build(
      use1D: false,
      use2D: true,
      oneDSymbology: Symbology.gs1_128,
      twoDSymbology: Symbology.qrCode,
      prefix: 'SN-',
      start: 1,
      count: 30,
      padding: 4,
      buildOneD: (s) => s,
      buildTwoD: (s) =>
          Sgtin(gtin: '80614141123458', serial: s).toDigitalLink(),
      ecLevel: QrEcLevel.medium,
      dpi: 300,
      xDimensionMm: 0.5,
      barHeightMm: 12,
      logoSideMm: 0,
      logoEcBudget: 0.5,
      page: PageFormat.a4,
    );

    final bytes = await BatchPdf.build(batch);
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
    expect(batch.pageCount, greaterThanOrEqualTo(1));
    expect(batch.columns, greaterThan(1));
  });

  test('combo batch PDF stacks 1D + 2D per cell', () async {
    final batch = Batch.build(
      use1D: true,
      use2D: true,
      oneDSymbology: Symbology.gs1_128,
      twoDSymbology: Symbology.qrCode,
      prefix: '',
      start: 1,
      count: 6,
      padding: 5,
      buildOneD: (s) =>
          Sgtin(gtin: '80614141123458', serial: s).toElementString(),
      buildTwoD: (s) =>
          Sgtin(gtin: '80614141123458', serial: s).toDigitalLink(),
      ecLevel: QrEcLevel.medium,
      dpi: 300,
      xDimensionMm: 0.4,
      barHeightMm: 10,
      logoSideMm: 0,
      logoEcBudget: 0.5,
      page: PageFormat.a4,
    );
    expect(batch.hasOneD && batch.hasTwoD, isTrue);
    final bytes = await BatchPdf.build(batch);
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
  });
}
