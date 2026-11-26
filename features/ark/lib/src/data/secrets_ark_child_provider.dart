import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart' show arkChildBip85Index;

import '../domain/repositories/ark_account_registry_repository.dart';

/// Setup-only derived child. Parent admission happened before durable registry
/// publication; never acquire it again while package native locks are held.
final class SecretsArkChildProvider implements ArkChildProviderPort {
  final Secrets _secrets;
  final ArkAccountRegistryRepository _registry;
  const SecretsArkChildProvider(this._secrets, this._registry);

  /// The foreground session is the authority here: the seed read in
  /// [withChild] already needs it, and a lock ends the runtime.
  @override
  Future<Result<void, ArkWalletFailure>> admitBatch(
    ArkAccountId account,
  ) async => const Ok(null);

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
    switch (await _secrets.fetch(account.parent)) {
      case Err():
        return const Err(ArkRecoveryRequiredFailure());
      case Ok(:final value):
        switch (await value.derive.bip85.mnemonic(
          wordCount: MnemonicLength.words12,
          index: arkChildBip85Index,
          language: Language.english,
        )) {
          case Err():
            return const Err(ArkRecoveryRequiredFailure());
          case Ok(value: final words):
            // Strings cannot be zeroized in Dart. No field, cache, storage, log
            // or facade receives them; scope ends only after native settles.
            switch (await _secrets.preview.arkFingerprint(words: words)) {
              case Err():
                return const Err(ArkRecoveryRequiredFailure());
              case Ok(value: final fingerprint):
                return action(words.join(' '), fingerprint);
            }
        }
    }
  }
}
