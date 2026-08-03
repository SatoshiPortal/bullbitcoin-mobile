import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/domain/usecases/confirm_sell_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPrepareBitcoinSendUsecase extends Mock
    implements PrepareBitcoinSendUsecase {}

class MockPrepareLiquidSendUsecase extends Mock
    implements PrepareLiquidSendUsecase {}

class MockSignBitcoinTxUsecase extends Mock implements SignBitcoinTxUsecase {}

class MockSignLiquidTxUsecase extends Mock implements SignLiquidTxUsecase {}

class MockBroadcastBitcoinTransactionUsecase extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class MockBroadcastLiquidTransactionUsecase extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class MockLabelsFacade extends Mock implements LabelsFacade {}

class MockWallet extends Mock implements Wallet {}

class MockSellOrder extends Mock implements SellOrder {}

class MockLabel extends Mock implements Label {}

void main() {
  late MockPrepareBitcoinSendUsecase prepareBitcoin;
  late MockPrepareLiquidSendUsecase prepareLiquid;
  late MockSignBitcoinTxUsecase signBitcoin;
  late MockSignLiquidTxUsecase signLiquid;
  late MockBroadcastBitcoinTransactionUsecase broadcastBitcoin;
  late MockBroadcastLiquidTransactionUsecase broadcastLiquid;
  late MockLabelsFacade labelsFacade;
  late ConfirmSellPayinUsecase usecase;

  setUpAll(() {
    registerFallbackValue(const RelativeFee(1));
    registerFallbackValue(
      NewLabel.tx(transactionId: 'fallback', label: 'fallback'),
    );
  });

  setUp(() {
    prepareBitcoin = MockPrepareBitcoinSendUsecase();
    prepareLiquid = MockPrepareLiquidSendUsecase();
    signBitcoin = MockSignBitcoinTxUsecase();
    signLiquid = MockSignLiquidTxUsecase();
    broadcastBitcoin = MockBroadcastBitcoinTransactionUsecase();
    broadcastLiquid = MockBroadcastLiquidTransactionUsecase();
    labelsFacade = MockLabelsFacade();
    usecase = ConfirmSellPayinUsecase(
      prepareBitcoinSendUsecase: prepareBitcoin,
      prepareLiquidSendUsecase: prepareLiquid,
      signBitcoinTxUsecase: signBitcoin,
      signLiquidTxUsecase: signLiquid,
      broadcastBitcoinTransactionUsecase: broadcastBitcoin,
      broadcastLiquidTransactionUsecase: broadcastLiquid,
      labelsFacade: labelsFacade,
      // Inject deterministic txid derivation so the money path is testable
      // without a real BDK/LWK transaction.
      bitcoinTxidFromPsbt: (_) async => 'btc-txid',
      liquidTxidFromPset: (_) async => 'lq-txid',
    );
  });

  SellOrder order() {
    final o = MockSellOrder();
    when(() => o.payinAmount).thenReturn(0.0005);
    when(() => o.bitcoinAddress).thenReturn('bc1qpayin');
    when(() => o.liquidAddress).thenReturn('lq1qpayin');
    return o;
  }

  Wallet wallet({required bool isLiquid}) {
    final w = MockWallet();
    when(() => w.id).thenReturn('wallet-1');
    when(() => w.isLiquid).thenReturn(isLiquid);
    return w;
  }

  void stubBitcoinHappyPath() {
    when(
      () => prepareBitcoin.execute(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        networkFee: any(named: 'networkFee'),
        selectedInputs: any(named: 'selectedInputs'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).thenAnswer(
      (_) async => (unsignedPsbt: 'psbt', txSize: 110, isToSelf: false),
    );
    when(
      () => signBitcoin.execute(
        psbt: any(named: 'psbt'),
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async => (signedPsbt: 'signed-psbt', txSize: 110));
    when(
      () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
    ).thenAnswer((_) async => 'btc-txid');
  }

  group('ConfirmSellPayinUsecase', () {
    test('bitcoin happy path → Ok(txid), broadcasts and labels', () async {
      stubBitcoinHappyPath();
      when(
        () => labelsFacade.store(any()),
      ).thenAnswer((_) async => Ok<Label, LabelFailure>(MockLabel()));

      final result = await usecase.execute(
        wallet: wallet(isLiquid: false),
        sellOrder: order(),
        absoluteFees: 300,
      );

      expect(result, isA<Ok>());
      expect((result as Ok).value, 'btc-txid');
      verify(
        () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
      ).called(1);
      verify(() => labelsFacade.store(any())).called(1);
    });

    test(
      'labelling failure after a successful broadcast still returns Ok — the '
      'payin is never demoted to a failure (no double-spend retry)',
      () async {
        stubBitcoinHappyPath();
        when(
          () => labelsFacade.store(any()),
        ).thenThrow(Exception('label boom'));

        final result = await usecase.execute(
          wallet: wallet(isLiquid: false),
          sellOrder: order(),
          absoluteFees: 300,
        );

        expect(result, isA<Ok>());
        expect((result as Ok).value, 'btc-txid');
      },
    );

    test(
      'bitcoin with no absoluteFees → SellPrepareTransactionFailure before any '
      'transaction is built',
      () async {
        final result = await usecase.execute(
          wallet: wallet(isLiquid: false),
          sellOrder: order(),
          absoluteFees: null,
        );

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<SellPrepareTransactionFailure>());
        verifyNever(
          () => prepareBitcoin.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            amountSat: any(named: 'amountSat'),
            networkFee: any(named: 'networkFee'),
            selectedInputs: any(named: 'selectedInputs'),
            replaceByFee: any(named: 'replaceByFee'),
          ),
        );
      },
    );

    test(
      'a pre-broadcast bitcoin throw → SellSendPaymentFailure that does NOT leak '
      'the raw exception message, and no broadcast happens',
      () async {
        when(
          () => prepareBitcoin.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            amountSat: any(named: 'amountSat'),
            networkFee: any(named: 'networkFee'),
            selectedInputs: any(named: 'selectedInputs'),
            replaceByFee: any(named: 'replaceByFee'),
          ),
        ).thenThrow(Exception('secret descriptor xpub boom'));

        final result = await usecase.execute(
          wallet: wallet(isLiquid: false),
          sellOrder: order(),
          absoluteFees: 300,
        );

        expect(result, isA<Err>());
        final failure = (result as Err).failure;
        expect(failure, isA<SellSendPaymentFailure>());
        // Sanitized: the raw exception text must never reach logMessage.
        expect(
          (failure as SellSendPaymentFailure).logMessage,
          isNot(contains('secret descriptor xpub boom')),
        );
        verifyNever(
          () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
        );
      },
    );

    test(
      'a pre-broadcast liquid throw → SellSendPaymentFailure, no broadcast',
      () async {
        when(
          () => prepareLiquid.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            amountSat: any(named: 'amountSat'),
            feeRate: any(named: 'feeRate'),
          ),
        ).thenThrow(Exception('liquid prepare boom'));

        final result = await usecase.execute(
          wallet: wallet(isLiquid: true),
          sellOrder: order(),
          absoluteFees: null,
        );

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<SellSendPaymentFailure>());
        verifyNever(() => broadcastLiquid.execute(any()));
      },
    );
  });
}
