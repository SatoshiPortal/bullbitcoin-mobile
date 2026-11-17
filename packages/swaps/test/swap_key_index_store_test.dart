import 'dart:async';

import 'package:swaps/src/data/swap_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRowStore extends Mock implements SwapRowStore {}

class _MockSecretStore extends Mock implements SecretStore {}

void main() {
  late _MockSecretStore secrets;
  late SwapStorage storage;

  setUp(() {
    secrets = _MockSecretStore();
    storage = SwapStorage(rows: _MockRowStore(), secrets: secrets);
  });

  test('an absent counter reads as unset', () async {
    when(() => secrets.read(any())).thenAnswer((_) async => null);

    expect(await storage.getSwapKeyIndex('cafe0001'), isNull);
  });

  test('a failed read is not mistaken for an unset counter', () async {
    when(() => secrets.read(any())).thenThrow(Exception('keychain locked'));

    expect(storage.getSwapKeyIndex('cafe0001'), throwsException);
  });

  test(
    'concurrent reservations await the write and use the latest counter',
    () async {
      var value = '0';
      final writeStarted = Completer<void>();
      final releaseWrite = Completer<void>();
      when(() => secrets.read(any())).thenAnswer((_) async => value);
      when(() => secrets.write(any(), any())).thenAnswer((invocation) async {
        if (!writeStarted.isCompleted) {
          writeStarted.complete();
          await releaseWrite.future;
        }
        value = invocation.positionalArguments[1] as String;
      });

      final first = storage.reserveSwapKeyIndex('cafe0001', 2, 3);
      await writeStarted.future;
      final second = storage.reserveSwapKeyIndex('cafe0001', 2, 3);
      releaseWrite.complete();

      expect(await Future.wait([first, second]), [3, 5]);
      expect(value, '7');
    },
  );

  test('a failed counter write does not return a reservation', () async {
    when(() => secrets.read(any())).thenAnswer((_) async => '4');
    when(() => secrets.write(any(), any())).thenThrow(Exception('locked'));

    await expectLater(
      storage.reserveSwapKeyIndex('cafe0001', 2, 0),
      throwsException,
    );
  });
}
