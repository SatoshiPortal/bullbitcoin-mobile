import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' hide Network;

final class AppPayjoinFeesAdapter implements PayjoinFeesPort {
  final FeesRepository _fees;

  const AppPayjoinFeesAdapter(this._fees);

  @override
  Future<FeeRate> fastestFeeRate({required BitcoinNetwork network}) async {
    final fees = await _fees.getNetworkFees(
      network: Network.fromEnvironment(
        environment: network.env,
        isLiquid: false,
      ),
    );
    return FeeRate(fees.fastest.value.toDouble());
  }
}
