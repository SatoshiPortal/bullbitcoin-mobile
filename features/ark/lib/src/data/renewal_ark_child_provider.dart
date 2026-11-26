import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart' show ArkRenewalAuthority;

import '../domain/repositories/ark_account_registry_repository.dart';

/// The only child provider of the background task (D92). Every open it serves
/// is a renewal: saved claims rebroadcast already signed bytes and never ask
/// for a child. The seed is read, and the child derived, inside one admission
/// of [ArkRenewalAuthority] that refuses protected views; nothing here can
/// fetch a secret or hold a handle.
///
/// A null authority means the inventory could not be opened: renewals are
/// unavailable and the rest of the task goes on.
final class RenewalArkChildProvider implements ArkChildProviderPort {
  final ArkRenewalAuthority? _authority;
  final ArkAccountRegistryRepository _registry;
  const RenewalArkChildProvider(this._authority, this._registry);

  @override
  Future<Result<void, ArkWalletFailure>> admitBatch(
    ArkAccountId account,
  ) async {
    switch (await _registry.list()) {
      case Err():
        return const Err(ArkStorageFailure());
      case Ok(:final value):
        if (!value.any((c) => c.id == account)) {
          return const Err(ArkRecoveryRequiredFailure());
        }
    }
    final authority = _authority;
    if (authority == null) return const Err(ArkUnavailableFailure());
    return await authority.mayRenew(account.parent)
        ? const Ok(null)
        : const Err(
            ArkUnavailableFailure(ArkFailureReason.renewalNotPermitted),
          );
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
    switch (await _registry.list()) {
      case Err():
        return const Err(ArkStorageFailure());
      case Ok(:final value):
        if (!value.any((c) => c.id == account)) {
          return const Err(ArkRecoveryRequiredFailure());
        }
    }
    final authority = _authority;
    if (authority == null) return const Err(ArkUnavailableFailure());
    return authority.withRenewalChild<T, ArkWalletFailure>(
      parent: account.parent,
      notPermitted: const ArkUnavailableFailure(
        ArkFailureReason.renewalNotPermitted,
      ),
      unavailable: const ArkUnavailableFailure(),
      action: action,
    );
  }
}
