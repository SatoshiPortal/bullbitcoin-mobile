import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_swap_quote_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapFacade extends Mock implements SwapFacade {}

void main() {
  late _MockSwapFacade swapFacade;
  late GetSendSwapQuoteUsecase usecase;

  setUp(() {
    swapFacade = _MockSwapFacade();
    usecase = GetSendSwapQuoteUsecase(swapFacade);
  });

  test(
    'requests only the selected wallet route in output-fixed mode',
    () async {
      when(
        () => swapFacade.getQuote(
          environment: OrderSwapEnvironment.testnet,
          amountSat: BigInt.from(1000),
          isInAmountFixed: false,
          inNetwork: OrderSwapNetwork.bitcoin,
          outNetwork: OrderSwapNetwork.lightning,
        ),
      ).thenAnswer(
        (_) async => Ok(
          OrderSwapQuote(
            inAmountSat: BigInt.from(1010),
            outAmountSat: BigInt.from(1000),
            inNetwork: OrderSwapNetwork.bitcoin,
            outNetwork: OrderSwapNetwork.lightning,
            inCurrency: 'BTC',
            outCurrency: 'BTCLN',
            feeBasisPoints: 100,
            warnings: const [],
          ),
        ),
      );

      final result = await usecase.execute(
        wallet: _wallet(Network.bitcoinTestnet),
        amountSat: BigInt.from(1000),
      );

      expect(result, isA<Ok<OrderSwapQuote, SendFailure>>());
      verify(
        () => swapFacade.getQuote(
          environment: OrderSwapEnvironment.testnet,
          amountSat: BigInt.from(1000),
          isInAmountFixed: false,
          inNetwork: OrderSwapNetwork.bitcoin,
          outNetwork: OrderSwapNetwork.lightning,
        ),
      ).called(1);
    },
  );

  test('preserves an API minimum in the Send failure family', () async {
    when(
      () => swapFacade.getQuote(
        environment: OrderSwapEnvironment.testnet,
        amountSat: BigInt.from(100),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.lightning,
      ),
    ).thenAnswer(
      (_) async => Err(
        SwapAmountOutOfBoundsFailure(
          limitAmountSat: BigInt.from(500),
          isMinimum: true,
        ),
      ),
    );

    final result = await usecase.execute(
      wallet: _wallet(Network.liquidTestnet),
      amountSat: BigInt.from(100),
    );

    final failure = (result as Err<OrderSwapQuote, SendFailure>).failure;
    expect(failure, isA<SendAmountOutOfBoundsFailure>());
    expect(
      (failure as SendAmountOutOfBoundsFailure).minimumSat,
      BigInt.from(500),
    );
  });

  test('requests a mainnet quote for a mainnet wallet', () async {
    when(
      () => swapFacade.getQuote(
        environment: OrderSwapEnvironment.mainnet,
        amountSat: BigInt.from(1000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.lightning,
      ),
    ).thenAnswer(
      (_) async => Ok(
        OrderSwapQuote(
          inAmountSat: BigInt.from(1010),
          outAmountSat: BigInt.from(1000),
          inNetwork: OrderSwapNetwork.bitcoin,
          outNetwork: OrderSwapNetwork.lightning,
          inCurrency: 'BTC',
          outCurrency: 'BTCLN',
          feeBasisPoints: 100,
          warnings: const [],
        ),
      ),
    );

    final result = await usecase.execute(
      wallet: _wallet(Network.bitcoinMainnet),
      amountSat: BigInt.from(1000),
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
  balanceSat: BigInt.from(100000),
);
