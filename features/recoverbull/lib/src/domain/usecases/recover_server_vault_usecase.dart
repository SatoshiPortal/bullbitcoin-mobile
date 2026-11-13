import 'package:primitives/primitives.dart';
import '../entities/encrypted_vault.dart';
import '../entities/recoverbull_flow.dart';
import '../entities/vault_completion.dart';
import '../recoverbull_failure.dart';
import 'manage_vault_session_usecase.dart';
import 'start_vault_flow_usecase.dart';

final class RecoverServerVaultUsecase {
  final StartVaultFlowUsecase _start;
  final ManageVaultSessionUsecase? Function(VaultFlowContext) _session;
  final RecoverBullFailure unavailable;
  const RecoverServerVaultUsecase(this._start, this._session, this.unavailable);

  Future<Result<VaultCompletion, RecoverBullFailure>> execute({
    required EncryptedVault vault,
    required String password,
  }) async {
    final context = await _start.execute(RecoverBullFlow.recoverVault);
    final BitcoinNetwork network;
    switch (context.network) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        network = value;
    }
    final session = _session(context);
    if (session == null) return Err(unavailable);
    try {
      return await session.verify(
        vault: vault,
        password: password,
        recoveryNetwork: network,
      );
    } finally {
      await session.close();
    }
  }
}
