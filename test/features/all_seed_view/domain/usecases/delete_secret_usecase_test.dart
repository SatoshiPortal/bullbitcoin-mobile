import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/all_seed_view/domain/all_seed_view_failure.dart';
import 'package:bb_mobile/features/all_seed_view/domain/usecases/delete_secret_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWallet extends Mock implements Wallet {}

/// Was `DeleteSeedUsecase`, inside the seeds package. The class moved out when the package stopped knowing what a wallet is — `Secrets.trash` is unconditional and documented as such — but the responsibility did not: something must still refuse to delete a secret a wallet depends on, and that something is here.
///
/// The guard is asserted by the entry surviving in the keystore rather than by a mock method not being called.
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

  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  late _MockWalletRepository walletRepository;
  late DeleteSecretUsecase usecase;
  late Fingerprint id;

  Iterable<String> storedSecrets() =>
      storage.entries.keys.where((k) => k.startsWith('seed_'));

  _MockWallet walletUsing(Fingerprint fingerprint, {bool local = true}) {
    final wallet = _MockWallet();
    when(() => wallet.signsLocally).thenReturn(local);
    when(() => wallet.masterFingerprint).thenReturn(fingerprint.hex);
    return wallet;
  }

  setUp(() async {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    final stored =
        (await secrets.import(words: words)) as Ok<Secret, SecretFailure>;
    id = stored.value.id;
    walletRepository = _MockWalletRepository();
    usecase = DeleteSecretUsecase(
      secrets: secrets,
      walletRepository: walletRepository,
    );
  });

  group('DeleteSecretUsecase', () {
    test('deletes when no wallet uses the secret', () async {
      when(() => walletRepository.getWallets()).thenAnswer((_) async => []);

      expect(await usecase.execute(id), isA<Ok<void, AllSeedViewFailure>>());
      expect(storedSecrets(), isEmpty);
    });

    test(
      'deletes when only a watch-only wallet carries that fingerprint',
      () async {
        // A watch-only wallet imported from a descriptor shows the seed's
        // origin fingerprint but never held the seed. Counting it as a user
        // would leave the entry undeletable from the one screen that exists
        // to clean up orphans — the same rule DeleteWalletUsecase applies.
        when(
          () => walletRepository.getWallets(),
        ).thenAnswer((_) async => [walletUsing(id, local: false)]);

        expect(await usecase.execute(id), isA<Ok<void, AllSeedViewFailure>>());
        expect(storedSecrets(), isEmpty);
      },
    );

    test(
      'refuses, and keeps the secret, when a wallet still uses it',
      () async {
        when(
          () => walletRepository.getWallets(),
        ).thenAnswer((_) async => [walletUsing(id)]);

        final result = await usecase.execute(id);

        expect((result as Err).failure, isA<AllSeedViewDeleteFailure>());
        expect(storedSecrets(), hasLength(1));
      },
    );

    test('refuses when the wallets cannot be listed', () async {
      // A guard that cannot be evaluated has failed: deleting here would be deleting blind.
      when(() => walletRepository.getWallets()).thenThrow(Exception('boom'));

      final result = await usecase.execute(id);

      expect((result as Err).failure, isA<AllSeedViewDeleteFailure>());
      expect(storedSecrets(), hasLength(1));
    });

    test('another wallet fingerprint does not protect this secret', () async {
      when(
        () => walletRepository.getWallets(),
      ).thenAnswer((_) async => [walletUsing(Fingerprint('00000000'))]);

      expect(await usecase.execute(id), isA<Ok<void, AllSeedViewFailure>>());
      expect(storedSecrets(), isEmpty);
    });
  });
}
