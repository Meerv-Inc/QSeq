// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

import '../version.dart';

/// The development register: each entry is one milestone of QSeq's build.
const List<(String, String)> _register = [
  ('Core engine',
      'QR, Data Matrix and 1D (GS1-128 / Code 128 / Code 39 / EAN-13 / UPC-A) generation with a live physical-size calculator: outer perimeter as a function of logo dead-space, byte count, DPI and error correction.'),
  ('GS1 identity',
      'SGTIN in three forms — element string, EPC Tag URI and GS1 Digital Link — plus configurable resolver domains.'),
  ('Combined labels', '1D + 2D for the same item on one larger label.'),
  ('Serial captions', 'The serial printed under every code, incrementing digits in bold.'),
  ('Structure-aware dead-space',
      'Centre logo never destroys QR finder, timing or alignment patterns — they show through.'),
  ('Composable workspaces',
      '1D / 2D / combined, each as a single design or a serialized sheet, with a live Serialization Log.'),
  ('Project files', 'All raw parameters saved as well-formatted, externally-editable JSON.'),
  ('Print-true rulers', 'mm + inch scales with vernier ticks on every sheet, at exact DPI.'),
  ('Cross-platform desktop',
      'Native macOS (signed & notarized) and Windows builds from one Dart codebase, alongside the web app.'),
  ('Layout controls',
      'Portrait / landscape orientation and a zoom-to-fit preview for serialized sheets.'),
];

/// End-user Release Notes — an excerpt of CHANGELOG.md relevant to users.
const List<String> _releaseNotes = [
  'Companion website rebuilt on a single Dart codebase (Jaspr) — the web generator now runs the exact same encoders and sizing engine as the desktop app, so an identity minted on macOS, Windows or the web is byte-for-byte the same.',
  'Meet QRPic, our MIT-licensed Android sister app: scan a logo\'d QR code and see exactly how much of its error-correction budget the logo spends — downloadable from qseq.app.',
  'Run on Windows too — a native desktop build alongside the signed & notarized macOS app.',
  'Choose portrait or landscape orientation for serialized cut-sheet layouts, with a zoom-to-fit preview.',
  'Serialized sheets reworked so the on-screen preview tracks the printed pages.',
  'Place a centre logo as an image in the cleared 2D dead-space (web), or remove it.',
  'Measurement rulers stay clear of the code in single-code PDF exports.',
  'Generate QR Code, Data Matrix and 1D barcodes (GS1-128, Code 128, Code 39, EAN-13, UPC-A).',
  'Encode SGTINs as GS1 element strings, EPC Tag URIs, or GS1 Digital Links.',
  'Choose your Digital Link resolver — GS1 (id.gs1.org) or QDat.io (tapdpp.qdat.io).',
  'Build serialized sheets and page through them by page size — A4, Letter, A3, Legal, or a flexographic continuous web — with a full serial log of every encoded link.',
  'See the exact printed size live, with mm/inch/vernier rulers on screen and in exports.',
  'Reserve a clean centre zone for a logo — a square free of all code, sized within the error-correction budget.',
  'Export PNG (exact DPI), SVG and PDF; save and open designs as JSON projects.',
];

