// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

// Browser download implementation (selected on JS targets only).
import 'dart:convert';
import 'dart:js_interop';
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
