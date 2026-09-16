import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/all_seed_view/domain/usecases/get_all_secrets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

/// `scripted` drives `read`; listing goes through `readAll`, so the failure is injected there.
class _ReadAllFails extends FakeSecureStoragePlatform {
  _ReadAllFails(this.error);

  final Object error;

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => throw error;
}

/// Was `GetAllSeedsUsecase`, which handed back the words of every stored secret. It hands back handles now; nothing is read out to list them.
///
/// Its "no raw leak" assertion only checked that `logMessage` was non-null — which a message containing the leak also satisfies. The real property is asserted where the redaction happens, in the package's `redaction_test.dart`; what is left here is this usecase's own: it forwards, and a keystore failure stays a failure.
void main() {
  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];

  late Secrets secrets;
  late GetAllSecretsUsecase usecase;

  setUp(() {
    FakeSecureStoragePlatform().install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    usecase = GetAllSecretsUsecase(secrets: secrets);
  });

  group('GetAllSecretsUsecase', () {
    test('returns the stored secrets as handles', () async {
      await secrets.import(words: words);

      final result = await usecase.execute();

      expect((result as Ok).value, hasLength(1));
    });

    test('returns an empty list when nothing is stored', () async {
      expect(((await usecase.execute()) as Ok).value, isEmpty);
    });

    test('a keystore failure stays a failure, with no stored text', () async {
      const sentinel = 'SYNTHETIC_KEYSTORE_SENTINEL';
      _ReadAllFails(Exception(sentinel)).install();

      final result = await usecase.execute();

      final failure = (result as Err).failure;
      expect(failure, isA<SecretFetchFailure>());
      expect(failure.logMessage, isNot(contains(sentinel)));
    });
  });
}