/// Shows the About sheet: how QSeq was built and why it is open source.
Future<void> showAboutSheet(BuildContext context) async {
  await showMacosSheet(
    context: context,
    builder: (context) {
      final t = MacosTheme.of(context).typography;
      Widget h(String s) => Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 6),
            child: Text(s, style: t.title2.copyWith(fontWeight: FontWeight.w600)),
          );
      Widget p(String s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(s, style: t.body),
          );
      Widget qBullet(String term, String s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: 'Q — $term.  ',
                  style: t.body.copyWith(fontWeight: FontWeight.bold)),
              TextSpan(text: s, style: t.body),
            ])),
          );

      return MacosSheet(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const MacosIcon(CupertinoIcons.qrcode, size: 30),
                const SizedBox(width: 12),
                Text('QSeq', style: t.largeTitle.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MacosColors.systemGrayColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('v$kAppVersion',
                      style: t.caption1.copyWith(fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Text('© 2026 Meerv Inc.',
                    style: t.caption1.copyWith(color: MacosColors.systemGrayColor)),
              ]),
              const SizedBox(height: 4),
              Text(kVersionLabel,
                  style: t.caption1.copyWith(color: MacosColors.systemGrayColor)),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      h('Release Notes — v$kAppVersion ($kBuildDate)'),
                      for (final n in _releaseNotes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text.rich(TextSpan(children: [
                            TextSpan(text: '•  ', style: t.body),
                            TextSpan(text: n, style: t.body),
                          ])),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Text('Full history in CHANGELOG.md.',
                            style: t.caption1.copyWith(
                                color: MacosColors.systemGrayColor)),
                      ),
                      h('Support'),
                      p('Questions, bug reports or feature requests? Email '
                          'support@meerv.com and include your version (shown '
                          'above) and platform — macOS, Windows or web. We read '
                          'every message.'),
                      h('Why “QSeq”?'),
                      p('Seq is sequence — QSeq mints ordered, serialized '
                          'identities. The Q is chosen deliberately; every '
                          'reading of it lands on what a sequence of identity '
                          'codes must be: ordered, robust and resolvable.'),
                      qBullet('Quality factor',
                          'In physics, Q measures how well a resonator preserves energy against loss. A QSeq code is built the same way — its error-correction budget and structure-aware dead-space are a literal quality factor for how much damage an identity can take and still resolve.'),
                      qBullet('Time quanta',
                          'A quantum is the smallest indivisible step. Serialization advances one quantum at a time — each code is the next discrete tick, never skipped, never repeated.'),
                      qBullet('Queue',
                          'An ordered set processed in order. A serialized sheet is a queue of identities, minted and consumed first-to-last.'),
                      qBullet('Cue',
                          'The signal that triggers the next action. Every scannable code is a cue: scan it, it resolves, the next step fires.'),
                      qBullet('QR',
                          'And the canonical 2D carrier itself begins with Q.'),
                      p('Quality factor, quanta, queue, cue, QR — four meanings '
                          'and a carrier, each independently true, all pointing '
                          'to the same idea: a quality-assured, ordered, '
                          'resolvable sequence of identity codes. That is QSeq.'),
                      h('How it was built'),
                      p('QSeq was designed and written from an empty directory '
                          'to tested, native macOS and Windows desktop '
                          'applications and a companion website. Every feature '
                          'below was added '
                          'iteratively, each verified with automated tests and a '
                          'real build before moving on. The domain core (encoders, '
                          'capacity tables, '
                          'sizing and rendering) is covered by 60+ unit and rendering '
                          'tests.'),
                      h('Development register'),
                      for (var i = 0; i < _register.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text.rich(TextSpan(children: [
                            TextSpan(
                                text:
                                    '${(i + 1).toString().padLeft(2, '0')}.  ${_register[i].$1} — ',
                                style: t.body
                                    .copyWith(fontWeight: FontWeight.bold)),
                            TextSpan(text: _register[i].$2, style: t.body),
                          ])),
                        ),
                      h('Why Flutter?'),
                      p('QSeq is written in Flutter / Dart so a single codebase '
                          'serves every surface. The macOS and Windows desktop '
                          'apps are built from it, and the same source compiles '
                          'to the web — the companion website mirrors this exact '
                          'logic. One '
                          'implementation of the encoders, capacity tables, '
                          'sizing and rendering means an identity minted on '
                          'macOS, Windows or the browser is byte-for-byte the '
                          'same. Sustainable Identity needs sustainable, '
                          'portable tooling — a single, open, well-tested '
                          'codebase across desktop and web is the cheapest path '
                          'to keeping these tools alive and consistent.'),
                      h('Why this is open source'),
                      p('QSeq is released as open source to accelerate the transition '
                          'to Sustainable Identity on Every Thing: a future in '
                          'which every physical object carries an open, web-resolvable, '
                          'standards-based identity — GS1 Digital Links, SGTINs and '
                          'compatible carriers — that anyone can read, verify and build '
                          'upon without proprietary lock-in.'),
                      p('Durable, interoperable identity is the foundation of circular '
                          'supply chains: reuse, repair, recall, provenance and '
                          'end-of-life tracking all depend on a code that still resolves '
                          'years later. Keeping the tools that mint those identities open '
                          'means the infrastructure of identity stays a public good, not '
                          'a toll booth. We invite you to use it, fork it, and help put a '
                          'sustainable identity on every thing.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: PushButton(
                  controlSize: ControlSize.large,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
