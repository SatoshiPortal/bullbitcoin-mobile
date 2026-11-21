import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show NetworkX, SignedPset, WalletFacade;
import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:sync/sync.dart' show SyncProtectedInputsFailure;
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/features/send/domain/broadcast_failure.dart';
import 'package:bb_mobile/features/send/data/broadcast_failure_mapper.dart';
import 'package:preferences/preferences.dart';

class BroadcastLiquidTransactionUsecase {
  final LiquidBlockchainRepository _liquidBlockchain;
  final SettingsRepository _settingsRepository;
  final WalletFacade? _wallet;

  BroadcastLiquidTransactionUsecase({
    required LiquidBlockchainRepository liquidBlockchainRepository,
    required this._settingsRepository,
    this._wallet,
  }) : _liquidBlockchain = liquidBlockchainRepository;

  /// Broadcasts [signedPset]. With [walletId], `wallet.tx` checks its
  /// generation and the freezes first.
  ///
  /// ⚠️ Liquid has no spend guard: nothing prevents a concurrent spend of
  /// the same coins, and the receipt records nothing.
  Future<String> execute(
    String signedPset, {
    Network? network,
    bool? isTestnet,
    String? walletId,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      if (network != null && isTestnet != null) {
        throw ArgumentError('Specify one network context');
      }
      network ??= isTestnet == null
          ? Network.fromEnvironment(
              environment: settings.environment.networkEnv,
              isLiquid: true,
            )
          : isTestnet
          ? Network.liquidTestnet
          : Network.liquidMainnet;
      if (!network.isMainnet &&
          (settings.isSuperuser != true || settings.isDevModeEnabled != true)) {
        log.warning('Liquid broadcast refused category=authorization');
        throw CategorizedBroadcastException(
          BroadcastFailureCategory.authorization,
        );
      }
      final wallet = _wallet;
      if (walletId != null && wallet != null) {
        return switch (await wallet.broadcastSpend(
          walletId,
          SignedPset(signedPset),
          network: network.shared,
        )) {
          Ok(:final value) => value.txid,
          Err(failure: SyncProtectedInputsFailure()) =>
            throw CategorizedBroadcastException(
              BroadcastFailureCategory.rejected,
            ),
          Err(:final failure) => throw CategorizedBroadcastException(
            broadcastFailureCategory(failure),
          ),
        };
      }
      return await _liquidBlockchain.broadcastTransaction(
        signedPset: signedPset,
        network: network,
      );
    } on Exception catch (e) {
      throw CategorizedBroadcastException(mapBroadcastFailure(e));
    }
  }
}
