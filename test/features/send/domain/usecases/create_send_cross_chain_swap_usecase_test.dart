import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_cross_chain_swap_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapFacade extends Mock implements SwapFacade {}

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockGetReceiveAddressUsecase extends Mock
    implements GetReceiveAddressUsecase {}

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

  test('creates Liquid to Bitcoin with a Liquid fallback', () async {
    when(
      () => getWallet.execute('wallet-1'),
    ).thenAnswer((_) async => _wallet(Network.liquidTestnet));
    when(
      () => getReceiveAddress.execute(walletId: 'wallet-1'),
    ).thenAnswer((_) async => _address('tlq1-fallback'));
    when(
      () => swapFacade.createOrder(
        amountSat: BigInt.from(100000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
        destinationAddress: 'tb1-destination',
        fallbackAddress: 'tlq1-fallback',
        purpose: OrderSwapPurpose.sendCrossChain,
        environment: OrderSwapEnvironment.testnet,
        sourceWalletId: 'wallet-1',
        note: 'transfer',
      ),
    ).thenAnswer((_) async => Ok(_record()));
    final result = await usecase.execute(
      walletId: 'wallet-1',
      destinationAddress: 'tb1-destination',
      destinationIsTestnet: true,
      amountSat: 100000,
      isInAmountFixed: false,
      note: 'transfer',
    );

    expect(result, isA<Ok<OrderSwapRecord, SendFailure>>());
  });

  test('creates Bitcoin to Liquid with a Bitcoin fallback', () async {
    when(
      () => getWallet.execute('wallet-1'),
    ).thenAnswer((_) async => _wallet(Network.bitcoinTestnet));
    when(
      () => getReceiveAddress.execute(walletId: 'wallet-1'),
    ).thenAnswer((_) async => _address('tb1-fallback'));
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
        note: null,
      ),
    ).thenAnswer((_) async => Ok(_record()));
    final result = await usecase.execute(
      walletId: 'wallet-1',
      destinationAddress: 'tlq1-destination',
      destinationIsTestnet: true,
      amountSat: 100000,
      isInAmountFixed: false,
    );

    expect(result, isA<Ok<OrderSwapRecord, SendFailure>>());
  });

  test('rejects hardware wallets before creating an order', () async {
    when(() => getWallet.execute('wallet-1')).thenAnswer(
      (_) async => _wallet(
        Network.liquidTestnet,
        signerDevice: SignerDeviceEntity.ledgerNanoX,
      ),
    );

    final result = await usecase.execute(
      walletId: 'wallet-1',
      destinationAddress: 'tb1-destination',
      destinationIsTestnet: true,
      amountSat: 100000,
      isInAmountFixed: false,
    );

    expect(result, isA<Err<OrderSwapRecord, SendFailure>>());
    verifyNever(
      () => getReceiveAddress.execute(walletId: any(named: 'walletId')),
    );
  });
}

Wallet _wallet(Network network, {SignerDeviceEntity? signerDevice}) => Wallet(
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

OrderSwapRecord _record() => OrderSwapRecord(
  localId: 'local-1',
  purpose: OrderSwapPurpose.sendCrossChain,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.liquid,
  outNetwork: OrderSwapNetwork.bitcoin,
  isInAmountFixed: false,
  requestedAmountSat: BigInt.from(100000),
  destination: 'destination',
  fallback: 'fallback',
  createdAt: DateTime.utc(2026),
  localStatus: OrderSwapLocalStatus.creating,
);
