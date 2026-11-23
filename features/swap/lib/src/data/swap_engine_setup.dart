import 'package:address_view/address_view.dart';
import 'package:transactions/transactions.dart';
import 'package:electrum/setup.dart';
import 'package:fees/fees.dart';
import 'package:get_it/get_it.dart';
import 'package:preferences/preferences.dart' as settings;
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:swaps/swaps.dart';
import 'package:sync/sync.dart' show WalletConnectionPort;

/// Opens the Boltz engine over the authorized inventory and registers the
/// engine capabilities still resolved through the service locator.
class SwapEngineSetup {
  static Future<Result<void, SwapsFailure>> open(
    GetIt locator, {
    required WalletInventory inventory,
  }) async {
    final opened = await Swaps.open(
      database: locator<BoltzSwapsDatabase>(),
      regtestDatabase: locator<BoltzSwapsDatabase>(instanceName: 'regtest'),
      secrets: locator<Secrets>(),
      preferences: locator<settings.Preferences>(),
      electrum: locator<ElectrumServersPort>(),
      connections: locator<WalletConnectionPort>(),
      fees: locator<Fees>(),
      wallets: (environment) async => [
        for (final wallet in await _wallets(inventory, environment))
          SwapWalletInfo(
            id: wallet.id,
            isLiquid: wallet.network is LiquidNetwork,
            isDefault: wallet.isDefault,
            fingerprint: wallet.masterFingerprint?.hex ?? '',
          ),
      ],
      defaultBitcoinFingerprint: (environment) async {
        final defaults = (await _wallets(inventory, environment)).where(
          (wallet) => wallet.isDefault && wallet.network is BitcoinNetwork,
        );
        return defaults.firstOrNull?.masterFingerprint;
      },
      newAddressFor: (id) async => switch (await locator<AddressView>()
          .receiveAddress(walletId: id, advance: true)) {
        Ok(:final value) => Ok(value.address),
        Err(failure: AddressViewWriterBusyFailure()) => const Err(
          SwapsBusyFailure(),
        ),
        Err() => const Err(
          SwapsUnexpectedFailure('Receive address unavailable'),
        ),
      },
      walletTx: (txid, {required walletId}) async {
        final result = await locator<Transactions>().getWalletTransaction(
          txid,
          walletId: walletId,
        );
        return switch (result) {
          Ok(value: final tx?) => _swapTransaction(tx),
          Ok(value: null) => null,
          Err(:final failure) => throw SwapsException(
            'wallet transaction read failed: ${failure.runtimeType}',
          ),
        };
      },
      walletTxs: (walletId, {bool sync = false}) async {
        final result = await locator<Transactions>().getWalletTransactions(
          walletId: walletId,
          sync: sync,
        );
        return switch (result) {
          Ok(:final value) => value.map(_swapTransaction).toList(),
          Err(:final failure) => throw SwapsException(
            'wallet transactions read failed: ${failure.runtimeType}',
          ),
        };
      },
    );
    switch (opened) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final engine):
        locator.registerSingleton(engine, dispose: (value) => value.close());
        locator.registerSingleton<SwapServerSettings>(engine);
        locator.registerSingleton<SwapRouting>(engine);
        locator.registerSingleton<AutoSwapSettings>(engine);
        locator.registerSingleton<SwapStore>(engine.store);
        locator.registerSingleton<SwapResolver>(engine.resolver);
        locator.registerSingleton<BoltzSwaps>(engine.boltz);
        locator.registerSingleton<SwapWatcher>(engine.watcher);
        _registerUsecases(locator);
        return const Ok(null);
    }
  }

  /// Readable accounts of [environment]; an unreadable row is skipped as the
  /// legacy catalogue did, an unavailable inventory refuses the read.
  static Future<List<WalletRegistration>> _wallets(
    WalletInventory inventory,
    NetworkEnv environment,
  ) async {
    final bitcoin = BitcoinNetwork.tryFromName(environment.name);
    final liquid = LiquidNetwork.tryFromName(environment.name);
    if (bitcoin == null || liquid == null) return const [];
    final wallets = <WalletRegistration>[];
    for (final network in <Network>[bitcoin, liquid]) {
      switch (await inventory.walletsForNetwork(network)) {
        case Ok(:final value):
          wallets.addAll(value.wallets);
        case Err(:final failure):
          throw SwapsException('wallets read failed: ${failure.runtimeType}');
      }
    }
    return wallets;
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
    locator.registerFactory<SwapStartup>(
      () =>
          SwapStartup(locator<LogSwapCensusUsecase>(), locator<SwapWatcher>()),
    );
    locator.registerFactory<LogSwapCensusUsecase>(
      () => LogSwapCensusUsecase(locator<SwapStore>()),
    );
  }
}
