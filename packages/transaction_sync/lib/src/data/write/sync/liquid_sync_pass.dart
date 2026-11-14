import 'dart:io';

import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';

import '../../../domain/public_wallet_descriptor.dart';
import '../../../domain/sync_completion.dart';
import '../../../domain/transaction_sync_failure.dart';
import '../../native_store_paths.dart';
import '../datasources/lwk_wallet_store_datasource.dart';
import '../datasources/native_store_errors.dart';
import 'payment_observation.dart';
import 'sync_pass.dart';

/// One LWK pass: open, sync through [issuedReceiveIndex], collect incoming
/// payments when asked. ⚠️ No Tor: LWK connects directly (see
/// [LwkWalletStoreDatasource.sync]).
Future<SyncPassOutcome> liquidSyncPass(
  SyncParams params,
  LiquidWalletDescriptor descriptor,
  int? issuedReceiveIndex, {
  required void Function() markMutation,
}) async {
  final watch = Stopwatch()..start();
  final path = nativeWalletStoragePath(params.root, descriptor.key);
  if (!Directory(path).existsSync()) {
    return SyncPassOutcome.failed(TransactionSyncNotFoundFailure());
  }
  if (LwkWalletStoreDatasource.network(descriptor.key.network) == null) {
    return SyncPassOutcome.failed(
      const TransactionSyncUnsupportedNetworkFailure(),
    );
  }
  LwkWalletStoreDatasource? store;
  TransactionSyncFailure failure = const TransactionSyncStorageFailure();
  try {
    // LWK init may mutate its cache. Never fallback once it has been called.
    markMutation();
    store = await LwkWalletStoreDatasource.open(path, descriptor);
    failure = const TransactionSyncConnectionFailure();
    await store.sync(params.connection, stopAtIndex: issuedReceiveIndex);
    final synced = store;
    final incoming = params.collectIncoming
        ? await collectPaymentObservation(
            synced.incomingTxids,
            warning: params.observationWarning,
          )
        : null;
    return SyncPassOutcome(
      Ok(
        SyncCompletion(SyncMode.liquid, watch.elapsed, incomingTxids: incoming),
      ),
      retryable: false,
    );
  } on lwk.LwkError catch (error) {
    return SyncPassOutcome.failed(
      isLiquidStatusConflict(error)
          ? const TransactionSyncNeedsRepairFailure()
          : failure,
    );
  } on Exception {
    return SyncPassOutcome.failed(failure);
  } finally {
    store?.close();
  }
}
