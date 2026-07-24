import 'package:bb_mobile/core/background_tasks/handler.dart';
import 'package:bb_mobile/core/background_tasks/tasks.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/process_ongoing_swaps_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_bitcoin_sync_backend_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockSyncWalletUsecase extends Mock implements SyncWalletUsecase {}

class _MockGetBitcoinSyncBackendUsecase extends Mock
    implements GetBitcoinSyncBackendUsecase {}

class _MockProcessOngoingSwapsUsecase extends Mock
    implements ProcessOngoingSwapsUsecase {}

Wallet _buildWallet({
  required Network network,
  String id = '[abcdef12/84h/0h/0h]',
}) {
  return Wallet(
    origin: id,
    network: network,
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
  late _MockGetWalletsUsecase getWalletsUsecase;
  late _MockSyncWalletUsecase syncWalletUsecase;
  late _MockGetBitcoinSyncBackendUsecase getBitcoinSyncBackendUsecase;
  late _MockProcessOngoingSwapsUsecase processOngoingSwapsUsecase;

  setUpAll(() {
    registerFallbackValue(_buildWallet(network: Network.bitcoinMainnet));
  });

  setUp(() {
    getWalletsUsecase = _MockGetWalletsUsecase();
    syncWalletUsecase = _MockSyncWalletUsecase();
    getBitcoinSyncBackendUsecase = _MockGetBitcoinSyncBackendUsecase();
    processOngoingSwapsUsecase = _MockProcessOngoingSwapsUsecase();
  });

  Future<void> run(BackgroundTask task) => runBackgroundTask(
    task,
    getWalletsUsecase: getWalletsUsecase,
    syncWalletUsecase: syncWalletUsecase,
    getBitcoinSyncBackendUsecase: getBitcoinSyncBackendUsecase,
    processOngoingSwapsUsecase: processOngoingSwapsUsecase,
  );

  group('BackgroundTask.bitcoinSync', () {
    test('an Electrum-backed wallet is synced through the legacy '
        'Electrum-only path (allowCompactBlockFilters: false)', () async {
      final wallet = _buildWallet(network: Network.bitcoinMainnet);
      when(
        () => getWalletsUsecase.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => [wallet]);
      when(
        () => getBitcoinSyncBackendUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => const Ok(BitcoinSyncBackend.electrum));
      when(
        () =>
            syncWalletUsecase.execute(wallet, allowCompactBlockFilters: false),
      ).thenAnswer((_) async {});

      await run(BackgroundTask.bitcoinSync);

      verify(
        () =>
            syncWalletUsecase.execute(wallet, allowCompactBlockFilters: false),
      ).called(1);
    });

    test(
      'a compact-block-filters-backed wallet is never synced from the '
      'background isolate — never forced through Electrum, never opened '
      'through SyncWalletUsecase at all (which is what opens the BDK db)',
      () async {
        final wallet = _buildWallet(network: Network.bitcoinMainnet);
        when(
          () => getWalletsUsecase.execute(onlyBitcoin: true),
        ).thenAnswer((_) async => [wallet]);
        when(
          () => getBitcoinSyncBackendUsecase.execute(walletId: wallet.id),
        ).thenAnswer(
          (_) async => const Ok(BitcoinSyncBackend.compactBlockFilters),
        );

        await run(BackgroundTask.bitcoinSync);

        verifyNever(
          () => syncWalletUsecase.execute(
            any(),
            allowCompactBlockFilters: any(named: 'allowCompactBlockFilters'),
          ),
        );
      },
    );

    test('a mixed set of wallets syncs only the Electrum-backed ones, '
        'skipping the CBF-backed wallet', () async {
      final electrumWallet = _buildWallet(
        network: Network.bitcoinMainnet,
        id: 'electrum-wallet',
      );
      final cbfWallet = _buildWallet(
        network: Network.bitcoinMainnet,
        id: 'cbf-wallet',
      );
      when(
        () => getWalletsUsecase.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => [electrumWallet, cbfWallet]);
      when(
        () => getBitcoinSyncBackendUsecase.execute(walletId: electrumWallet.id),
      ).thenAnswer((_) async => const Ok(BitcoinSyncBackend.electrum));
      when(
        () => getBitcoinSyncBackendUsecase.execute(walletId: cbfWallet.id),
      ).thenAnswer(
        (_) async => const Ok(BitcoinSyncBackend.compactBlockFilters),
      );
      when(
        () => syncWalletUsecase.execute(
          electrumWallet,
          allowCompactBlockFilters: false,
        ),
      ).thenAnswer((_) async {});

      await run(BackgroundTask.bitcoinSync);

      verify(
        () => syncWalletUsecase.execute(
          electrumWallet,
          allowCompactBlockFilters: false,
        ),
      ).called(1);
      verifyNever(
        () => syncWalletUsecase.execute(
          cbfWallet,
          allowCompactBlockFilters: any(named: 'allowCompactBlockFilters'),
        ),
      );
    });

    test('a backend lookup failure falls back to the safe Electrum default '
        '(matching the schema-13-to-14 migration default) rather than '
        'skipping the wallet or throwing', () async {
      final wallet = _buildWallet(network: Network.bitcoinMainnet);
      when(
        () => getWalletsUsecase.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => [wallet]);
      when(
        () => getBitcoinSyncBackendUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => const Err(WalletSyncWalletNotFoundFailure()));
      when(
        () =>
            syncWalletUsecase.execute(wallet, allowCompactBlockFilters: false),
      ).thenAnswer((_) async {});

      await run(BackgroundTask.bitcoinSync);

      verify(
        () =>
            syncWalletUsecase.execute(wallet, allowCompactBlockFilters: false),
      ).called(1);
    });
  });

  group('BackgroundTask.liquidSync', () {
    test('every Liquid wallet is synced through the default '
        '(CBF-router-eligible, but Liquid has no CBF backend) sync path, '
        'unchanged from before', () async {
      final wallet = _buildWallet(network: Network.liquidMainnet);
      when(
        () => getWalletsUsecase.execute(onlyLiquid: true),
      ).thenAnswer((_) async => [wallet]);
      when(() => syncWalletUsecase.execute(wallet)).thenAnswer((_) async {});

      await run(BackgroundTask.liquidSync);

      verify(() => syncWalletUsecase.execute(wallet)).called(1);
      verifyNever(
        () => getBitcoinSyncBackendUsecase.execute(
          walletId: any(named: 'walletId'),
        ),
      );
    });
  });

  group('BackgroundTask.swapsSync', () {
    test('processes ongoing swaps once when wallets exist', () async {
      final wallet = _buildWallet(network: Network.bitcoinMainnet);
      when(() => getWalletsUsecase.execute()).thenAnswer((_) async => [wallet]);
      when(() => processOngoingSwapsUsecase.execute()).thenAnswer((_) async {});

      await run(BackgroundTask.swapsSync);

      verify(() => processOngoingSwapsUsecase.execute()).called(1);
    });

    test('skips swap processing when there are no wallets', () async {
      when(() => getWalletsUsecase.execute()).thenAnswer((_) async => []);

      await run(BackgroundTask.swapsSync);

      verifyNever(() => processOngoingSwapsUsecase.execute());
    });
  });
}
