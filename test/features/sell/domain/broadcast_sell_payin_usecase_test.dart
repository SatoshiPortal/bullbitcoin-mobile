import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show WalletFacade;
import 'package:bb_mobile/features/wallet/domain/wallet.dart' as app;
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_liquid_transaction_usecase.dart';
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
      wallet: const WalletFacade(Stream.empty()),
      send: SendFacade(bitcoin: bitcoin.execute, liquid: liquid.execute),
    );
  });

  test('returns the bitcoin txid', () async {
    when(
      () => bitcoin.execute(
        any(),
        isPsbt: any(named: 'isPsbt'),
        walletId: any(named: 'walletId'),
        network: app.Network.bitcoinMainnet,
      ),
    ).thenAnswer((_) async => 'txid-1');

    final result = await usecase.bitcoin(
      'signed',
      walletId: 'source',
      isPsbt: true,
      network: app.Network.bitcoinMainnet,
    );

    expect((result as Ok<String, SellFailure>).value, 'txid-1');
  });

  test('a rejected bitcoin broadcast is sanitized, never raw', () async {
    when(
      () => bitcoin.execute(
        any(),
        isPsbt: any(named: 'isPsbt'),
        walletId: any(named: 'walletId'),
        network: app.Network.bitcoinMainnet,
      ),
    ).thenThrow(Exception(_rawReason));

    final result = await usecase.bitcoin(
      'signed',
      walletId: 'source',
      isPsbt: true,
      network: app.Network.bitcoinMainnet,
    );

    switch (result) {
      case Ok():
        fail('a rejected broadcast must not report a txid');
      case Err(:final failure):
        expect(failure, isA<SellUnexpectedFailure>());
        // Foreign node text must not escape through a later failure logger.
        expect(failure.logMessage, 'sell_payin_broadcast_failed');
    }
  });

  test('returns the liquid txid', () async {
    when(() => liquid.execute(any())).thenAnswer((_) async => 'txid-2');

    final result = await usecase.liquid('signed-pset', walletId: 'source');

    expect((result as Ok<String, SellFailure>).value, 'txid-2');
  });

  test('a rejected liquid broadcast is sanitized', () async {
    when(() => liquid.execute(any())).thenThrow(Exception(_rawReason));

    final result = await usecase.liquid('signed-pset', walletId: 'source');

    expect(
      (result as Err<String, SellFailure>).failure,
      isA<SellUnexpectedFailure>(),
    );
  });
}
