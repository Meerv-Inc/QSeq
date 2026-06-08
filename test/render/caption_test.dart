import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/models/caption.dart';
import 'package:qr_studio/models/data_source.dart';
import 'package:qr_studio/models/encode_config.dart';
import 'package:qr_studio/models/symbology.dart';
import 'package:qr_studio/render/raster_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('caption derived from SGTIN data source is the serial (bold)', () {
    const d = DataSourceInput(kind: DataSourceKind.sgtin, serial: '6789');
    final cap = d.caption();
    expect(cap.bold, '6789');
    expect(cap.prefix, '');
    expect(cap.isNotEmpty, isTrue);
  });

  test('NSN caption is the dashed number; raw text has none', () {
    expect(const DataSourceInput(kind: DataSourceKind.nsn, nsn: '9515000036945')
            .caption()
            .text,
        '9515-00-003-6945');
    expect(const DataSourceInput(kind: DataSourceKind.rawText).caption().isEmpty,
        isTrue);
  });

  test('caption band makes the rendered image taller than the symbol', () async {
    const cfg = EncodeConfig(
      symbology: Symbology.qrCode,
      data: 'https://id.gs1.org/01/80614141123458/21/6789',
      dpi: 300,
      xDimensionMm: 0.5,
    );
    final plain = await RasterRenderer.render(cfg);
    final withCap = await RasterRenderer.render(cfg,
        caption: const LabelCaption(bold: '6789'));
    expect(withCap.height, greaterThan(plain.height));
    expect(withCap.width, plain.width);
  });
}
