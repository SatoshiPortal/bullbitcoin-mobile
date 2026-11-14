import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show SeedReferences;
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/all_seed_view/domain/all_seed_view_failure.dart';
import 'package:bb_mobile/features/all_seed_view/domain/usecases/delete_secret_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockSeedOwner extends Mock implements SeedReferencePort {}

class _MockWalletRepository extends Mock implements WalletRepository {}

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
  late SeedReferences references;
  late DeleteSecretUsecase usecase;
  late Fingerprint id;

  Iterable<String> storedSecrets() =>
      storage.entries.keys.where((k) => k.startsWith('seed_'));

  late Directory logDirectory;
  tearDown(() async {
    await log.flush();
    await logDirectory.delete(recursive: true);
  });

  setUp(() async {
    logDirectory = await Directory.systemTemp.createTemp("seed-log-");
    log = Logger.replace(directory: logDirectory);
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    final stored =
        (await secrets.import(words: words)) as Ok<Secret, SecretFailure>;
    id = stored.value.id;
    walletRepository = _MockWalletRepository();
    references = SeedReferences(walletRepository);
    usecase = DeleteSecretUsecase(secrets: secrets, seedReferences: references);
  });

  for (final outcome in ['referenced', 'incomplete', 'throws']) {
    test('additional custody owner $outcome preserves seed', () async {
      when(
        () => walletRepository.getCustodyFingerprints(),
      ).thenAnswer((_) async => const Ok<Set<Fingerprint>, WalletFailure>({}));
      final owner = _MockSeedOwner();
      references.register(owner);
      if (outcome == 'throws') {
        when(() => owner.getCustodyFingerprints())
            .thenThrow(Exception('unavailable'));
      } else {
        when(() => owner.getCustodyFingerprints()).thenAnswer(
          (_) async => outcome == 'referenced'
              ? Ok<Set<Fingerprint>, WalletFailure>({id})
              : const Err<Set<Fingerprint>, WalletFailure>(
                  WalletStorageFailure('incomplete'),
                ),
        );
      }
      expect(await usecase.execute(id), isA<Err>());
      expect(storedSecrets(), hasLength(1));
      final rows = await log.readLogs();
      expect(rows.map((row) => row.split('\t')[2]), [
        outcome == 'referenced'
            ? 'Seed delete refused reason=referenced'
            : 'Seed delete refused reason=references_unavailable',
      ]);
    });
  }

  group('DeleteSecretUsecase', () {
    test('deletes when no wallet uses the secret', () async {
      when(() => walletRepository.getCustodyFingerprints())
          .thenAnswer((_) async => Ok<Set<Fingerprint>, WalletFailure>({}));

      expect(await usecase.execute(id), isA<Ok<void, AllSeedViewFailure>>());
      expect(storedSecrets(), isEmpty);
      expect((await log.readLogs()).map((row) => row.split('\t')[2]), [
        'Seed deleted source=manual',
      ]);
    });

    test(
      'deletes when only a watch-only wallet carries that fingerprint',
      () async {
        // A watch-only wallet imported from a descriptor shows the seed's
        // origin fingerprint but never held the seed. Counting it as a user
        // would leave the entry undeletable from the one screen that exists
        // to clean up orphans — the same rule DeleteWalletUsecase applies.
        when(() => walletRepository.getCustodyFingerprints())
            .thenAnswer((_) async => Ok<Set<Fingerprint>, WalletFailure>({}));

        expect(await usecase.execute(id), isA<Ok<void, AllSeedViewFailure>>());
        expect(storedSecrets(), isEmpty);
      },
    );

    test(
      'refuses, and keeps the secret, when a wallet still uses it',
      () async {
        when(() => walletRepository.getCustodyFingerprints())
            .thenAnswer((_) async => Ok<Set<Fingerprint>, WalletFailure>({id}));

        final result = await usecase.execute(id);

        expect((result as Err).failure, isA<AllSeedViewDeleteFailure>());
        expect(storedSecrets(), hasLength(1));
      },
    );

    test('refuses when the wallets cannot be listed', () async {
      // A guard that cannot be evaluated has failed: deleting here would be deleting blind.
      when(() => walletRepository.getCustodyFingerprints())
          .thenThrow(Exception('boom'));

      final result = await usecase.execute(id);

      expect((result as Err).failure, isA<AllSeedViewDeleteFailure>());
      expect(storedSecrets(), hasLength(1));
    });

    test('refuses when the wallet read fails', () async {
      // An unreadable list is not an empty one: deleting key material on a
      // failed read is unrecoverable.
      when(() => walletRepository.getCustodyFingerprints()).thenAnswer(
        (_) async => const Err<Set<Fingerprint>, WalletFailure>(
          WalletStorageFailure('read'),
        ),
      );

      final result = await usecase.execute(id);

      expect((result as Err).failure, isA<AllSeedViewDeleteFailure>());
      expect(storedSecrets(), hasLength(1));
    });

    test('another wallet fingerprint does not protect this secret', () async {
      when(() => walletRepository.getCustodyFingerprints()).thenAnswer(
        (_) async =>
            Ok<Set<Fingerprint>, WalletFailure>({Fingerprint('00000000')}),
      );

      expect(await usecase.execute(id), isA<Ok<void, AllSeedViewFailure>>());
      expect(storedSecrets(), isEmpty);
    });
  });
}
