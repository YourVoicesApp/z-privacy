// **Where the library the Dart half speaks through is, on this platform** —
// 098 item 4(ب), from the Windows run of 20 October.
//
// Fifty-nine test files each held this line of their own:
//
// ```dart
// final _libPath = theBridgeTheTestsSpeakThrough;
// ```
//
// and on Windows every one of them threw out of its `setUpAll` with «no
// build/linux/x64/debug/bundle/lib/libz_bridge.so» — a Linux path on a machine
// that has no such folder. Seventy-one failures in the job, sixty-six of them
// hidden behind a `tail -40`, and five more errors from a `tearDownAll` whose
// `late` folder was never set because the `setUpAll` above it had already
// thrown.
//
// So the path is chosen **once**, here, by the platform:
//
//   * on Linux, `flutter build linux --debug` leaves the bridge in the
//     bundle's own `lib/`, where the loader is pointed by
//     `LD_LIBRARY_PATH`;
//   * on Windows there is no bundle folder. The runner build puts the
//     application in `build/windows/x64/runner/Debug`, the job copies the
//     bridge built with the test features in beside it, and the loader finds
//     it there because Windows searches the executable's own directory and
//     then `PATH` — which the job sets to that same folder. The DLL is the one
//     the job proved carries the echo provider.
//
// Relative, like the line it replaces: every one of these tests runs with
// `apps/flutter_app` as its working directory.
import 'dart:io';
import 'the_bridge_the_tests_speak_through.dart';

/// The built bridge for the platform this test is running on.
String get theBridgeTheTestsSpeakThrough => Platform.isWindows
    ? 'build/windows/x64/runner/Debug/z_bridge.dll'
    : 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

/// **And the sentence a missing bridge says**, in the words of the platform
/// the person is on. Fifty-nine files told a Windows session to «run `flutter
/// build linux --debug` first», which is the one thing that cannot help it.
String get buildTheBridgeFirst => Platform.isWindows
    ? 'no $theBridgeTheTestsSpeakThrough — build it as the Windows job does: '
        '`cargo build -p z_bridge --features '
        'z_core/fake_provider,z_core/test_clock,z_core/measuring`, then '
        '`flutter build windows --debug`, then copy target/debug/z_bridge.dll '
        'in beside the runner'
    : 'no $theBridgeTheTestsSpeakThrough — run `flutter build linux --debug` first';
