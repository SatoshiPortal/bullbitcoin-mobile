import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_preferences_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart';
import 'package:meta/meta.dart';

final class GetBtcpayWalletBehaviorsUsecase {
  final GetWalletPreferencesUsecase _getPreferences;

  const GetBtcpayWalletBehaviorsUsecase(this._getPreferences);

  @useResult
  Future<Result<List<BtcpayWalletBehavior>, BtcpayFailure>> execute({
    BtcpayConnection? connection,
  }) async {
    final preferencesResult = await _getPreferences.execute();
    final List<WalletPreferences> preferences;
    switch (preferencesResult) {
      case Ok(:final value):
        preferences = value;
      case Err(:final failure):
        return Err(BtcpayStorageFailure(failure.runtimeType.toString()));
    }

    final byId = {for (final item in preferences) item.walletRef: item};
    final results = <BtcpayWalletBehavior>[];
    for (final network
        in connection?.walletNetworks ?? BtcpayWalletNetwork.values) {
      final storedId = connection?.walletIds[network];
      final preference = storedId == null
          ? preferences
                .where((item) => item.label == network.walletLabel)
                .firstOrNull
          : byId[storedId];
      if (preference == null) continue;
      results.add(
        BtcpayWalletBehavior(
          network: network,
          walletId: preference.walletRef,
          hideOnHome: preference.hideOnHome ?? false,
          autoSweepEnabled: preference.autoSweepEnabled ?? false,
        ),
      );
    }
    return Ok(List.unmodifiable(results));
  }
}

final class BtcpayWalletBehavior {
  final BtcpayWalletNetwork network;
  final String walletId;
  final bool hideOnHome;
  final bool autoSweepEnabled;

  const BtcpayWalletBehavior({
    required this.network,
    required this.walletId,
    required this.hideOnHome,
    required this.autoSweepEnabled,
  });
}
