import 'dart:async';
import 'dart:io';

import 'package:primitives/primitives.dart';

import 'coordinator_fixture.dart';

Future<void> main(List<String> args) async {
  final coordinator = fixtureCutover(
    Directory(args[0]),
    durableStep: (step) async {
      if (step == args[1]) {
        stdout.writeln('ready:$step');
        await Completer<void>().future;
      }
    },
  );
  final result = await coordinator.prepare();
  if (result case Ok(:final value)) await value.close();
}
