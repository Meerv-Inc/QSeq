// Smoke test: proves the QSeq domain core runs as pure Dart (no Flutter),
// which is the whole point of qseq_core for the Jaspr web app.
import 'package:qseq_core/qseq_core.dart';
import 'package:test/test.dart';

void main() {
  test('SGTIN encoders produce the expected representations', () {
    final s = Sgtin(gtin: '80614141123458', serial: '6789');
    expect(s.gtin14, '80614141123458');
    expect(s.toElementString(), '(01)80614141123458(21)6789');
    expect(s.toDigitalLink(), 'https://id.gs1.org/01/80614141123458/21/6789');
    expect(
      s.toDigitalLink(domain: 'https://tapdpp.qdat.io'),
      'https://tapdpp.qdat.io/01/80614141123458/21/6789',
    );
  });

  test('NSN parser validates structure', () {
    final nsn = Nsn('9515-00-003-6945');
    expect(nsn.payload, '9515000036945');
    expect(nsn.formatted, '9515-00-003-6945');
    expect(Nsn.tryParse('nope'), isNull);
  });

  test('Sizer computes a print-true size for a QR Digital Link', () {
    final url = Sgtin(gtin: '80614141123458', serial: '6789').toDigitalLink();
    final r = Sizer.compute(EncodeConfig(symbology: Symbology.qrCode, data: url));
    expect(r.fits, isTrue);
    expect(r.outer.widthMm, greaterThan(0));
    expect(r.outer.widthMm, equals(r.outer.heightMm)); // QR is square
  });

  test('Sizer sizes a 1D GS1-128 element string', () {
    final el = Sgtin(gtin: '80614141123458', serial: '6789').toElementString();
    final r = Sizer.compute(EncodeConfig(symbology: Symbology.gs1_128, data: el));
    expect(r.fits, isTrue);
    expect(r.outer.widthMm, greaterThan(0));
  });
}
