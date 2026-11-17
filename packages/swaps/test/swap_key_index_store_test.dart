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
}
