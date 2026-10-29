import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:background_tasks/background_tasks.dart'
    show WalletPaymentNotificationIdentity;
import 'package:transaction_sync/transaction_sync.dart' show WalletNetworkKey;
import 'package:primitives/primitives.dart';

class ResolveNotificationWalletUsecase {
  final GetWalletsUsecase _get;
  ResolveNotificationWalletUsecase({required this._get});
  Future<String?> execute(String opaqueKey) async {
    final result = await _get.execute();
    if (result case Ok(:final value)) {
      for (final wallet in value) {
        final key = WalletNetworkKey(
          wallet.id,
          wallet.isLiquid ? 'liquid' : 'bitcoin',
          wallet.isTestnet ? 'testnet' : 'mainnet',
        );
        if (WalletPaymentNotificationIdentity.topicId(key) == opaqueKey) {
          return wallet.id;
        }
      }
    }
    return null;
  }
}
