import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:signers/signers.dart';
import 'package:primitives/primitives.dart' show Err, Ok, ScriptType;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:address_view/address_view.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_cross_chain_swap_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapFacade extends Mock implements SwapFacade {}

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockGetReceiveAddressUsecase extends Mock implements AddressView {}

void main() {
  late _MockSwapFacade swapFacade;
  late _MockGetWalletUsecase getWallet;
  late _MockGetReceiveAddressUsecase getReceiveAddress;
  late CreateSendCrossChainSwapUsecase usecase;

  setUp(() {
    swapFacade = _MockSwapFacade();
    getWallet = _MockGetWalletUsecase();
    getReceiveAddress = _MockGetReceiveAddressUsecase();
    usecase = CreateSendCrossChainSwapUsecase(
      swapFacade,
      getWalletUsecase: getWallet,
      getReceiveAddressUsecase: getReceiveAddress,
    );
  });

  for (final network in [Network.bitcoinRegtest, Network.liquidRegtest]) {
    test(
      '$network refuses before receive-address or provider side effects',
      () async {
        when(() => getWallet.execute('wallet-1'))
            .thenAnswer((_) async => _wallet(network));
        final result = await usecase.execute(
          walletId: 'wallet-1',
          amountSat: 1000,
          destinationAddress: 'unused',
          destinationIsTestnet: true,
          isInAmountFixed: false,
          quotedCounterpartAmountSat: BigInt.from(1000),
        );
        expect(
          result,
          isA<Err>().having(
            (result) => result.failure,
            'failure',
            isA<SendSwapRouteUnavailableFailure>(),
          ),
        );
        verifyZeroInteractions(swapFacade);
        verifyZeroInteractions(getReceiveAddress);
      },
    );
  }

  for (final isTestnet in [false, true]) {
    final environment = isTestnet
        ? OrderSwapEnvironment.testnet
        : OrderSwapEnvironment.mainnet;
    final network = isTestnet ? Network.liquidTestnet : Network.liquidMainnet;
    test(
      '$environment creates Liquid to Bitcoin with a Liquid fallback',
      () async {
        when(() => getWallet.execute('wallet-1'))
            .thenAnswer((_) async => _wallet(network));
        when(() => getReceiveAddress.receiveAddress(walletId: 'wallet-1'))
            .thenAnswer((_) async => Ok(_address('tlq1-fallback')));
        when(
          () => swapFacade.createOrder(
            amountSat: BigInt.from(100000),
            isInAmountFixed: false,
            inNetwork: OrderSwapNetwork.liquid,
            outNetwork: OrderSwapNetwork.bitcoin,
            destinationAddress: 'tb1-destination',
            fallbackAddress: 'tlq1-fallback',
            purpose: OrderSwapPurpose.sendCrossChain,
            environment: environment,
            sourceWalletId: 'wallet-1',
            note: 'transfer',
            quotedCounterpartAmountSat: BigInt.from(101000),
          ),
        ).thenAnswer((_) async => Ok(_record(environment: environment)));
        final result = await usecase.execute(
          walletId: 'wallet-1',
          destinationAddress: 'tb1-destination',
          destinationIsTestnet: isTestnet,
          amountSat: 100000,
          isInAmountFixed: false,
          note: 'transfer',
          quotedCounterpartAmountSat: BigInt.from(101000),
        );

        expect(result, isA<Ok<OrderSwapRecord, SendFailure>>());
      },
    );
  }

  test('creates Bitcoin to Liquid with a Bitcoin fallback', () async {
    when(() => getWallet.execute('wallet-1'))
        .thenAnswer((_) async => _wallet(Network.bitcoinTestnet));
    when(() => getReceiveAddress.receiveAddress(walletId: 'wallet-1'))
        .thenAnswer((_) async => Ok(_address('tb1-fallback')));
    when(
      () => swapFacade.createOrder(
        amountSat: BigInt.from(100000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.liquid,
        destinationAddress: 'tlq1-destination',
        fallbackAddress: 'tb1-fallback',
        purpose: OrderSwapPurpose.sendCrossChain,
        environment: OrderSwapEnvironment.testnet,
        sourceWalletId: 'wallet-1',
        quotedCounterpartAmountSat: BigInt.from(101000),
        note: null,
      ),
    ).thenAnswer((_) async => Ok(_record()));
    final result = await usecase.execute(
      walletId: 'wallet-1',
      destinationAddress: 'tlq1-destination',
      destinationIsTestnet: true,
      amountSat: 100000,
      isInAmountFixed: false,
      quotedCounterpartAmountSat: BigInt.from(101000),
    );

    expect(result, isA<Ok<OrderSwapRecord, SendFailure>>());
  });

  test('rejects hardware wallets before creating an order', () async {
    when(() => getWallet.execute('wallet-1')).thenAnswer(
      (_) async => _wallet(
        Network.liquidTestnet,
        signerDevice: SignerDevice.ledgerNanoX,
      ),
    );

    final result = await usecase.execute(
      walletId: 'wallet-1',
      destinationAddress: 'tb1-destination',
      destinationIsTestnet: true,
      amountSat: 100000,
      isInAmountFixed: false,
      quotedCounterpartAmountSat: BigInt.from(101000),
    );

    expect(result, isA<Err<OrderSwapRecord, SendFailure>>());
    verifyNever(
      () => getReceiveAddress.receiveAddress(walletId: any(named: 'walletId')),
    );
  });
}

Wallet _wallet(Network network, {SignerDevice? signerDevice}) => Wallet(
  origin: 'wallet-1',
  network: network,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: signerDevice,
  balanceSat: BigInt.from(200000),
);

WalletAddress _address(String address) => WalletAddress(
  walletId: 'wallet-1',
  index: 0,
  address: address,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

OrderSwapRecord _record({
  OrderSwapEnvironment environment = OrderSwapEnvironment.testnet,
}) => OrderSwapRecord(
  localId: 'local-1',
  purpose: OrderSwapPurpose.sendCrossChain,
  environment: environment,
  inNetwork: OrderSwapNetwork.liquid,
  outNetwork: OrderSwapNetwork.bitcoin,
  isInAmountFixed: false,
  requestedAmountSat: BigInt.from(100000),
  destination: 'destination',
  fallback: 'fallback',
  createdAt: DateTime.utc(2026),
  localStatus: OrderSwapLocalStatus.creating,
);
