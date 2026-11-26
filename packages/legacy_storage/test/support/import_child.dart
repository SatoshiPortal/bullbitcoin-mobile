import 'dart:io';

import 'package:primitives/primitives.dart';

import 'import_fixture.dart';

Future<void> main(List<String> args) async {
  final [source, destination, target] = args;
  final fixtureKey = Platform.environment['BULL_RECIPE_TEST_KEY'];
  if (fixtureKey == null) throw StateError('Missing disposable fixture key');

  Future<void> pause(String step) async {
    if (step == target) {
      stdout.writeln('ready:$step:$pid');
      await stdout.flush();
      await stdin.first;
    }
  }

  final db = SampleDatabase(
    File(destination),
    fixtureKey,
    afterSchemaCreated: () => pause('create'),
  );
  try {
    // Open the schema before importing, as the foreground owner would.
    await db.readSamples();
    await pause('schema');
    final result = await importSamples(File(source), db, pause: pause);
    if (result is! Ok) throw StateError('Fixture import failed');
    await pause('commit');
  } finally {
    await db.close();
  }
}
