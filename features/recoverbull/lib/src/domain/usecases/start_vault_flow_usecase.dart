import 'package:primitives/primitives.dart';
import '../entities/recoverbull_flow.dart';
import '../entities/vault_context.dart';
import '../recoverbull_environment_port.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_wallet_port.dart';

final class VaultFlowContext {
  final Result<VaultContext?, RecoverBullFailure> wallet;
  final Result<BitcoinNetwork, RecoverBullFailure> network;
  const VaultFlowContext(this.wallet, this.network);
}

/// Capture before file selection, password entry or any network request.
final class StartVaultFlowUsecase {
  final RecoverBullWalletPort _wallets;
  final RecoverBullEnvironmentPort _environment;
  const StartVaultFlowUsecase(this._wallets, this._environment);

  Future<VaultFlowContext> execute(
    RecoverBullFlow flow, {
    VaultContext? backupContext,
  }) async {
    if (backupContext != null &&
        (flow == RecoverBullFlow.secureVault ||
            flow == RecoverBullFlow.testVault)) {
      return VaultFlowContext(Ok(backupContext), Ok(backupContext.network));
    }
    final network = await _environment.currentNetwork();
    final wallet = switch (flow) {
      RecoverBullFlow.secureVault ||
      RecoverBullFlow.testVault => await _wallets.currentDefault(),
      _ => const Ok<VaultContext?, RecoverBullFailure>(null),
    };
    return VaultFlowContext(wallet, network);
  }
}

/// Operation-scoped capability: a selection change cannot certify a new wallet.
final class CapturedRecoverBullWalletPort implements RecoverBullWalletPort {
  final RecoverBullWalletPort _wallets;
  final VaultFlowContext _context;
  const CapturedRecoverBullWalletPort(this._wallets, this._context);

  @override
  Future<Result<VaultContext?, RecoverBullFailure>> currentDefault() async =>
      _context.wallet;

  @override
  Future<Result<VaultContext, RecoverBullFailure>> restoreDefaults(
    VaultContext requested,
  ) => _wallets.restoreDefaults(requested);
}
