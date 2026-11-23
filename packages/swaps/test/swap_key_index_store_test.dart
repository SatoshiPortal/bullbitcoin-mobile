import 'dart:async';

import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;
import 'package:mocktail/mocktail.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:test/test.dart';

import 'support/real_swap_backends.dart';

class _MockRowStore extends Mock implements SwapRowStore {}

class _HeldKeychain extends ReproKeychainBackend {
  final writeStarted = Completer<void>();
  final releaseWrite = Completer<void>();
  bool holdFirstWrite = false;

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    if (holdFirstWrite && !writeStarted.isCompleted) {
      writeStarted.complete();
      await releaseWrite.future;
    }
    await super.write(key: key, value: value, options: options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _HeldKeychain secrets;
  late SwapStorage storage;

  setUp(() {
    secrets = _HeldKeychain();
    storage = SwapStorage(rows: _MockRowStore(), secrets: secrets.capability);
  });

  test('an absent counter reads as unset', () async {
    expect(await storage.getSwapKeyIndex('cafe0001'), isNull);
  });

  test('a failed read is not mistaken for an unset counter', () async {
    secrets.scripted.add(Exception('keychain locked'));
    expect(storage.getSwapKeyIndex('cafe0001'), throwsException);
  });

  test(
    'concurrent reservations await the write and use the latest counter',
    () async {
      secrets.values['swap_master_key_index_cafe0001'] = '0';
      secrets.holdFirstWrite = true;
      final first = storage.reserveSwapKeyIndex('cafe0001', 2, 3);
      await secrets.writeStarted.future;
      final second = storage.reserveSwapKeyIndex('cafe0001', 2, 3);
      secrets.releaseWrite.complete();
      expect(await Future.wait([first, second]), [3, 5]);
      expect(secrets.values['swap_master_key_index_cafe0001'], '7');
    },
  );

  test('a failed counter write does not return a reservation', () async {
    secrets.values['swap_master_key_index_cafe0001'] = '4';
    secrets.scriptedWrites.add(Exception('locked'));
    await expectLater(
      storage.reserveSwapKeyIndex('cafe0001', 2, 0),
      throwsException,
    );
  });
}
