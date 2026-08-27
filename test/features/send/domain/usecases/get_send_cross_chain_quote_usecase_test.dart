import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_cross_chain_quote_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapFacade extends Mock implements SwapFacade {}

void main() {
  late _MockSwapFacade swapFacade;
  late GetSendCrossChainQuoteUsecase usecase;

  setUp(() {
    swapFacade = _MockSwapFacade();
    usecase = GetSendCrossChainQuoteUsecase(swapFacade);
  });

  test('quotes Liquid to Bitcoin as exact output', () async {
    when(
      () => swapFacade.getQuote(
        environment: OrderSwapEnvironment.testnet,
        amountSat: BigInt.from(100000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
      ),
    ).thenAnswer((_) async => Ok(_quote()));

    final result = await usecase.execute(
      wallet: _wallet(Network.liquidTestnet),
      amountSat: BigInt.from(100000),
      isInAmountFixed: false,
    );

    expect(result, isA<Ok<OrderSwapQuote, SendFailure>>());
  });

  test('quotes Bitcoin to Liquid as exact output', () async {
    when(
      () => swapFacade.getQuote(
        environment: OrderSwapEnvironment.testnet,
        amountSat: BigInt.from(100000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.liquid,
      ),
    ).thenAnswer(
      (_) async => Ok(
        _quote(
          inNetwork: OrderSwapNetwork.bitcoin,
          outNetwork: OrderSwapNetwork.liquid,
        ),
      ),
    );

    final result = await usecase.execute(
      wallet: _wallet(Network.bitcoinTestnet),
      amountSat: BigInt.from(100000),
      isInAmountFixed: false,
    );

    expect(result, isA<Ok<OrderSwapQuote, SendFailure>>());
  });
}

Wallet _wallet(Network network) => Wallet(
  origin: 'wallet-1',
  network: network,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(200000),
);

OrderSwapQuote _quote({
  OrderSwapNetwork inNetwork = OrderSwapNetwork.liquid,
  OrderSwapNetwork outNetwork = OrderSwapNetwork.bitcoin,
}) => OrderSwapQuote(
  inAmountSat: BigInt.from(101000),
  outAmountSat: BigInt.from(100000),
  inNetwork: inNetwork,
  outNetwork: outNetwork,
  inCurrency: inNetwork == OrderSwapNetwork.liquid ? 'LBTC' : 'BTC',
  outCurrency: outNetwork == OrderSwapNetwork.liquid ? 'LBTC' : 'BTC',
  feeBasisPoints: 100,
  warnings: const [],
);
