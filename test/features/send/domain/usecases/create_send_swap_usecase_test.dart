import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
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
  late CreateSendSwapUsecase usecase;
  final now = DateTime.utc(2026, 8, 5, 12);

  setUp(() {
    swapFacade = _MockSwapFacade();
    getWallet = _MockGetWalletUsecase();
    getReceiveAddress = _MockGetReceiveAddressUsecase();
    usecase = CreateSendSwapUsecase(
      swapFacade,
      getWalletUsecase: getWallet,
      getReceiveAddressUsecase: getReceiveAddress,
      now: () => now,
    );
  });

  test(
    'creates an output-fixed order with an owned fallback address',
    () async {
      final invoice = _invoice(amountSat: 1000);
      when(
        () => getWallet.execute('wallet-1'),
      ).thenAnswer((_) async => _wallet(Network.liquidTestnet));
      when(
        () => getReceiveAddress.execute(walletId: 'wallet-1'),
      ).thenAnswer((_) async => _address());
      when(
        () => swapFacade.createOrder(
          amountSat: BigInt.from(1000),
          isInAmountFixed: false,
          inNetwork: OrderSwapNetwork.liquid,
          outNetwork: OrderSwapNetwork.lightning,
          destinationAddress: 'lntb-invoice',
          fallbackAddress: 'tlq1-fallback',
          purpose: OrderSwapPurpose.sendLightning,
          environment: OrderSwapEnvironment.testnet,
          sourceWalletId: 'wallet-1',
          note: 'coffee',
        ),
      ).thenAnswer((_) async => Ok(_record()));

      final result = await usecase.execute(
        walletId: 'wallet-1',
        invoice: invoice,
        amountSat: 1000,
        note: 'coffee',
      );

      expect(result, isA<Ok<OrderSwapRecord, SendFailure>>());
      verify(
        () => swapFacade.createOrder(
          amountSat: BigInt.from(1000),
          isInAmountFixed: false,
          inNetwork: OrderSwapNetwork.liquid,
          outNetwork: OrderSwapNetwork.lightning,
          destinationAddress: 'lntb-invoice',
          fallbackAddress: 'tlq1-fallback',
          purpose: OrderSwapPurpose.sendLightning,
          environment: OrderSwapEnvironment.testnet,
          sourceWalletId: 'wallet-1',
          note: 'coffee',
        ),
      ).called(1);
    },
  );

  test('allows an entered amount for an amountless invoice', () async {
    final invoice = _invoice(amountSat: 0);
    when(
      () => getWallet.execute('wallet-1'),
    ).thenAnswer((_) async => _wallet(Network.bitcoinTestnet));
    when(
      () => getReceiveAddress.execute(walletId: 'wallet-1'),
    ).thenAnswer((_) async => _address());
    when(
      () => swapFacade.createOrder(
        amountSat: BigInt.from(2000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.lightning,
        destinationAddress: 'lntb-invoice',
        fallbackAddress: 'tlq1-fallback',
        purpose: OrderSwapPurpose.sendLightning,
        environment: OrderSwapEnvironment.testnet,
        sourceWalletId: 'wallet-1',
        note: null,
      ),
    ).thenAnswer((_) async => Ok(_record()));
    final result = await usecase.execute(
      walletId: 'wallet-1',
      invoice: invoice,
      amountSat: 2000,
    );

    expect(result, isA<Ok<OrderSwapRecord, SendFailure>>());
  });

  test(
    'rejects a contradictory fixed invoice amount before any lookup',
    () async {
      final result = await usecase.execute(
        walletId: 'wallet-1',
        invoice: _invoice(amountSat: 1000),
        amountSat: 2000,
      );

      expect(
        (result as Err<OrderSwapRecord, SendFailure>).failure,
        isA<SendInvalidPaymentRequestFailure>(),
      );
      verifyNever(() => getWallet.execute(any()));
    },
  );

  test('rejects an expired invoice before any lookup', () async {
    final result = await usecase.execute(
      walletId: 'wallet-1',
      invoice: _invoice(amountSat: 1000, expiresAt: 1),
      amountSat: 1000,
    );

    expect(
      (result as Err<OrderSwapRecord, SendFailure>).failure,
      isA<SendInvoiceExpiredFailure>(),
    );
    verifyNever(() => getWallet.execute(any()));
  });

  test('rejects a Bitcoin hardware wallet before deriving fallback', () async {
    when(
      () => getWallet.execute('wallet-1'),
    ).thenAnswer((_) async => _wallet(Network.bitcoinTestnet, remote: true));

    final result = await usecase.execute(
      walletId: 'wallet-1',
      invoice: _invoice(amountSat: 1000),
      amountSat: 1000,
    );

    expect(
      (result as Err<OrderSwapRecord, SendFailure>).failure,
      isA<SendHardwareWalletFailure>(),
    );
    verifyNever(
      () => getReceiveAddress.execute(walletId: any(named: 'walletId')),
    );
    verifyZeroInteractions(swapFacade);
  });
}

Bolt11PaymentRequest _invoice({required int amountSat, int? expiresAt}) =>
    PaymentRequest.bolt11(
          invoice: 'lntb-invoice',
          amountSat: amountSat,
          paymentHash: 'hash',
          expiresAt: expiresAt ?? 2000000000,
          isTestnet: true,
        )
        as Bolt11PaymentRequest;

Wallet _wallet(Network network, {bool remote = false}) => Wallet(
  origin: 'wallet-1',
  network: network,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: remote ? SignerEntity.remote : SignerEntity.local,
  signerDevice: remote ? SignerDeviceEntity.jade : null,
  balanceSat: BigInt.from(100000),
);

WalletAddress _address() => WalletAddress(
  walletId: 'wallet-1',
  index: 0,
  address: 'tlq1-fallback',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

OrderSwapRecord _record() => OrderSwapRecord(
  localId: 'local-1',
  purpose: OrderSwapPurpose.sendLightning,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.liquid,
  outNetwork: OrderSwapNetwork.lightning,
  isInAmountFixed: false,
  requestedAmountSat: BigInt.from(1000),
  destination: 'lntb-invoice',
  fallback: 'tlq1-fallback',
  order: OrderSwap(
    orderId: 'order-1',
    orderNumber: 1,
    inNetwork: OrderSwapNetwork.liquid,
    outNetwork: OrderSwapNetwork.lightning,
    payinAmountSat: BigInt.from(1010),
    payoutAmountSat: BigInt.from(1000),
    payinCurrency: 'LBTC',
    payoutCurrency: 'BTCLN',
    payinMethod: 'Liquid',
    payoutMethod: 'Lightning',
    orderType: 'Swap',
    orderStatus: 'Awaiting payment',
    payinStatus: 'In progress',
    payoutStatus: 'In progress',
    messageCode: 'ORDER_CREATED',
    liquidAddress: 'tlq1-payin',
    createdAt: DateTime.utc(2026),
    confirmationDeadline: DateTime.utc(2026, 1, 1, 0, 5),
  ),
  createdAt: DateTime.utc(2026),
  localStatus: OrderSwapLocalStatus.awaitingUserConfirmation,
);
