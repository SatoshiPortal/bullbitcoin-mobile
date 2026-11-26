import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart' as native;
import 'package:legacy_storage/coordination.dart' show RuntimeAdmission;
import 'package:primitives/primitives.dart';
// The ONE importer of this library. `test/architecture/ark_renewal_importers_test.dart`
// fails on any other.
import 'package:secrets/ark_renewal.dart';

import '../domain/repositories/ark_account_registry_repository.dart';
import 'create_ark_native_client.dart';

/// The trusted integration of the headless Ark refresh (D105).
///
/// It holds both halves that must never meet in the worker: the reading of the
/// account's dedicated BIP85 child, through the restricted `secrets` library,
/// and the native opener that consumes it. The worker receives neither: it
/// gets an [ArkClient] confined to existing accounts, whose only way to a
/// child is this provider, and it calls `synchronize(account, renew: true)`,
/// which answers with a typed outcome and no words.
///
/// Admission is fresh at every native open ([withChild]) and before every lot
/// ([admitBatch]); the SQLite write lock is released before the network runs.
/// The account must be the registered one, and its parent must belong to a view
/// with background access. A view protected by a PIN does not refuse the
/// refresh: only the dedicated child is used. An unreadable policy refuses and
/// reads no seed.
final class ArkRenewalChildProvider implements native.ArkChildProviderPort {
  final ArkRenewalSecrets? _secrets;
  final ArkAccountRegistryRepository _registry;

  /// A null [secrets] means the inventory could not be opened: refresh is
  /// unavailable and the rest of the task (saved claims) goes on.
  const ArkRenewalChildProvider(this._secrets, this._registry);

  Future<ArkWalletFailure?> _refusal(ArkAccountId account) async {
    switch (await _registry.list()) {
      case Err():
        return const ArkStorageFailure();
      case Ok(:final value):
        if (!value.any((config) => config.id == account)) {
          return const ArkRecoveryRequiredFailure();
        }
    }
    return _secrets == null ? const ArkUnavailableFailure() : null;
  }

  @override
  Future<Result<void, ArkWalletFailure>> admitBatch(
    ArkAccountId account,
  ) async {
    final refusal = await _refusal(account);
    if (refusal != null) return Err(refusal);
    final secrets = _secrets;
    if (secrets == null) return const Err(ArkUnavailableFailure());
    return await secrets.mayRefresh(account.parent)
        ? const Ok(null)
        : const Err(ArkRenewalNotPermittedFailure());
  }

  @override
  Future<Result<T, ArkWalletFailure>> withChild<T>(
    ArkAccountId account,
    Future<Result<T, ArkWalletFailure>> Function(
      String mnemonic,
      Fingerprint fingerprint,
    )
    action,
  ) async {
    final refusal = await _refusal(account);
    if (refusal != null) return Err(refusal);
    final secrets = _secrets;
    if (secrets == null) return const Err(ArkUnavailableFailure());
    return secrets.withArkChild<T, ArkWalletFailure>(
      parent: account.parent,
      notPermitted: const ArkRenewalNotPermittedFailure(),
      unavailable: const ArkUnavailableFailure(),
      action: (child) => action(child.mnemonic, child.fingerprint),
    );
  }
}

/// The background client and what it owns. [close] closes both.
final class ArkRenewalClient {
  final ArkClient client;
  final Future<void> Function() close;

  const ArkRenewalClient._(this.client, this.close);
}

/// Opens the secrets side under [admission] and builds the confined client.
/// An inventory that cannot be opened leaves refresh unavailable, never open.
Future<ArkRenewalClient> openArkRenewalClient({
  required String storagePath,
  required File secretsFile,
  required RuntimeAdmission admission,
  required ArkAccountRegistryRepository registry,
  required ArkTransactionVerifierPort transactionVerifier,
  required native.ArkExecutionPolicyPort executionPolicy,
  required native.ArkStageBudget stageBudget,
  native.ArkBoardAbandonmentPort? boardAbandonment,
  native.ArkExitObserverPort? exitObserver,
}) async {
  final secrets = switch (await ArkRenewalSecrets.open(
    file: secretsFile,
    admission: admission,
  )) {
    Ok(:final value) => value,
    Err() => null,
  };
  final client = createArkNativeClient(
    storagePath: storagePath,
    childProvider: ArkRenewalChildProvider(secrets, registry),
    transactionVerifier: transactionVerifier,
    executionPolicy: executionPolicy,
    executionMode: native.ArkExecutionMode.backgroundExisting,
    stageBudget: stageBudget,
    boardAbandonment: boardAbandonment,
    exitObserver: exitObserver,
  );
  return ArkRenewalClient._(client, () async {
    try {
      await client.close();
    } finally {
      await secrets?.close();
    }
  });
}
