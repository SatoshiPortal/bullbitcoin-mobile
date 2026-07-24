import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_sync_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWalletSyncRepository extends Mock implements WalletSyncRepository {}

Wallet _buildWallet({String id = '[abcdef12/84h/0h/0h]'}) {
  return Wallet(
    origin: id,
    network: Network.bitcoinMainnet,
    xpubFingerprint: '12345678',
    scriptType: ScriptType.bip84,
    xpub: 'xpub-fake',
    externalPublicDescriptor: 'wpkh([abcdef12/84h/0h/0h]xpub-fake/0/*)',
    internalPublicDescriptor: 'wpkh([abcdef12/84h/0h/0h]xpub-fake/1/*)',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );
}

void main() {
  late _MockWalletRepository walletRepository;
  late _MockWalletSyncRepository walletSyncRepository;
  late SyncWalletUsecase usecase;

  setUpAll(() {
    registerFallbackValue(_buildWallet());
  });

  setUp(() {
    walletRepository = _MockWalletRepository();
    walletSyncRepository = _MockWalletSyncRepository();
    usecase = SyncWalletUsecase(
      walletSyncRepository: walletSyncRepository,
      walletRepository: walletRepository,
    );
  });

  group('allowCompactBlockFilters: true (default — foreground callers, '
      'e.g. SyncCoordinator)', () {
    test('routes through WalletSyncRepository.startSync, never the legacy '
        'WalletRepository.sync — this is what lets a wizard-created CBF '
        'wallet actually sync with CBF', () async {
      final wallet = _buildWallet();
      when(
        () => walletSyncRepository.startSync(walletId: wallet.id),
      ).thenAnswer((_) async => const Ok(null));

      await expectLater(usecase.execute(wallet), completes);

      verify(
        () => walletSyncRepository.startSync(walletId: wallet.id),
      ).called(1);
      verifyNever(() => walletRepository.sync(any()));
    });

    test(
      'wraps a WalletSyncRepository failure into a SyncWalletException',
      () async {
        final wallet = _buildWallet();
        when(
          () => walletSyncRepository.startSync(walletId: wallet.id),
        ).thenAnswer(
          (_) async => const Err(WalletSyncDeveloperGateClosedFailure()),
        );

        await expectLater(
          usecase.execute(wallet),
          throwsA(isA<SyncWalletException>()),
        );
      },
    );
  });

  group('allowCompactBlockFilters: false (background tasks — '
      'lib/core/background_tasks/handler.dart)', () {
    test('bypasses WalletSyncRepository entirely and forces the legacy '
        'Electrum-only WalletRepository.sync', () async {
      final wallet = _buildWallet();
      when(() => walletRepository.sync(wallet)).thenAnswer((_) async {});

      await expectLater(
        usecase.execute(wallet, allowCompactBlockFilters: false),
        completes,
      );

      verify(() => walletRepository.sync(wallet)).called(1);
      verifyNever(
        () => walletSyncRepository.startSync(walletId: any(named: 'walletId')),
      );
    });

    test(
      'wraps any WalletRepository.sync failure into a SyncWalletException',
      () async {
        final wallet = _buildWallet();
        when(() => walletRepository.sync(wallet)).thenThrow(Exception('boom'));

        await expectLater(
          usecase.execute(wallet, allowCompactBlockFilters: false),
          throwsA(isA<SyncWalletException>()),
        );
      },
    );
  });
}
