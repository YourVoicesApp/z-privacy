// Connecting a provider, inside the sheet where the need arises.
//
// Two shapes of the same form, because the boards and the owner both want the
// local model to be a first-class door rather than an advanced setting:
//
//   a provider on the internet   address (https) + a credential + a model
//   a model on this machine      address (http://127.0.0.1:…) + a model
//
// The credential goes in and does not come out. There is no call in the contract
// that returns one, so this form cannot show you what you typed last time — and
// the row says instead whether one is held, and whether it will survive the app
// being closed.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';

class ConnectForm extends StatefulWidget {
  const ConnectForm({super.key, required this.ground, required this.row, required this.local});

  final Ground ground;
  final ProviderFact row;

  /// True for the «model on this machine» door: no credential asked for, and the
  /// address starts at the usual local one.
  final bool local;

  @override
  State<ConnectForm> createState() => _ConnectFormState();
}

class _ConnectFormState extends State<ConnectForm> {
  late final TextEditingController _base;
  late final TextEditingController _model;
  final _credential = TextEditingController();
  String? _trouble;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _base = TextEditingController(
      text: widget.local ? 'http://127.0.0.1:11434' : widget.row.endpoint,
    );
    _model = TextEditingController(text: widget.local ? 'llama3.2' : widget.row.model);
  }

  @override
  void dispose() {
    _base.dispose();
    _model.dispose();
    _credential.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field('Address', _base, hint: widget.local ? 'http://127.0.0.1:11434' : 'https://…'),
        if (widget.local)
          Padding(
            padding: const EdgeInsets.only(top: 5, bottom: 4),
            child: Text(
              'Plain http is accepted only for a literal loopback address — 127.0.0.1 or ::1. '
              'A name like «localhost» is refused, because then a hosts file would be deciding '
              'whether plain text is safe.',
              style: Zc.tiny.copyWith(letterSpacing: 0),
            ),
          ),
        const SizedBox(height: 10),
        _field('Model', _model, hint: 'the model to ask'),
        if (!widget.local) ...[
          const SizedBox(height: 10),
          _field('API key', _credential, hint: 'pasted once, never shown again', obscure: true),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              switch (widget.row.credentialState) {
                CredentialState.encryptedInVault =>
                  'This key is sealed in the vault.',
                CredentialState.sessionOnly =>
                  'This key is kept in memory for this run only — it is gone when the app closes.',
                CredentialState.missing =>
                  widget.ground.vault == VaultState.unlocked
                      ? 'No key is stored yet. Connecting will seal it in the vault.'
                      : 'No key is stored yet. Connecting will keep it in memory for this run only.',
              },
              style: Zc.tiny.copyWith(letterSpacing: 0),
            ),
          ),
        ],
        if (_trouble != null) ...[const SizedBox(height: 11), Trouble(_trouble!)],
        const SizedBox(height: 13),
        Row(
          children: [
            ZButton(
              label: _busy ? 'Connecting…' : (widget.row.connected ? 'Save' : 'Connect'),
              filled: true,
              onPressed: _busy ? null : _connect,
            ),
            if (widget.row.connected) ...[
              const SizedBox(width: 9),
              ZButton(
                label: 'Forget the key',
                onPressed: _busy
                    ? null
                    : () async {
                        final bad = await widget.ground.forget(widget.row.id);
                        if (mounted) setState(() => _trouble = bad);
                      },
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _trouble = null;
    });
    final bad = await widget.ground.connect(
      id: widget.row.id,
      credential: widget.local ? '' : _credential.text,
      baseUrl: _base.text,
      model: _model.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _trouble = bad;
      if (bad == null) _credential.clear();
    });
  }

  Widget _field(String label, TextEditingController c, {String? hint, bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(label),
        const SizedBox(height: 5),
        TextField(
          controller: c,
          obscureText: obscure,
          style: const TextStyle(fontSize: 13.5, fontFamily: Zc.mono),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Zc.card,
            hintText: hint,
            hintStyle: Zc.small.copyWith(color: Zc.ink4, fontFamily: null),
            contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Zc.line),
            ),
          ),
        ),
      ],
    );
  }
}
