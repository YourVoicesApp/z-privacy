// Z Privacy — the UI.
//
// This layer sees and shows. It holds no secret, builds no outgoing text and
// knows nothing about the network: every fact on screen comes from z_core.
import 'package:flutter/material.dart';
import 'package:zprivacy/src/rust/api/core.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  // One line on stdout, so a headless build can prove the bridge is live
  // without anyone having to look at a window.
  debugPrint('bridge ok — ${coreVersion()}');
  runApp(const ZPrivacyApp());
}

const _paper = Color(0xFFF6F4EF);
const _ink = Color(0xFF17181B);
const _clay = Color(0xFFA85422);
const _ink2 = Color(0xFF4E545A);

class ZPrivacyApp extends StatelessWidget {
  const ZPrivacyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Z Privacy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(seedColor: _clay, surface: _paper),
        useMaterial3: true,
      ),
      home: const _Ground(),
    );
  }
}

class _Ground extends StatelessWidget {
  const _Ground();

  @override
  Widget build(BuildContext context) {
    // Sync call: the very first thing the window shows is a string built in Rust.
    final version = coreVersion();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _clay,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Z',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                const Text(
                  'Z Privacy',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              version,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
                color: _clay,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'this line was built in Rust',
              style: TextStyle(fontSize: 12.5, color: _ink2),
            ),
          ],
        ),
      ),
    );
  }
}
