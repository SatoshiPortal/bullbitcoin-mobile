import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockBoltzSwapRepository extends Mock implements BoltzSwapRepository {}

class _MockSeedRepository extends Mock implements SeedRepository {}

void main() {
  late _MockWalletRepository walletRepository;
  late _MockBoltzSwapRepository swapRepository;
  late _MockSeedRepository seedRepository;
  late DeleteWalletUsecase usecase;

  const walletId = 'wallet-1';
  const fingerprint = 'deadbeef';

  Wallet buildWallet({
    String masterFingerprint = fingerprint,
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
          masterFingerprint: masterFingerprint,
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

  setUp(() {
    walletRepository = _MockWalletRepository();
    swapRepository = _MockBoltzSwapRepository();
    seedRepository = _MockSeedRepository();
    usecase = DeleteWalletUsecase(
      walletRepository: walletRepository,
      swapRepository: swapRepository,
      seedRepository: seedRepository,
    );

    when(
      () => swapRepository.getOngoingSwaps(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => []);
    when(
      () => walletRepository.deleteWallet(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async {});
    when(
      () => seedRepository.delete(any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  group('DeleteWalletUsecase seed ownership', () {
    test('deletes the seed once no remaining wallet references it', () async {
      final wallet = buildWallet(
        masterFingerprint: 'cafebabe',
        localSeedFingerprint: fingerprint,
      );
      when(
        () => walletRepository.getWallet(walletId),
      ).thenAnswer((_) async => wallet);
      when(() => walletRepository.getWallets()).thenAnswer((_) async => []);

      await usecase.execute(walletId: walletId);

      verify(() => seedRepository.delete(fingerprint)).called(1);
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
          ).thenAnswer((_) async => wallet);
          when(
            () => walletRepository.getWallets(),
          ).thenAnswer((_) async => [sibling]);

          await usecase.execute(walletId: walletId);

          verifyNever(() => seedRepository.delete(any()));
        },
      );
    }

    test('ignores the fingerprint on a remote-only sibling', () async {
      final wallet = buildWallet();
      final sibling = buildWallet(signer: SignerEntity.remote);
      when(
        () => walletRepository.getWallet(walletId),
      ).thenAnswer((_) async => wallet);
      when(
        () => walletRepository.getWallets(),
      ).thenAnswer((_) async => [sibling]);

      await usecase.execute(walletId: walletId);

      verify(() => seedRepository.delete(fingerprint)).called(1);
    });

    test('never touches a seed for a watch-only wallet', () async {
      final wallet = buildWallet(masterFingerprint: '');
      when(
        () => walletRepository.getWallet(walletId),
      ).thenAnswer((_) async => wallet);

      await usecase.execute(walletId: walletId);

      verifyNever(() => seedRepository.delete(any()));
      verifyNever(() => walletRepository.getWallets());
    });

    test(
      'completes the wallet deletion even when seed cleanup fails — '
      'cleanup is best effort and must not surface as a wallet error',
      () async {
        final wallet = buildWallet();
        when(
          () => walletRepository.getWallet(walletId),
        ).thenAnswer((_) async => wallet);
        when(() => walletRepository.getWallets()).thenAnswer((_) async => []);
        when(
          () => seedRepository.delete(fingerprint),
        ).thenAnswer((_) async => const Err(SeedDeleteFailure('boom')));

        await expectLater(usecase.execute(walletId: walletId), completes);

        verify(
          () => walletRepository.deleteWallet(walletId: walletId),
        ).called(1);
      },
    );
  });
}
