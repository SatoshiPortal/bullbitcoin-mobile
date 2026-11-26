import 'package:primitives/primitives.dart';
import 'package:swaps/order_swaps.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

class CheckSwapSpendAdmissionUsecase {
  final WalletNativeRuntime _sync;

  const CheckSwapSpendAdmissionUsecase(this._sync);

  Future<Result<void, SwapFailure>> execute(WalletKey wallet) async =>
      switch (await _sync.spendStatus(wallet)) {
        Ok(value: BitcoinSpendStatus.ready) => const Ok(null),
        Ok(:final value) => Err(SwapSpendBlockedFailure(value)),
        Err() => const Err(
          SwapSpendBlockedFailure(BitcoinSpendStatus.unavailable),
        ),
      };
}
