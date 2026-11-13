import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'entities/vault_context.dart';
import 'recoverbull_failure.dart';

abstract interface class RecoverBullWalletPort {
  /// Reads the selected network before looking up that network's default.
  @useResult
  Future<Result<VaultContext?, RecoverBullFailure>> currentDefault();

  /// Creates defaults from a stored secret, returning their actual context.
  /// Existing defaults must never be overwritten.
  @useResult
  Future<Result<VaultContext, RecoverBullFailure>> restoreDefaults(
    VaultContext requested,
  );
}
