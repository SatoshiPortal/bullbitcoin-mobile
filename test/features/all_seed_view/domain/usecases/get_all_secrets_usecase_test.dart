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
      expect(
        await secrets.import(words: words),
        isA<Ok<Secret, SecretFailure>>(),
      );

      final result = await usecase.execute();

      final listing = (result as Ok<List<SecretEntry>, SecretFailure>).value;
      expect(listing, hasLength(1));
      expect(listing.single, isA<Secret>());
    });

    test('returns an empty list when nothing is stored', () async {
      final listing =
          ((await usecase.execute()) as Ok<List<SecretEntry>, SecretFailure>)
              .value;
      expect(listing, isEmpty);
    });

    test('returns an unreadable entry beside readable secrets', () async {
      // R6's last item: a shorter list must never look like a smaller
      // keystore. One good entry, one value under the prefix that is not ours.
      FakeSecureStoragePlatform(
        entries: {'seed_deadbeef': 'not json at all'},
      ).install();
      secrets = Secrets(scratchDirectory: () async => '/tmp');
      usecase = GetAllSecretsUsecase(secrets: secrets);
      expect(
        await secrets.import(words: words),
        isA<Ok<Secret, SecretFailure>>(),
      );

      final listing =
          ((await usecase.execute()) as Ok<List<SecretEntry>, SecretFailure>)
              .value;

      expect(listing, hasLength(2));
      expect(listing.whereType<Secret>(), hasLength(1));
      final unreadable = listing.whereType<UnreadableSecret>().single;
      expect(unreadable.id?.hex, 'deadbeef');
      expect(unreadable.failure, isA<FetchSecretFailure>());
    });

    test('a keystore failure stays a failure, with no stored text', () async {
      const sentinel = 'SYNTHETIC_KEYSTORE_SENTINEL';
      _ReadAllFails(Exception(sentinel)).install();

      final result = await usecase.execute();

      final failure = (result as Err).failure;
      expect(failure, isA<FetchSecretFailure>());
      expect(failure.logMessage, isNot(contains(sentinel)));
    });
  });
}
