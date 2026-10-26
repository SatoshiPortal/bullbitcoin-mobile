import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../entities/encrypted_vault.dart';
import '../entities/decrypted_vault.dart';
import '../entities/recoverbull_flow.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_flow_failure.dart';
import '../recoverbull_lifecycle_port.dart';
import '../recoverbull_tor_route.dart';
import '../recoverbull_route_port.dart';
import 'complete_vault_recovery_usecase.dart';
import 'decrypt_vault_usecase.dart';
import 'fetch_vault_key_from_server_usecase.dart';
import 'verify_decrypted_vault_usecase.dart';

/// Contains only the explicitly revealed key, never a decrypted mnemonic.
final class AcceptedVault {
  final String? revealedKey;
  final bool completed;
  const AcceptedVault({this.revealedKey, this.completed = false});
  @override
  String toString() => 'AcceptedVault(completed: $completed, key: <redacted>)';
}

final class DecryptAndAcceptVaultUsecase {
  final LogSink log;
  final FetchVaultKeyFromServerUsecase fetch;
  final DecryptVaultUsecase decrypt;
  final VerifyDecryptedVaultUsecase verify;
  final CompleteVaultRecoveryUsecase recover;
  final RecoverBullLifecyclePort? lifecycle;

  const DecryptAndAcceptVaultUsecase({
    required this.log,
    required this.fetch,
    required this.decrypt,
    required this.verify,
    required this.recover,
    this.lifecycle,
  });

  Future<Result<AcceptedVault, RecoverBullFailure>> execute({
    required RecoverBullFlow flow,
    required EncryptedVault? vault,
    required bool Function() cancelled,
    String? password,
    String? vaultKey,
    RecoverBullTorRoute? route,
    RecoverBullRoutePort? routeOwner,
  }) async {
    if (cancelled()) return const Err(VaultDecryptionFailure());
    if (vault == null) return const Err(VaultNotSetFailure());
    try {
      var key = vaultKey;
      if (key == null) {
        if (password == null) return const Err(PasswordNotSetFailure());
        final suppliedPassword = password;
        final fetched = routeOwner == null
            ? await fetch.execute(
                vault: vault,
                password: suppliedPassword,
                route: route,
              )
            : await routeOwner.borrowRoute(
                (selected) => fetch.execute(
                  vault: vault,
                  password: suppliedPassword,
                  route: selected,
                ),
              );
        if (cancelled()) return const Err(VaultDecryptionFailure());
        switch (fetched) {
          case Err(:final failure):
            return Err(fetchVaultKeyFailure(failure));
          case Ok(:final value):
            key = value;
        }
      }
      final decrypted = decrypt.execute(vault: vault, vaultKey: key);
      final DecryptedVault secret;
      switch (decrypted) {
        case Err():
          return const Err(VaultDecryptionFailure());
        case Ok(value: final value):
          secret = value;
      }
      if (flow == RecoverBullFlow.viewVaultKey) {
        return Ok(AcceptedVault(revealedKey: key));
      }
      final verified = await verify.execute(decryptedVault: secret);
      if (cancelled()) return const Err(VaultDecryptionFailure());
      switch (verified) {
        case Err():
          return const Err(VaultDecryptionFailure());
        case Ok(:final value):
          if (value.result == VaultVerificationResult.mismatch) {
            return const Err(VaultBelongsToAnotherWalletFailure());
          }
          if (flow == RecoverBullFlow.testVault) {
            final network = value.network;
            if (value.result != VaultVerificationResult.match ||
                network == null) {
              return const Err(VaultDecryptionFailure());
            }
            try {
              await lifecycle?.markVerified(network);
            } on Exception {
              log.warning('recoverbull.lifecycle.mark_verified_failed');
            }
            if (cancelled()) return const Err(VaultDecryptionFailure());
            return const Ok(AcceptedVault(completed: true));
          }
          if (flow != RecoverBullFlow.recoverVault) {
            return const Err(VaultDecryptionFailure());
          }
          return (await recover.execute(
            vault: secret,
            cancelled: cancelled,
          )).map((_) => const AcceptedVault(completed: true));
      }
    } on Exception {
      log.warning('recoverbull.vault.accept.failed');
      return const Err(VaultDecryptionFailure());
    }
  }
}
