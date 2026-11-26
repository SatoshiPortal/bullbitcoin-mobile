import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart' as native;
import 'package:legacy_storage/coordination.dart' show RuntimeAdmission;
import 'package:primitives/primitives.dart';
// The ONE importer of this library. `test/architecture/ark_renewal_importers_test.dart`
// fails on any other.
import 'package:secrets/ark_renewal.dart';

import '../domain/repositories/ark_account_registry_repository.dart';
import 'confined_ark_client.dart';
import 'create_ark_native_client.dart';

/// The policy half of the headless Ark refresh (D105): who may be refreshed,
/// asked afresh at every native open and before every lot. It touches no
/// words: the account must be the registered one, and its parent must belong to
/// a view with background access, a PIN notwithstanding (only the dedicated
/// child is used). An unreadable policy refuses and reads no seed.
final class ArkRenewalAdmission {
  final ArkRenewalSecrets? _secrets;
  final ArkAccountRegistryRepository _registry;

  /// A null [secrets] means the inventory could not be opened: refresh is
  /// unavailable and the rest of the task (saved claims) goes on.
  const ArkRenewalAdmission(this._secrets, this._registry);

  /// Why [account] may not be opened, or null if the registry knows it and the
  /// inventory is there. The inventory decides the rest, atomically, when the
  /// child is requested.
  Future<ArkWalletFailure?> openRefusal(ArkAccountId account) async {
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

  /// Asked before every lot of an open that is already running.
  Future<Result<void, ArkWalletFailure>> admitBatch(
    ArkAccountId account,
  ) async {
    final refusal = await openRefusal(account);
    if (refusal != null) return Err(refusal);
    final secrets = _secrets;
    if (secrets == null) return const Err(ArkUnavailableFailure());
    return await secrets.mayRefresh(account.parent)
        ? const Ok(null)
        : const Err(ArkRenewalNotPermittedFailure());
  }
}

/// The only place the child's words pass: from [ArkRenewalSecrets] to the
/// native opener the client was built with. Private: nothing can ask it for
/// them, and what the native pass produces stays in its result.
final class _ChildProvider implements native.ArkChildProviderPort {
  final ArkRenewalSecrets? _secrets;
  final ArkRenewalAdmission _admission;

  const _ChildProvider(this._secrets, this._admission);

  @override
  Future<Result<void, ArkWalletFailure>> admitBatch(ArkAccountId account) =>
      _admission.admitBatch(account);

  @override
  Future<Result<T, ArkWalletFailure>> withChild<T>(
    ArkAccountId account,
    Future<Result<T, ArkWalletFailure>> Function(
      String mnemonic,
      Fingerprint fingerprint,
    )
    action,
  ) async {
    final refusal = await _admission.openRefusal(account);
    if (refusal != null) return Err(refusal);
    final secrets = _secrets;
    if (secrets == null) return const Err(ArkUnavailableFailure());
    Result<T, ArkWalletFailure>? outcome;
    final admitted = await secrets.consumeChild(
      account.parent,
      _NativeConsumer(
        (child) async =>
            outcome = await action(child.mnemonic, child.fingerprint),
      ),
    );
    return switch (admitted) {
      ArkChildAdmission.consumed =>
        outcome ?? const Err(ArkUnavailableFailure()),
      ArkChildAdmission.notPermitted => const Err(
        ArkRenewalNotPermittedFailure(),
      ),
      ArkChildAdmission.unavailable => const Err(ArkUnavailableFailure()),
    };
  }
}

final class _NativeConsumer implements ArkChildConsumer {
  final Future<void> Function(ArkChild child) _run;
  const _NativeConsumer(this._run);

  @override
  Future<void> consume(ArkChild child) => _run(child);
}

/// The headless Ark refresh, closed (D105).
///
/// It holds both halves that must never meet in the worker: the reading of the
/// account's dedicated BIP85 child, through the restricted `secrets` library,
/// and the Bark native opener that consumes it, fixed when this is built. The
/// worker is given [client], confined to the saved-claim lane and [refresh];
/// it never holds words, a native session or a callback.
final class ArkBackgroundRenewal {
  final ArkClient client;
  final Future<void> Function() _close;

  const ArkBackgroundRenewal._(this.client, this._close);

  /// The refresh of [account]: a typed outcome, no words.
  Future<Result<ArkPassOutcome, ArkWalletFailure>> refresh(
    ArkAccountId account,
  ) => client.synchronize(account, renew: true);

  Future<void> close() => _close();

  /// Opens the secrets side under [admission] and builds the confined client.
  /// An inventory that cannot be opened leaves refresh unavailable, never open.
  static Future<ArkBackgroundRenewal> open({
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
    final inner = createArkNativeClient(
      storagePath: storagePath,
      childProvider: _ChildProvider(
        secrets,
        ArkRenewalAdmission(secrets, registry),
      ),
      transactionVerifier: transactionVerifier,
      executionPolicy: executionPolicy,
      executionMode: native.ArkExecutionMode.backgroundExisting,
      stageBudget: stageBudget,
      boardAbandonment: boardAbandonment,
      exitObserver: exitObserver,
    );
    return ArkBackgroundRenewal._(confineArkClient(inner), () async {
      try {
        await inner.close();
      } finally {
        await secrets?.close();
      }
    });
  }
}
