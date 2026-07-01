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

  test('Sizer computes a print-true size for a QR Digital Link', () {
    final url = Sgtin(gtin: '80614141123458', serial: '6789').toDigitalLink();
    final r = Sizer.compute(
      EncodeConfig(symbology: Symbology.qrCode, data: url),
    );
    expect(r.fits, isTrue);
    expect(r.outer.widthMm, greaterThan(0));
    expect(r.outer.widthMm, equals(r.outer.heightMm)); // QR is square
  });

  test('Sizer sizes a 1D GS1-128 element string', () {
    final el = Sgtin(gtin: '80614141123458', serial: '6789').toElementString();
    final r = Sizer.compute(
      EncodeConfig(symbology: Symbology.gs1_128, data: el),
    );
    expect(r.fits, isTrue);
    expect(r.outer.widthMm, greaterThan(0));
  });

  test('DigitalLink round-trips and validates a Digital Link URI', () {
    final url = Sgtin(gtin: '80614141123458', serial: '6789').toDigitalLink();
    final r = DigitalLink.parse(url);
    expect(r.isValid, isTrue, reason: r.issues.join('; '));
    expect(r.identifier?.ai, '01');
    expect(r.qualifiers.single.ai, '21');
  });

  test('DigitalLink flags a bad GTIN check digit', () {
    final r = DigitalLink.parse('https://id.gs1.org/01/80614141123455');
    expect(r.isValid, isFalse);
  });

  test('Gs1Keys builds a check-digited GRAI with a serial', () {
    final g = Gs1Keys.grai(
      companyPrefix: '0614141',
      assetType: '00001',
      serial: 'XYZ001',
    );
    expect(g.value.length, 20);
    expect(Gtin.isValid(g.value.substring(0, 14)), isTrue);
    expect(g.toDigitalLink(), 'https://id.gs1.org/8003/${g.value}');
  });

  test('Sizer computes a print-true size for a PDF417 Digital Link', () {
    final url = Sgtin(gtin: '80614141123458', serial: '6789').toDigitalLink();
    final r = Sizer.compute(
      EncodeConfig(symbology: Symbology.pdf417, data: url),
    );
    expect(r.fits, isTrue);
    expect(r.geometryLabel, contains('Level 2'));
    expect(r.outer.widthMm, greaterThan(0));
  });

  test('a PDF417 2D symbol forces a stacked CombinedLabel arrangement', () {
    final sgtin = Sgtin(gtin: '80614141123458', serial: '6789');
    final label = CombinedLabel.fromSgtin(
      sgtin: sgtin,
      twoDSymbology: Symbology.pdf417,
      digitalLinkDomain: 'https://id.gs1.org',
      dpi: 300,
      xDimensionMm: 0.33,
      barHeightMm: 12,
      ecLevel: QrEcLevel.medium,
      arrangement: LabelArrangement.sideBySide,
      gapMm: 2,
      paddingMm: 2,
    );
    expect(label.arrangement, LabelArrangement.stacked);
  });

  test('DataSourceInput builds a GS1 key type via qseq_core too', () {
    const d = DataSourceInput(
      gs1KeyType: Gs1KeyType.gln,
      gs1CompanyPrefix: '0614141',
      gs1Reference: '00001',
    );
    final r = d.resolve();
    expect(r.error, isNull);
    expect(r.data, startsWith('https://id.gs1.org/414/'));
  });
}
