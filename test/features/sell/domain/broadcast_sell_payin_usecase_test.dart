import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/features/sell/domain/broadcast_sell_payin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockBroadcastBitcoin extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class _MockBroadcastLiquid extends Mock
    implements BroadcastLiquidTransactionUsecase {}

const _rawReason = 'RpcError -26: min relay fee not met, bc1qchangeaddress';

void main() {
  late _MockBroadcastBitcoin bitcoin;
  late _MockBroadcastLiquid liquid;
  late BroadcastSellPayinUsecase usecase;

  setUp(() {
    bitcoin = _MockBroadcastBitcoin();
    liquid = _MockBroadcastLiquid();
    usecase = BroadcastSellPayinUsecase(
      broadcastBitcoinTransactionUsecase: bitcoin,
      broadcastLiquidTransactionUsecase: liquid,
    );
  });

  test('returns the bitcoin txid', () async {
    when(
      () => bitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
    ).thenAnswer((_) async => 'txid-1');

    final result = await usecase.bitcoin('signed', isPsbt: true);

    expect((result as Ok<String, SellFailure>).value, 'txid-1');
  });

  test('a rejected bitcoin broadcast is sanitized, never raw', () async {
    when(
      () => bitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
    ).thenThrow(Exception(_rawReason));

    final result = await usecase.bitcoin('signed', isPsbt: true);

    switch (result) {
      case Ok():
        fail('a rejected broadcast must not report a txid');
      case Err(:final failure):
        expect(failure, isA<SellUnexpectedFailure>());
        // The node's reason quotes a change address; logs only.
        expect(failure.logMessage, contains('min relay fee'));
    }
  });

  test('returns the liquid txid', () async {
    when(() => liquid.execute(any())).thenAnswer((_) async => 'txid-2');

    final result = await usecase.liquid('signed-pset');

    expect((result as Ok<String, SellFailure>).value, 'txid-2');
  });

  test('a rejected liquid broadcast is sanitized', () async {
    when(() => liquid.execute(any())).thenThrow(Exception(_rawReason));

    final result = await usecase.liquid('signed-pset');

    expect(
      (result as Err<String, SellFailure>).failure,
      isA<SellUnexpectedFailure>(),
    );
  });
}
