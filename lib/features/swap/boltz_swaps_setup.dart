import 'package:bb_mobile/features/address_view/domain/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/features/transactions/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/transactions/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:electrum/setup.dart';
import 'package:fees/fees.dart';
import 'package:get_it/get_it.dart';
import 'package:preferences/preferences.dart' as settings;
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:swaps/swaps.dart';
import 'package:sync/sync.dart' show WalletConnectionPort;

/// Composes the Boltz package with the remaining legacy feature projections.
class BoltzSwapsSetup {
  static Future<Result<void, SwapsFailure>> setup(GetIt locator) async {
    final opened = await Swaps.open(
      database: locator<BoltzSwapsDatabase>(),
      regtestDatabase: locator<BoltzSwapsDatabase>(instanceName: 'regtest'),
      secrets: locator<Secrets>(),
      preferences: locator<settings.Preferences>(),
      electrum: locator<ElectrumServersPort>(),
      connections: locator<WalletConnectionPort>(),
      fees: locator<Fees>(),
      wallets: (environment) async {
        final result = await locator<WalletRepository>().getWallets(
          environment: settings.Environment.fromName(environment.name),
        );
        return switch (result) {
          Ok(:final value) => [
            for (final wallet in value)
              SwapWalletInfo(
                id: wallet.id,
                isLiquid: wallet.isLiquid,
                isDefault: wallet.isDefault,
                fingerprint: wallet.masterFingerprint,
              ),
          ],
          Err(:final failure) => throw SwapsException(
            'wallets read failed: ${failure.runtimeType}',
          ),
        };
      },
      defaultBitcoinFingerprint: (environment) async {
        final result = await locator<WalletRepository>().getWallets(
          onlyDefaults: true,
          onlyBitcoin: true,
          environment: settings.Environment.fromName(environment.name),
        );
        final fingerprint = switch (result) {
          Ok(:final value) => value.firstOrNull?.masterFingerprint,
          Err(:final failure) => throw SwapsException(
            'default wallets read failed: ${failure.runtimeType}',
          ),
        };
        return fingerprint == null || fingerprint.isEmpty
            ? null
            : Fingerprint(fingerprint);
      },
      newAddressFor: (id) async =>
          (await locator<WalletAddressRepository>().generateNewReceiveAddress(
            walletId: id,
          )).address,
      walletTx: (txid, {required walletId}) async {
        final tx = await locator<WalletTransactionRepository>()
            .getWalletTransaction(txid, walletId: walletId);
        return tx == null ? null : _swapTransaction(tx);
      },
      walletTxs: (walletId, {bool sync = false}) async {
        final txs = await locator<WalletTransactionRepository>()
            .getWalletTransactions(walletId: walletId, sync: sync);
        return txs.map(_swapTransaction).toList();
      },
    );
    switch (opened) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final engine):
        locator.registerSingleton(engine, dispose: (value) => value.close());
        locator.registerSingleton<SwapServerSettings>(engine);
        locator.registerSingleton<AutoSwapSettings>(engine);
        locator.registerSingleton<SwapStore>(engine.store);
        locator.registerSingleton<SwapResolver>(engine.resolver);
        locator.registerSingleton<BoltzSwaps>(engine.boltz);
        locator.registerSingleton<SwapWatcher>(engine.watcher);
        _registerUsecases(locator);
        return const Ok(null);
    }
  }

  static void followEnvironment(GetIt locator) =>
      locator<Swaps>().followEnvironment();

  static SwapWalletTx _swapTransaction(WalletTransaction tx) => SwapWalletTx(
    txId: tx.txId,
    isIncoming: tx.isIncoming,
    spendsTxIds: [for (final input in tx.inputs) input.previousTxId],
  );

  static void _registerUsecases(GetIt locator) {
    locator.registerFactory<GetSwapUsecase>(
      () => GetSwapUsecase(locator<SwapStore>()),
    );
    locator.registerFactory<GetSwapsUsecase>(
      () => GetSwapsUsecase(locator<SwapStore>()),
    );
    locator.registerFactory<WatchSwapUsecase>(
      () => WatchSwapUsecase(locator<SwapStore>()),
    );
    locator.registerFactory<RestoreSwapsUsecase>(
      () => RestoreSwapsUsecase(locator<SwapResolver>(), locator<SwapStore>()),
    );
    locator.registerFactory<RescueSwapUsecase>(
      () => RescueSwapUsecase(
        locator<SwapResolver>(),
        locator<SwapStore>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<RetrySwapUsecase>(
      () => RetrySwapUsecase(locator<SwapWatcher>()),
    );
    locator.registerFactory<RetryOngoingSwapsUsecase>(
      () => RetryOngoingSwapsUsecase(locator<SwapWatcher>()),
    );
    locator.registerFactory<CreateBitcoinToLightningSwapUsecase>(
      () => CreateBitcoinToLightningSwapUsecase(
        locator<BoltzSwaps>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<CreateLiquidToLightningSwapUsecase>(
      () => CreateLiquidToLightningSwapUsecase(
        locator<BoltzSwaps>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<CreateLightningToBitcoinSwapUsecase>(
      () => CreateLightningToBitcoinSwapUsecase(
        locator<BoltzSwaps>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<CreateLightningToLiquidSwapUsecase>(
      () => CreateLightningToLiquidSwapUsecase(
        locator<BoltzSwaps>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<CreateBitcoinToLiquidSwapUsecase>(
      () => CreateBitcoinToLiquidSwapUsecase(
        locator<BoltzSwaps>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<CreateLiquidToBitcoinSwapUsecase>(
      () => CreateLiquidToBitcoinSwapUsecase(
        locator<BoltzSwaps>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<GetSwapLimitsAndFeesUsecase>(
      () => GetSwapLimitsAndFeesUsecase(locator<BoltzSwaps>()),
    );
    locator.registerFactory<RecordSwapLockupUsecase>(
      () => RecordSwapLockupUsecase(
        locator<SwapResolver>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<RecordPendingSwapLockupUsecase>(
      () => RecordPendingSwapLockupUsecase(locator<SwapResolver>()),
    );
    locator.registerFactory<DropPendingSwapLockupUsecase>(
      () => DropPendingSwapLockupUsecase(locator<SwapResolver>()),
    );
    locator.registerFactory<LogSwapCensusUsecase>(
      () => LogSwapCensusUsecase(locator<SwapStore>()),
    );
    locator.registerFactory<GetSwapMasterKeyUsecase>(
      () => GetSwapMasterKeyUsecase(locator<BoltzSwaps>()),
    );
    locator.registerFactory<GetSwapMnemonicUsecase>(
      () => GetSwapMnemonicUsecase(locator<BoltzSwaps>()),
    );
    locator.registerFactory<DeleteSwapMasterKeyUsecase>(
      () => DeleteSwapMasterKeyUsecase(locator<BoltzSwaps>()),
    );
  }
}
