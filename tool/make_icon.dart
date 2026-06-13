// Generates the app-icon masters from the QSeq wordmark logo.
//   images/app_icon.png     — 1024² wordmark centred on white (legacy/iOS/macOS/Windows)
//   images/app_icon_fg.png  — 1024² wordmark on transparent, sized for the
//                             Android adaptive-icon safe zone.
// Run: dart run tool/make_icon.dart
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final logo = img.decodePng(File('images/qseq.png').readAsBytesSync());
  if (logo == null) {
    stderr.writeln('could not read images/qseq.png');
    exit(1);
  }

  img.Image compose(int size, double widthFrac, {img.Color? background}) {
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    if (background != null) {
      img.fill(canvas, color: background);
    }
    final targetW = (size * widthFrac).round();
    final targetH = (targetW * logo.height / logo.width).round();
    final scaled = img.copyResize(logo,
        width: targetW,
        height: targetH,
        interpolation: img.Interpolation.cubic);
    img.compositeImage(canvas, scaled,
        dstX: ((size - targetW) / 2).round(),
        dstY: ((size - targetH) / 2).round());
    return canvas;
  }

  final white = img.ColorRgb8(255, 255, 255);
  // Legacy / iOS / macOS / Windows: wordmark fills ~80% width on white.
  File('images/app_icon.png')
      .writeAsBytesSync(img.encodePng(compose(1024, 0.80, background: white)));
  // Android adaptive foreground: keep inside the ~66% safe zone, transparent.
  File('images/app_icon_fg.png')
      .writeAsBytesSync(img.encodePng(compose(1024, 0.62)));
  stdout.writeln('wrote images/app_icon.png and images/app_icon_fg.png');
}
