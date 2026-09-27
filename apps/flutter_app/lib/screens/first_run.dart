// First run — one page, once.
//
// Not an onboarding of ten screens. Four lines of what this program does not do,
// one line of what it does, a language, and away. No e-mail, no account, no
// permission it does not need.
//
// It is written in both languages because the choice on it is a language choice:
// a page that asked «Deutsch oder English?» in English only would be asking the
// question in the answer.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/widgets/bits.dart';

class FirstRunScreen extends StatefulWidget {
  const FirstRunScreen({super.key, required this.ground, required this.onStart});

  final Ground ground;
  final void Function(String language) onStart;

  @override
  State<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends State<FirstRunScreen> {
  String _language = 'en';

  @override
  Widget build(BuildContext context) {
    final de = _language == 'de';
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const ZMark(size: 38),
                    const SizedBox(width: 13),
                    Text('Z Privacy', style: Zc.h1.copyWith(fontSize: 28)),
                  ],
                ),
                const SizedBox(height: 30),
                for (final line in de
                    ? const ['Kein Konto.', 'Keine Werbung.', 'Keine Analyse.', 'Kein Z-Privacy-Server.']
                    : const ['No account.', 'No ads.', 'No analytics.', 'No Z Privacy server.'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text(
                      line,
                      style: const TextStyle(fontSize: 17, height: 1.3, fontWeight: FontWeight.w600, color: Zc.ink),
                    ),
                  ),
                const SizedBox(height: 22),
                Text(
                  de
                      ? 'Ihre Originaldaten bleiben auf diesem Gerät. Gesendet wird nur die '
                          'geschützte Fassung, und nur wenn Sie sich entscheiden, einen '
                          'KI-Anbieter zu nutzen.'
                      : 'Your original data stays on this device. Only the protected version is '
                          'sent, and only when you choose to use an AI provider.',
                  style: Zc.body.copyWith(fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 30),
                Eyebrow(de ? 'Sprache' : 'Language'),
                const SizedBox(height: 9),
                Row(
                  children: [
                    _Lang(label: 'Deutsch', on: de, onTap: () => setState(() => _language = 'de')),
                    const SizedBox(width: 9),
                    _Lang(label: 'English', on: !de, onTap: () => setState(() => _language = 'en')),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  de
                      ? 'Wählt zunächst das Privacy Pack — die Regeln, nach denen gesucht wird. '
                          'Die Oberfläche ist vorerst auf Englisch.'
                      : 'This picks the privacy pack — the rules the scanner looks with. The '
                          'interface is English for now.',
                  style: Zc.tiny.copyWith(letterSpacing: 0),
                ),
                const SizedBox(height: 28),
                ZButton(
                  label: de ? 'Starten' : 'Start',
                  filled: true,
                  onPressed: () => widget.onStart(_language),
                ),
                const SizedBox(height: 34),
                Text('by YourVoices', style: Zc.tiny.copyWith(letterSpacing: 0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Lang extends StatelessWidget {
  const _Lang({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: on ? Zc.clayWash : Zc.card,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: on ? Zc.clayEdge : Zc.line),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: on ? Zc.clayDeep : Zc.ink2,
              ),
            ),
          ),
        ),
      );
}
