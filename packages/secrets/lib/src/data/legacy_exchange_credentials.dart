import 'dart:async';

import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';

import '../domain/domain.dart';
import 'owner_keychain.dart';

/// Reads the two historical Exchange records under a live exclusive lease.
/// Closing the lease waits for an already admitted read to finish.
Future<Result<({String? mainnet, String? testnet}), LegacyImportFailure>>
readLegacyExchangeCredentials(ExclusiveAdmission admission) async {
  final done = Completer<void>();
  final LifecycleHandle handle;
  try {
    handle = admission.track(() => done.future);
  } on LifecycleException {
    return const Err(LegacyImportDeferred());
  }
  try {
    final store = OwnerKeychain();
    final mainnet = await store.read(OwnerKey.exchange);
    final testnet = await store.read(OwnerKey.exchangeTestnet);
    return switch ((mainnet, testnet)) {
      (Err(failure: KeystoreLockedFailure()), _) ||
      (
        _,
        Err(failure: KeystoreLockedFailure()),
      ) => const Err(LegacyImportDeferred()),
      (Ok(value: final main), Ok(value: final test)) => Ok((
        mainnet: main,
        testnet: test,
      )),
      _ => const Err(LegacyImportUnavailable()),
    };
  } finally {
    done.complete();
    await handle.close();
  }
}
