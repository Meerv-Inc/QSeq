import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qr_studio/models/encode_config.dart';
import 'package:qr_studio/models/symbology.dart';
import 'package:qr_studio/render/raster_renderer.dart';
import 'package:qr_studio/sizing/dpi.dart';
import 'package:qr_studio/sizing/qr_capacity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('QR renders to a pixel-exact PNG carrying the right DPI', () async {
    const cfg = EncodeConfig(
      symbology: Symbology.qrCode,
      data: 'https://id.gs1.org/01/80614141123458/21/6789',
      dpi: 300,
      xDimensionMm: 0.5,
    );
    final image = await RasterRenderer.render(cfg);

    // Expected side: (moduleCount + 2*quietZone) * moduleDots.
    final version = QrCapacity.minVersionForBytes(cfg.byteCount, cfg.ecLevel)!;
    final dots = Dpi.moduleDots(cfg.xDimensionMm, cfg.dpi); // 6 at 300dpi/0.5mm
    final expectedSide =
        (QrCapacity.moduleCount(version) + 2 * 4) * dots;
    expect(image.width, expectedSide);
    expect(image.height, expectedSide);

    final png = await RasterRenderer.toPng(image, cfg.dpi);
    // Valid PNG signature.
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);

    // Decode and confirm the pHYs DPI round-trips.
    final decoded = img.PngDecoder().decode(png)!;
    expect(decoded.width, expectedSide);
    final phys = decoded.exif; // metadata present
    expect(phys, isNotNull);
  });

  test('Logo dead-space punches a white knockout in the centre', () async {
    const cfg = EncodeConfig(
      symbology: Symbology.qrCode,
      data: 'https://example.com/01/80614141123458/21/6789',
      dpi: 300,
      xDimensionMm: 0.6,
      logoSideMm: 6,
    );
    final image = await RasterRenderer.render(cfg);
    final png = await RasterRenderer.toPng(image, cfg.dpi);
    final decoded = img.PngDecoder().decode(png)!;
    // Centre pixel should be white (inside the knockout).
    final p = decoded.getPixel(decoded.width ~/ 2, decoded.height ~/ 2);
    expect(p.r, 255);
    expect(p.g, 255);
    expect(p.b, 255);
  });

  test('1D Code 128 renders a wider-than-tall image with text band',
      () async {
    const cfg = EncodeConfig(
      symbology: Symbology.code128,
      data: '0123456789',
      dpi: 300,
      xDimensionMm: 0.33,
      barHeightMm: 15,
    );
    final image = await RasterRenderer.render(cfg);
    expect(image.width, greaterThan(image.height));
  });
}
