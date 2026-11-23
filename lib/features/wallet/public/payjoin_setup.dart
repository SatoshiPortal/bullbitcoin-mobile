import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';
import 'package:bull_ark/ark_wallet_setup.dart' show ArkFundingSigningGuard;
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';

import 'dart:async';

import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import 'package:fees/fees.dart';
import 'package:sync/write.dart' show WalletNativeRuntime;
import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/data/payjoin_wallet_adapter.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:transactions/transactions.dart';
import 'package:bb_mobile/features/wallet/data/payjoin_blockchain_adapter.dart';
import 'package:bb_mobile/features/wallet/data/payjoin_codec_adapter.dart';
import 'package:bb_mobile/features/wallet/data/payjoin_input_reservation_adapter.dart';
import 'package:bb_mobile/features/wallet/data/payjoin_log_adapter.dart';
import 'package:bb_mobile/features/wallet/data/payjoin_transaction_adapter.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_payjoin/migration.dart';
import 'package:get_it/get_it.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart'
    show InputReservationPort, WalletConnectionPort, BitcoinSpendStatus;

abstract final class PayjoinSetup {
  static void setup(GetIt locator, {bool startRecovery = true}) {
    bool? capturedRegtest;
    Future<bool> isCurrent() async {
      try {
        final active = ((await locator<Preferences>().fetch()).fold(
          (value) => value,
          (failure) => throw Exception('Preferences read failed'),
        )).activeNetwork;
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
          final settings = (await locator<Preferences>().fetch()).fold(
            (value) => value,
            (failure) => throw Exception('Preferences read failed'),
          );
          final host = RegtestHostProfile.forNetwork(settings.activeNetwork);
          capturedRegtest = host != null;
          return host;
        }();

    final runtime = RecoverablePayjoin(() async {
      final profile = await captureProfile();
      return openPayjoin(
        regtestHostProfile: profile,
        isCurrent: isCurrent,
        admission: locator<RuntimeAdmission>(),
        productionCutover: locator<PayjoinCutover>(),
        regtestCutover: locator<PayjoinCutover>(instanceName: 'regtest'),
        wallet: PayjoinWalletAdapter(
          locator<Secrets>(),
          locator<WalletNativeRuntime>().wallet,
          (id) async {
            try {
              return WalletSyncBinding.value<BitcoinSpendStatus>(
                await locator<WalletNativeRuntime>().spendStatus(
                  await WalletSyncBinding.keyForId(
                    locator<WalletRegistrations>(),
                    id,
                  ),
                ),
              );
            } on Exception {
              return BitcoinSpendStatus.unavailable;
            }
          },
          locator<SyncWalletValuesDatasource>(),
          locator<WalletRegistrations>(),
          locator<ArkFundingSigningGuard>(),
        ),
        blockchain: AppPayjoinBlockchainAdapter(
          locator<WalletConnectionPort>(),
          locator<WalletFacade>(),
        ),
        fees: locator<Fees>().payjoin,
        transactions: AppPayjoinTransactionAdapter(
          locator<WalletRepository>(),
          locator<Transactions>(),
          locator<WalletConnectionPort>(),
          spendWallet: locator<WalletFacade>(),
        ),
        labels: locator<PayjoinLabelsPort>(),
        log: const AppPayjoinLogAdapter(),
        codec: const AppPayjoinCodecAdapter(),
      );
    }, isCurrent: isCurrent);
    _registerRoles(locator, runtime.payjoin);
    locator.registerSingleton<PayjoinLifecycle>(
      runtime,
      dispose: (value) => value.dispose(),
    );

    // Opening the package database and resuming sessions must not delay
    // runApp. Background isolates (workmanager handler) register the roles
    // but must NOT start recovery: the engine's own invariant is that only
    // the foreground composition root resumes sessions.
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
