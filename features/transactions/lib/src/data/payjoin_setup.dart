import 'dart:async';

import 'package:ark/funding.dart' show ArkFundingSigningGuard;
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_payjoin/migration.dart';
import 'package:bull_payjoin/setup.dart';
import 'package:fees/fees.dart';
import 'package:get_it/get_it.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

import '../../transactions.dart';
import 'payjoin_blockchain_adapter.dart';
import 'payjoin_transaction_adapter.dart';
import 'payjoin_wallet_adapter.dart';

void mountPayjoin(GetIt locator, {bool startRecovery = true}) {
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
  Future<RegtestHostProfile?> captureProfile() => capturedProfile ??= () async {
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
        (key) async =>
            (await locator<WalletNativeRuntime>().spendStatus(key))
                .fold((value) => value, (_) => BitcoinSpendStatus.unavailable),
        locator<SecretsInventory>(),
        locator<ArkFundingSigningGuard>(),
      ),
      blockchain: AppPayjoinBlockchainAdapter(
        locator<WalletConnectionPort>(),
        locator<BroadcastObservationFollowUp>().wrap(
          (
            id,
            transaction, {
            required network,
            built,
            owner,
            replacing,
          }) async =>
              switch (await locator<SecretsInventory>().readWallet(id)) {
                Ok(:final value) => locator<WalletNativeRuntime>().broadcast(
                  WalletKey(id: value.id, network: value.network),
                  transaction,
                  network: network,
                  built: built,
                  owner: owner,
                  replacing: replacing,
                ),
                Err(failure: WalletRegistrationNotFoundFailure()) => const Err(
                  SyncNotFoundFailure(),
                ),
                Err() => const Err(SyncStorageFailure()),
              },
        ),
      ),
      fees: locator<Fees>().payjoin,
      transactions: AppPayjoinTransactionAdapter(
        locator<SecretsInventory>(),
        locator<Transactions>(),
        locator<WalletConnectionPort>(),
        synchronize: (key) async =>
            switch (await locator<WalletCatalogPort>().find(key)) {
              Ok(:final value) => ForegroundWalletSynchronization(
                locator<ElectrumSync>(),
                native: locator<WalletNativeRuntime>(),
              ).execute(value),
              Err(:final failure) => Err(failure),
            },
        finished: locator<ElectrumSync>().finished.map((event) => event.key),
        protectSpend: (id, txid) async =>
            switch (await locator<SecretsInventory>().readWallet(id)) {
              Ok(:final value) =>
                (await locator<WalletNativeRuntime>().protectObservedSpend(
                  WalletKey(id: value.id, network: value.network),
                  txid,
                )).fold((protected) => protected, (_) => false),
              Err() => false,
            },
      ),
      labels: locator<PayjoinLabelsPort>(),
      admitInputs:
          ({
            required walletId,
            required network,
            required inputs,
            required sessionId,
            required persist,
          }) async =>
              switch (await locator<WalletNativeRuntime>().reservePayjoinInputs(
                WalletKey(id: walletId, network: network),
                inputs: inputs,
                sessionId: sessionId,
                persist: persist,
              )) {
                Ok() => const Ok(null),
                Err(:final failure) => Err(
                  PayjoinSpendBlockedFailure(busy: failure is SyncBusyFailure),
                ),
              },
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

void _registerRoles(GetIt locator, Payjoin payjoin) {
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
