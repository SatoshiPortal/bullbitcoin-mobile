import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:primitives/primitives.dart' hide Network, ScriptType;
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockBoltzSwapRepository extends Mock implements BoltzSwapRepository {}

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

  Wallet buildWallet({
    String? masterFingerprint,
    bool isDefault = false,
    SignerEntity signer = SignerEntity.local,
    String? localSeedFingerprint,
  }) {
    return Wallet(
      origin: walletId,
      network: Network.bitcoinTestnet,
      isDefault: isDefault,
      signers: [
        WalletSigner.single(
          masterFingerprint: masterFingerprint ?? fingerprint,
          xpubFingerprint: '12345678',
          xpub: 'xpub',
          signer: signer,
          signerDevice: null,
        ).copyWith(localSeedFingerprint: localSeedFingerprint),
      ],
      scriptType: ScriptType.bip84,
      publicDescriptor: 'wpkh(xpub/<0;1>/*)',
      balanceSat: BigInt.zero,
    );
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
    ).thenAnswer((_) async => const Ok<void, WalletFailure>(null));
  });

  group('DeleteWalletUsecase seed ownership', () {
    test('deletes the seed once no remaining wallet references it', () async {
      final wallet = buildWallet(
        masterFingerprint: 'cafebabe',
        localSeedFingerprint: fingerprint,
      );
      when(
        () => walletRepository.getWallet(walletId),
      ).thenAnswer((_) async => Ok<Wallet, WalletFailure>(wallet));
      when(() => walletRepository.getWallets()).thenAnswer((_) async => Ok([]));

      final result = await usecase.execute(walletId: walletId);

      expect(result, isA<Ok<void, WalletFailure>>());
      expect(storage.entries, isNot(contains(key())));
    });

    for (final protectedSibling in [false, true]) {
      test(
        'keeps the seed used by a ${protectedSibling ? 'protected' : 'standard'} sibling',
        () async {
          final wallet = buildWallet();
          final sibling = buildWallet(
            masterFingerprint: protectedSibling ? 'cafebabe' : fingerprint,
            localSeedFingerprint: protectedSibling ? fingerprint : null,
          );
          when(
            () => walletRepository.getWallet(walletId),
          ).thenAnswer((_) async => Ok(wallet));
          when(
            () => walletRepository.getWallets(),
          ).thenAnswer((_) async => Ok([sibling]));

          expect(
            await usecase.execute(walletId: walletId),
            isA<Ok<void, WalletFailure>>(),
          );

          expect(storage.entries, contains(key()));
        },
      );
    }

    test('ignores the fingerprint on a remote-only sibling', () async {
      final wallet = buildWallet();
      final sibling = buildWallet(signer: SignerEntity.remote);
      when(
        () => walletRepository.getWallet(walletId),
      ).thenAnswer((_) async => Ok(wallet));
      when(
        () => walletRepository.getWallets(),
      ).thenAnswer((_) async => Ok([sibling]));

      expect(
        await usecase.execute(walletId: walletId),
        isA<Ok<void, WalletFailure>>(),
      );

      expect(storage.entries, isNot(contains(key())));
    });

    test('never touches a seed for a watch-only wallet', () async {
      final wallet = buildWallet(
        masterFingerprint: '',
        signer: SignerEntity.none,
      );
      when(
        () => walletRepository.getWallet(walletId),
      ).thenAnswer((_) async => Ok<Wallet, WalletFailure>(wallet));

      final result = await usecase.execute(walletId: walletId);

      expect(result, isA<Ok<void, WalletFailure>>());
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
          (_) async => Ok<Wallet, WalletFailure>(
            buildWallet(masterFingerprint: fingerprint.toUpperCase()),
          ),
        );
        when(() => walletRepository.getWallets()).thenAnswer(
          (_) async => Ok<List<Wallet>, WalletFailure>([
            buildWallet(masterFingerprint: fingerprint),
          ]),
        );

        expect(
          await usecase.execute(walletId: walletId),

          isA<Ok<void, WalletFailure>>(),
        );

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
        ).thenAnswer((_) async => Ok<Wallet, WalletFailure>(buildWallet()));
        when(() => walletRepository.getWallets()).thenAnswer(
          (_) async => Ok<List<Wallet>, WalletFailure>([
            buildWallet(
              masterFingerprint: fingerprint.toUpperCase(),
              signer: SignerEntity.none,
            ),
          ]),
        );

        expect(
          await usecase.execute(walletId: walletId),

          isA<Ok<void, WalletFailure>>(),
        );

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
          (_) async => Ok<Wallet, WalletFailure>(
            buildWallet(
              masterFingerprint: 'A1B2C3D4',
              signer: SignerEntity.none,
            ),
          ),
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
        ).thenAnswer((_) async => Ok<Wallet, WalletFailure>(buildWallet()));
        when(
          () => walletRepository.getWallets(),
        ).thenAnswer((_) async => Ok([]));
        // Scripted on the MUTATION queue, not the read queue. `trash` performs
        // no read, so an exception queued on `scripted` was never consumed and
        // this test passed while exercising nothing.
        storage.scriptedWrites.add(Exception('keystore refused the delete'));

        await expectLater(usecase.execute(walletId: walletId), completes);

        verify(
          () => walletRepository.deleteWallet(walletId: walletId),
        ).called(1);
        // The entry survives the failed delete, which is what makes the
        // cleanup best-effort rather than silently successful.
        expect(storage.entries, contains(key()));
      },
    );

    test(
      'keeps the secret when the remaining wallets cannot be read — deleting key material on a failed read is unrecoverable',
      () async {
        when(
          () => walletRepository.getWallet(walletId),
        ).thenAnswer((_) async => Ok<Wallet, WalletFailure>(buildWallet()));
        when(
          () => walletRepository.getWallets(),
        ).thenAnswer((_) async => const Err(WalletUnexpectedFailure('read')));

        final result = await usecase.execute(walletId: walletId);

        expect(result, isA<Ok<void, WalletFailure>>());
        expect(storage.entries, contains(key()));
      },
    );
  });
}
