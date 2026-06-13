// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

// Licence-gate DOM helpers: server-safe stubs by default, real browser
// implementations on JS targets.
export 'gate_dom_stub.dart' if (dart.library.js_interop) 'gate_dom_web.dart';
