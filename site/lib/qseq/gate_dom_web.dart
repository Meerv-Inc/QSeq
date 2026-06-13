// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

// Browser implementations (selected on JS targets only) for the licence gate:
// read/store consent, wire the "Open QSeq" triggers, and reveal the generator.
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const _storageKey = 'qseq-license-accepted';

/// True when consent was given within the last 30 days.
bool gateAccepted() {
  try {
    final at = DateTime.tryParse(
        web.window.localStorage.getItem(_storageKey) ?? '');
    return at != null && DateTime.now().difference(at).inDays < 30;
  } catch (_) {
    return false;
  }
}

void gateStoreAccepted() {
  try {
    web.window.localStorage
        .setItem(_storageKey, DateTime.now().toIso8601String());
  } catch (_) {}
}

/// The hero "Open QSeq" button and the nav link both open the app — gated.
void wireOpenButtons(void Function() onOpen) {
  for (final id in const ['openQseq', 'navGenerator']) {
    web.document.getElementById(id)?.addEventListener(
        'click',
        ((web.Event e) {
          e.preventDefault();
          onOpen();
        }).toJS);
  }
}

/// Reveal the (CSS-hidden) generator and scroll to it.
void revealGenerator() {
  web.document.body?.classList.add('qseq-unlocked');
  web.document.getElementById('generator')?.scrollIntoView();
}
