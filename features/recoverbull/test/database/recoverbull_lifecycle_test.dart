import 'dart:io';

import 'package:bull_recoverbull/src/public/recoverbull.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supports opening path A, then B, then B again', () async {
    final directory = await Directory.systemTemp.createTemp(
      'recoverbull-lifecycle-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final lifecycle = RecoverBullLifecycle();
    final pathA = '${directory.path}/a.sqlite';
    final pathB = '${directory.path}/b.sqlite';

    await lifecycle.open(pathA);
    await lifecycle.open(pathB);
    await lifecycle.open(pathB);

    await lifecycle.dispose();
  });

  test('reports StateError rather than null-crashing after dispose', () async {
    final directory = await Directory.systemTemp.createTemp(
      'recoverbull-disposed-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final lifecycle = RecoverBullLifecycle();
    await lifecycle.open('${directory.path}/recoverbull.sqlite');
    await lifecycle.dispose();

    expect(lifecycle.markStored, throwsA(isA<StateError>()));
    expect(lifecycle.markVerified, throwsA(isA<StateError>()));
  });
}
