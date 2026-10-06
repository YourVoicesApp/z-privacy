// First run — one page, once.
//
// Not an onboarding of ten screens. Four lines of what this program does not do,
// two lines of what it does, a language, and away. No e-mail, no account, no
// permission it does not need.
//
// It is written in both languages because the choice on it is a language choice:
// a page that asked «Deutsch oder English?» in English only would be asking the
// question in the answer.
//
// That was written here as a comment while the code did the opposite — the state
// began at `en`, so a fresh install read the promise in English and the German
// text existed only for someone who had already found the button. P2-6: nothing
// is assumed. Before a choice **both** promises stand on the page, neither
// button is on, and there is no Start yet.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/widgets/bits.dart';

/// What the product does not do, and what it does — in one place per language.
///
/// The two paragraphs carry a correction of the owner's, 30 September: «your
/// original data stays on this device» must not be read as «it can never
/// leave», because `Copy Restored` exists and puts real values on the clipboard
/// when a person asks for them. The sentence names that exception itself rather
/// than being quietly wrong about it.
class _Promise {
  const _Promise({
    required this.name,
    required this.nots,
    required this.paragraphs,
    required this.rules,
    required this.start,
  });

  /// The language's own name for itself.
  final String name;
  final List<String> nots;
  final List<String> paragraphs;

  /// What choosing this language actually does — said before Start, because a
  /// person picking «Deutsch» must not have to discover afterwards that only
  /// the rules changed.
  final List<String> rules;
  final String start;
}

const _de = _Promise(
  name: 'Deutsch',
  nots: [
    'Kein Konto.',
    'Keine Werbung.',
    'Keine Analyse- oder Tracking-Daten.',
    'Kein Z-Privacy-Server.',
  ],
  paragraphs: [
    'Ihre Originaldaten bleiben auf diesem Gerät, es sei denn, Sie kopieren '
        'ausdrücklich wiederhergestellte Inhalte.',
    'Über Z Privacy wird nur die geschützte Version an eine KI gesendet.',
  ],
  rules: [
    'Die deutschen Datenschutzregeln werden aktiviert.',
    'Die übrige Benutzeroberfläche ist derzeit auf Englisch.',
  ],
  start: 'Starten',
);

const _en = _Promise(
  name: 'English',
  nots: [
    'No account.',
    'No ads.',
    'No analytics.',
    'No Z Privacy server.',
  ],
  paragraphs: [
    'Your original data stays on this device unless you explicitly copy '
        'restored content.',
    'Only the protected version is sent to AI through Z Privacy.',
  ],
  rules: [
    'The English privacy rules will be enabled.',
  ],
  start: 'Start',
);

class FirstRunScreen extends StatefulWidget {
  const FirstRunScreen({super.key, required this.ground, required this.onStart});

  /// The second step's sentence, in one place: what the vault is for, said
  /// before it is offered. Not a warning and not a sales line — the reason.
  static const vaultWhy =
      'What you teach Z lives here: the names you add, the values you protect '
      'for good, and the keys to any AI you connect. It stays on this computer, '
      'and nothing is written anywhere else.';

  final Ground ground;
  /// `wantsVault` is always true since 041-N — the vault is the way in, not an
  /// offer — and the parameter stays so the shell's door keeps one shape.
  final void Function(String language, {required bool wantsVault}) onStart;

  @override
  State<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends State<FirstRunScreen> {
  /// Null until a person chooses. **Not** a default — this page has no right to
  /// one, because the question it asks is which language they read.
  String? _language;

  /// The second step: the vault, before any work.
  ///
  /// The owner's sentence in 041-E was «the vault should be opened before
  /// starting work so we can save the words», and this page offered it with a
  /// «Later» beside it. 041-N, after a live run: «you cannot begin without an
  /// open vault». So the offer became the way in. There is no «Later» here any
  /// more — not because a person must be pushed, but because everything Z
  /// learns while they work is kept in the vault, and work done without one is
  /// work thrown away at the end of the day.
  bool _atTheVault = false;

  @override
  Widget build(BuildContext context) {
    final chosen = switch (_language) {
      'de' => _de,
      'en' => _en,
      _ => null,
    };
    return Scaffold(
      body: Stack(
        children: [
          Center(
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

                // Before a choice: both, each under its own name so nobody has
                // to work out which language they are reading. After a choice:
                // theirs alone.
                if (chosen == null)
                  for (final p in const [_de, _en]) _Block(p, named: true)
                else
                  _Block(chosen, named: false),

                const SizedBox(height: 8),
                // The label is in both languages while the answer is unknown.
                Eyebrow(chosen == null ? 'Sprache · Language' : (chosen == _de ? 'Sprache' : 'Language')),
                const SizedBox(height: 9),
                Row(
                  children: [
                    _Lang(
                      label: _de.name,
                      on: _language == 'de',
                      onTap: () => setState(() => _language = 'de'),
                    ),
                    const SizedBox(width: 9),
                    _Lang(
                      label: _en.name,
                      on: _language == 'en',
                      onTap: () => setState(() => _language = 'en'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (chosen == null)
                  // Why there is no Start yet, in both languages — a control
                  // that is absent has to be accounted for, like a disabled one.
                  Text(
                    'Wählen Sie eine Sprache, um fortzufahren.\n'
                    'Choose a language to continue.',
                    style: Zc.small,
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: Zc.panel(fill: Zc.clayWash, edge: Zc.clayEdge, radius: 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in chosen.rules)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              line,
                              style: Zc.small.copyWith(
                                color: Zc.clayDeep,
                                fontWeight: line == chosen.rules.first ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (!_atTheVault)
                    ZButton(
                      label: chosen.start,
                      filled: true,
                      onPressed: () => setState(() => _atTheVault = true),
                    )
                  else ...[
                    const Eyebrow('Your vault'),
                    const SizedBox(height: 8),
                    Text(FirstRunScreen.vaultWhy, style: Zc.small),
                    const SizedBox(height: 14),
                    ZButton(
                      label: 'Create a vault',
                      filled: true,
                      onPressed: () => widget.onStart(_language!, wantsVault: true),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'One passphrase, kept on this device. Everything Z learns while '
                      'you work — your names, your lists, your decisions — is kept in it.',
                      style: Zc.tiny.copyWith(letterSpacing: 0),
                    ),
                  ],
                ],
                const SizedBox(height: 34),
                Text('by YourVoices', style: Zc.tiny.copyWith(letterSpacing: 0.4)),
              ],
            ),
          ),
        ),
          ),
          // The mark itself, once, in the corner of the first page a person
          // ever sees — and nowhere else in the app. A product that shows its
          // badge on every screen is a product talking about itself; this one
          // has work to do.
          const Positioned(
            right: 28,
            bottom: 24,
            child: Opacity(opacity: 0.9, child: BrandMark(size: 64)),
          ),
        ],
      ),
    );
  }
}

/// One language's promise: the four lines, then the two sentences.
class _Block extends StatelessWidget {
  const _Block(this.promise, {required this.named});

  final _Promise promise;

  /// Headed by the language's name — only while both are on the page.
  final bool named;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: named ? 24 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (named) ...[
              Eyebrow(promise.name),
              const SizedBox(height: 8),
            ],
            for (final line in promise.nots)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  line,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: Zc.ink,
                  ),
                ),
              ),
            const SizedBox(height: 11),
            for (final paragraph in promise.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(paragraph, style: Zc.body.copyWith(fontSize: 15, height: 1.6)),
              ),
          ],
        ),
      );
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
