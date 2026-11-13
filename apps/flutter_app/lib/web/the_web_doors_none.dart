// Not a browser: there is no `z_web` module to load. The tests hand the
// screen a fake written to ed's shape instead.
import 'package:zprivacy/web/the_web_core.dart';

Future<WebDoors> loadTheWebDoors({String module = ''}) =>
    Future<WebDoors>.error(UnsupportedError('z_web'));
