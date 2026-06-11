// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

// Browser download helpers. The real implementation (download_web.dart) uses
// package:web and is only included when compiling for a JS target; the server
// prerender gets the no-op stub so it never tries to compile browser APIs.
export 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
