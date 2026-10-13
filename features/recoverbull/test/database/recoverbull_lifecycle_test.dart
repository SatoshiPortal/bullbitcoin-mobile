import 'dart:io';

import 'package:bull_recoverbull/src/domain/entities/recoverbull_network.dart';
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

  test(
    'ignores a late successful provider acknowledgement after disposal',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recoverbull-disposed-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final lifecycle = RecoverBullLifecycle();
      await lifecycle.open('${directory.path}/recoverbull.sqlite');
      await lifecycle.dispose();

      await lifecycle.markStored(RecoverBullNetwork.mainnet);
      await lifecycle.markVerified(RecoverBullNetwork.mainnet);
    },
  );

  test('unopened lifecycle retains programmer errors', () async {
    final lifecycle = RecoverBullLifecycle();
    await expectLater(
      lifecycle.markStored(RecoverBullNetwork.mainnet),
      throwsStateError,
    );
    await expectLater(
      lifecycle.markVerified(RecoverBullNetwork.mainnet),
      throwsStateError,
    );
  });
}
