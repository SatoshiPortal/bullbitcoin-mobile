import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bull_exchange/src/sell/domain/usecases/broadcast_sell_payin_usecase.dart';

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
      final usecase = BroadcastSellPayinUsecase(spend);
      final bitcoin = SpendFixtures.signedBitcoin('reviewed');
      final liquid = SpendFixtures.signedLiquid('reviewed');
      expect(
        (await usecase.bitcoin(bitcoin) as Ok<String, SellFailure>).value,
        'bitcoin',
      );
      expect(
        (await usecase.liquid(liquid) as Ok<String, SellFailure>).value,
        'liquid',
      );
      expect(spend.submitted, [same(bitcoin), same(liquid)]);
    },
  );
}
