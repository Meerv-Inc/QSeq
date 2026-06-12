// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

// Browser implementations (selected on JS targets only): blob downloads, SVG
// rasterization, file pickers, and PDF assembly through the page's jsPDF.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void _save(String filename, JSArray<JSAny> parts, String mime) {
  final blob = web.Blob(parts, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  a.click();
  web.URL.revokeObjectURL(url);
}

void downloadText(String filename, String text, String mime) {
  final bytes = Uint8List.fromList(utf8.encode(text));
  _save(filename, [bytes.toJS].toJS, mime);
}

void downloadBytes(String filename, Uint8List bytes, String mime) {
  _save(filename, [bytes.toJS].toJS, mime);
}

Future<web.HTMLCanvasElement?> _svgToCanvas(String svg, int wPx, int hPx,
    {bool transparent = false}) async {
  final svgUrl = web.URL.createObjectURL(
    web.Blob([svg.toJS].toJS,
        web.BlobPropertyBag(type: 'image/svg+xml;charset=utf-8')),
  );
  final img = web.document.createElement('img') as web.HTMLImageElement;
  img.src = svgUrl;
  try {
    await img.decode().toDart;
  } catch (_) {
    web.URL.revokeObjectURL(svgUrl);
    return null;
  }
  final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
    ..width = wPx
    ..height = hPx;
  final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
  if (!transparent) {
    ctx.fillStyle = 'white'.toJS;
    ctx.fillRect(0, 0, wPx.toDouble(), hPx.toDouble());
  }
  ctx.drawImage(img, 0, 0, wPx.toDouble(), hPx.toDouble());
  web.URL.revokeObjectURL(svgUrl);
  return canvas;
}

Future<String?> rasterizeSvg(String svg, int wPx, int hPx,
    {bool transparent = false}) async {
  final canvas = await _svgToCanvas(svg, wPx, hPx, transparent: transparent);
  return canvas?.toDataURL('image/png');
}

Future<void> downloadSvgPng(
    String filename, String svg, int wPx, int hPx) async {
  final canvas = await _svgToCanvas(svg, wPx, hPx);
  if (canvas == null) return;
  final done = Completer<void>();
  canvas.toBlob(
    (web.Blob? blob) {
      if (blob != null) {
        final url = web.URL.createObjectURL(blob);
        final a = web.document.createElement('a') as web.HTMLAnchorElement
          ..href = url
          ..download = filename;
        a.click();
        web.URL.revokeObjectURL(url);
      }
      done.complete();
    }.toJS,
    'image/png',
  );
  await done.future;
}

Future<String?> pickFile({String accept = '*/*', bool asText = false}) async {
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = accept;
  final done = Completer<String?>();
  input.onchange = (web.Event _) {
    final file = input.files?.item(0);
    if (file == null) {
      done.complete(null);
      return;
    }
    final reader = web.FileReader();
    reader.onload = (web.Event _) {
      done.complete((reader.result as JSString?)?.toDart);
    }.toJS;
    reader.onerror = (web.Event _) {
      done.complete(null);
    }.toJS;
    if (asText) {
      reader.readAsText(file);
    } else {
      reader.readAsDataURL(file);
    }
  }.toJS;
  input.click();
  return done.future;
}

class PdfPageImage {
  final double wMm;
  final double hMm;
  final String pngDataUrl;
  const PdfPageImage(this.wMm, this.hMm, this.pngDataUrl);
}

Future<bool> savePdfPages(String filename, List<PdfPageImage> pages) async {
  if (pages.isEmpty) return false;
  final jspdf = web.window.getProperty('jspdf'.toJS);
  if (jspdf == null || jspdf.isUndefinedOrNull) return false;
  final ctor =
      (jspdf as JSObject).getProperty('jsPDF'.toJS) as JSFunction?;
  if (ctor == null) return false;
  final first = pages.first;
  final opts = JSObject()
    ..setProperty('unit'.toJS, 'mm'.toJS)
    ..setProperty(
        'format'.toJS, [first.wMm.toJS, first.hMm.toJS].toJS)
    ..setProperty('compress'.toJS, true.toJS);
  final doc = ctor.callAsConstructor<JSObject>(opts);
  for (var p = 0; p < pages.length; p++) {
    final page = pages[p];
    if (p > 0) {
      doc.callMethodVarArgs('addPage'.toJS, [
        [page.wMm.toJS, page.hMm.toJS].toJS,
      ]);
    }
    doc.callMethodVarArgs('addImage'.toJS, [
      page.pngDataUrl.toJS,
      'PNG'.toJS,
      0.toJS,
      0.toJS,
      page.wMm.toJS,
      page.hMm.toJS,
    ]);
  }
  doc.callMethodVarArgs('save'.toJS, [filename.toJS]);
  return true;
}
