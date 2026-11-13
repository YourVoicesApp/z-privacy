// **The web entry point** — paper 122, rule 85: z-privacy.com becomes a place
// to try Z, and its first screen is the app's chat. This file shows the trial
// and nothing else.
//
// **Nothing of the desktop is imported here**: not `main.dart`, not the
// flutter_rust_bridge bindings in `src/rust`, not `dart:io`. The core is ed's
// `z_web` module, loaded by `the_web_doors.dart`; a guard walks every import
// this file reaches.
import 'package:flutter/widgets.dart';

import 'package:zprivacy/web/the_trial.dart';
import 'package:zprivacy/web/the_web_doors.dart';

/// The root the browser runs: the trial, in the language of the page's
/// address.
Widget theWebRoot() => TrialApp(
  language: theLanguageOfTheAddress(Uri.base),
  doors: loadTheWebDoors,
);

void main() => runApp(theWebRoot());
