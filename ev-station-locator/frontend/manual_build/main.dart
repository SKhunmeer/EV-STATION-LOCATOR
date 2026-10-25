// Flutter web bootstrap script for package:ev_station_locator/main.dart.
// Generated locally using the cached Flutter web compiler.
// ignore_for_file: type=lint

import 'dart:ui_web' as ui_web;
import 'dart:async';

import 'package:ev_station_locator/main.dart' as entrypoint;
import 'web_plugin_registrant.dart' as pluginRegistrant;

typedef _UnaryFunction = dynamic Function(List<String> args);
typedef _NullaryFunction = dynamic Function();

Future<void> main() async {
  await ui_web.bootstrapEngine(
    runApp: () {
      if (entrypoint.main is _UnaryFunction) {
        return (entrypoint.main as _UnaryFunction)(<String>[]);
      }
      return (entrypoint.main as _NullaryFunction)();
    },
    registerPlugins: () {
      pluginRegistrant.registerPlugins();
    },
  );
}
