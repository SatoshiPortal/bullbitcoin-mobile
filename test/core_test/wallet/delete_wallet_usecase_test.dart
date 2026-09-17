import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockBoltzSwapRepository extends Mock implements BoltzSwapRepository {}

class _MockWallet extends Mock implements Wallet {}

/// Orphan-seed cleanup (issue #2324), against the real `Secrets`.
///
/// `Secrets.trash` is unconditional — the package does not know what a wallet is — so the guard asserted here is entirely this usecase's. The old test proved it with `verifyNever(delete)` on a mock; it is now proved by the entry still being in the keystore, which is the thing that actually matters.
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
  const walletId = 'wallet-1';

  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  late _MockWalletRepository walletRepository;
  late _MockBoltzSwapRepository swapRepository;
  late DeleteWalletUsecase usecase;
  late String fingerprint;

  String key() => 'seed_$fingerprint';

  _MockWallet buildWallet({String? masterFingerprint, bool local = true}) {
    final wallet = _MockWallet();
    when(() => wallet.isDefault).thenReturn(false);
    when(() => wallet.signsLocally).thenReturn(local);
    when(
      () => wallet.masterFingerprint,
    ).thenReturn(masterFingerprint ?? fingerprint);
    return wallet;
  }

  setUp(() async {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    final stored =
        (await secrets.import(words: words)) as Ok<Secret, SecretFailure>;
    fingerprint = stored.value.id.hex;

    walletRepository = _MockWalletRepository();
    swapRepository = _MockBoltzSwapRepository();
    usecase = DeleteWalletUsecase(
      walletRepository: walletRepository,
      swapRepository: swapRepository,
      secrets: secrets,
    );
    when(
      () => swapRepository.getOngoingSwaps(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => []);
    when(
      () => walletRepository.deleteWallet(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async {});
  });

  group('DeleteWalletUsecase — orphan seed cleanup (issue #2324)', () {
    test('deletes the secret once no remaining wallet references it', () async {
      when(
        () => walletRepository.getWallet(walletId),
      ).thenAnswer((_) async => buildWallet());
      when(() => walletRepository.getWallets()).thenAnswer((_) async => []);

      await usecase.execute(walletId: walletId);

      expect(storage.entries, isNot(contains(key())));
    });

    test(
      'keeps the secret while another wallet shares the fingerprint',
      () async {
        when(
          () => walletRepository.getWallet(walletId),
        ).thenAnswer((_) async => buildWallet());
        when(
          () => walletRepository.getWallets(),
        ).thenAnswer((_) async => [buildWallet()]);

        await usecase.execute(walletId: walletId);

        expect(storage.entries, contains(key()));
      },
    );

    test('never touches a secret for a watch-only wallet', () async {
      when(
        () => walletRepository.getWallet(walletId),
      ).thenAnswer((_) async => buildWallet(masterFingerprint: ''));

      await usecase.execute(walletId: walletId);

      expect(storage.entries, contains(key()));
      verifyNever(() => walletRepository.getWallets());
    });

    test(
      'keeps the secret when another wallet spells the same fingerprint in lowercase',
      () async {
        // Both hot. A hot wallet always writes lowercase, so a spelling split
        // between two LOCAL signers is defence in depth rather than a live
        // path — the live split is watch-only vs hot, tested below, and there
        // the watch-only must NOT count as a user. Here both sign, so the
        // parsed compare is what keeps the seed a hot wallet still uses.
        when(() => walletRepository.getWallet(walletId)).thenAnswer(
          (_) async =>
              buildWallet(masterFingerprint: fingerprint.toUpperCase()),
        );
        when(() => walletRepository.getWallets()).thenAnswer(
          (_) async => [buildWallet(masterFingerprint: fingerprint)],
        );

        await usecase.execute(walletId: walletId);

        expect(storage.entries, contains(key()));
      },
    );

    test(
      'trashes the seed when only a watch-only wallet with that fingerprint remains',
      () async {
        // The hot wallet goes; a Coldcard watch-only imported from the same
        // seed stays, with the origin spelled A1B2C3D4. It cannot sign, so
        // it does not hold the seed — counting it as a user left the seed
        // orphaned, and CheckDuplicateMnemonic then refused to reimport the
        // very words the user still had on paper (the #2634 class).
        when(
          () => walletRepository.getWallet(walletId),
        ).thenAnswer((_) async => buildWallet());
        when(() => walletRepository.getWallets()).thenAnswer(
          (_) async => [
            buildWallet(
              masterFingerprint: fingerprint.toUpperCase(),
              local: false,
            ),
          ],
        );

        await usecase.execute(walletId: walletId);

        expect(storage.entries, isNot(contains(key())));
      },
    );

    test(
      'completes for a watch-only wallet whose descriptor fingerprint is uppercase',
      () async {
        // Sparrow and Coldcard write key origins as [A1B2C3D4/84h/0h/0h], and
        // an imported watch-only wallet keeps that spelling verbatim. Building
        // a Fingerprint from it threw ArgumentError *after* deleteWallet had
        // already run, so the row was gone and the user still saw an error.
        when(() => walletRepository.getWallet(walletId)).thenAnswer(
          (_) async => buildWallet(masterFingerprint: 'A1B2C3D4', local: false),
        );

        await expectLater(usecase.execute(walletId: walletId), completes);

        verify(
          () => walletRepository.deleteWallet(walletId: walletId),
        ).called(1);
        // A watch-only wallet never owned a seed entry, so nothing is even
        // looked up — the same shape as the empty-fingerprint case.
        verifyNever(() => walletRepository.getWallets());
        expect(storage.entries, contains(key()));
      },
    );

    test(
      'completes the wallet deletion even when secret cleanup fails — cleanup is best effort and must not surface as a wallet error',
      () async {
        when(
          () => walletRepository.getWallet(walletId),
        ).thenAnswer((_) async => buildWallet());
        when(() => walletRepository.getWallets()).thenAnswer((_) async => []);
        storage.scripted.add(Exception('keystore refused the delete'));

        await expectLater(usecase.execute(walletId: walletId), completes);

        verify(
          () => walletRepository.deleteWallet(walletId: walletId),
        ).called(1);
      },
    );
  });
}
