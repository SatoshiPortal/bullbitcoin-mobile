import 'package:bb_mobile/features/wallet/public/ark_funding_setup.dart'
    show ArkFundingSigningGuard;
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';

import 'dart:async';

import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:electrum/setup.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/storage/payjoin_legacy_data_adapter.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';
import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/payjoin_wallet_adapter.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/transactions/data/payjoin_blockchain_adapter.dart';
import 'package:bb_mobile/features/transactions/data/payjoin_codec_adapter.dart';
import 'package:bb_mobile/features/transactions/data/payjoin_fees_adapter.dart';
import 'package:bb_mobile/features/transactions/data/payjoin_input_reservation_adapter.dart';
import 'package:bb_mobile/features/transactions/data/payjoin_log_adapter.dart';
import 'package:bb_mobile/features/transactions/data/payjoin_transaction_adapter.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:get_it/get_it.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart' show InputReservationPort;

abstract final class PayjoinSetup {
  static void setup(
    GetIt locator,
    SqliteDatabase database,
    String databasePath, {
    bool startRecovery = true,
  }) {
    bool? capturedRegtest;
    Future<bool> isCurrent() async {
      try {
        final active =
            (await locator<GetSettingsUsecase>().execute()).activeNetwork;
        final captured = capturedRegtest;
        if (captured == null) return true;
        return captured
            ? active == NetworkEnv.regtest
            : (active == NetworkEnv.mainnet || active == NetworkEnv.testnet);
      } on Exception {
        return false;
      }
    }

    Future<RegtestHostProfile?>? capturedProfile;
    Future<RegtestHostProfile?> captureProfile() =>
        capturedProfile ??= () async {
          final settings = await locator<GetSettingsUsecase>().execute();
          final host = RegtestHostProfile.forNetwork(settings.activeNetwork);
          capturedRegtest = host != null;
          return host;
        }();

    final runtime = RecoverablePayjoin(() async {
      final profile = await captureProfile();
      return openPayjoin(
        regtestHostProfile: profile,
        isCurrent: isCurrent,
        databasePath: databasePath,
        wallet: PayjoinWalletAdapter(
          locator<Secrets>(),
          locator<WalletNativeRuntime>().wallet,
          locator<WalletNativeRuntime>().spendStatus,
          locator<SyncWalletValuesDatasource>(),
          locator<WalletMetadataDatasource>(),
          locator<ArkFundingSigningGuard>(),
        ),
        blockchain: AppPayjoinBlockchainAdapter(
          locator<BdkBitcoinBlockchainDatasource>(),
          locator<ElectrumServersPort>(),
          locator<WalletFacade>(),
        ),
        fees: AppPayjoinFeesAdapter(locator<FeesRepository>()),
        transactions: AppPayjoinTransactionAdapter(
          locator<WalletRepository>(),
          locator<WalletTransactionRepository>(),
          locator<BdkBitcoinBlockchainDatasource>(),
          locator<ElectrumServersPort>(),
          spendWallet: locator<WalletFacade>(),
        ),
        labels: locator<PayjoinLabelsPort>(),
        legacyData: PayjoinLegacyDataAdapter(database),
        log: const AppPayjoinLogAdapter(),
        codec: const AppPayjoinCodecAdapter(),
      );
    }, isCurrent: isCurrent);
    _registerRoles(locator, runtime.payjoin);
    locator.registerSingleton<PayjoinLifecycle>(runtime);

    // Opening the package database and resuming sessions must not delay
    // runApp. Background isolates (workmanager handler) register the roles
    // but must NOT start recovery: the engine's own invariant is that only
    // the foreground composition root resumes sessions — a BG isolate would
    // open payjoin.sqlite concurrently with the foreground engine and run
    // the legacy migration + recovery sweep inside a ~30s iOS budget.
    if (startRecovery) {
      unawaited(
        Future<void>(() async {
          await runtime.resume();
        }),
      );
    }
  }

  static void _registerRoles(GetIt locator, Payjoin payjoin) {
    locator.registerSingleton<Payjoin>(payjoin);
    locator.registerSingleton<PayjoinSender>(payjoin.sender);
    locator.registerSingleton<PayjoinReceiver>(payjoin.receiver);
    locator.registerSingleton<PayjoinSessions>(payjoin.sessions);
    locator.registerSingleton<PayjoinPolicyAccess>(payjoin.policy);
    locator.registerSingleton<PayjoinDiagnostics>(payjoin.diagnostics);
    // Sync reads the reservations through the owner's own sessions role.
    locator.registerSingleton<InputReservationPort>(
      PayjoinInputReservationAdapter(payjoin.sessions),
    );
  }
}
