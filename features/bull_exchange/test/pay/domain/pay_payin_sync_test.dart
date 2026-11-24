import 'package:bull_exchange/src/pay/domain/pay_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bull_exchange/src/pay/domain/broadcast_pay_payin_usecase.dart';

class _Spend extends FakeSpend {
  final List<Object> submitted = [];

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> broadcastBitcoin(
    SignedBitcoinSpend signed,
  ) async {
    submitted.add(signed);
    return const Ok((txid: 'bitcoin', guarded: true, durable: false));
  }

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> broadcastLiquid(
    SignedLiquidSpend signed,
  ) async {
    submitted.add(signed);
    return const Ok((txid: 'liquid', guarded: false, durable: false));
  }
}

void main() {
  test(
    'returns guarded non-durable and unguarded acceptances as success',
    () async {
      final spend = _Spend();
      final usecase = BroadcastPayPayinUsecase(spend);
      final bitcoin = SpendFixtures.signedBitcoin('reviewed');
      final liquid = SpendFixtures.signedLiquid('reviewed');
      expect(
        (await usecase.bitcoin(bitcoin) as Ok<String, PayFailure>).value,
        'bitcoin',
      );
      expect(
        (await usecase.liquid(liquid) as Ok<String, PayFailure>).value,
        'liquid',
      );
      expect(spend.submitted, [same(bitcoin), same(liquid)]);
    },
  );
}
