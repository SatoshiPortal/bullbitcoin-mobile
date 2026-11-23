import 'package:primitives/primitives.dart'
    show BitcoinNetwork, LiquidNetwork, Network, Ok, Err;
import 'package:swaps/order_swaps.dart';
import 'package:signers/signers.dart';
import 'package:satoshifier/payment_request.dart';
import 'package:send/src/payment/domain/send_source.dart';
import 'package:secrets/testing.dart' show walletRegistrationForTesting;
import 'package:secrets/secrets.dart' show WalletSigner;
import 'package:send/src/payment/domain/usecases/load_send_sources_usecase.dart';
import 'package:address_view/address_view.dart';
import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/domain/usecases/create_send_swap_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOrderSwaps extends Mock implements OrderSwaps {}

class _MockLoadSendSourcesUsecase extends Mock
    implements LoadSendSourcesUsecase {}

class _MockGetReceiveAddressUsecase extends Mock implements AddressView {}

void main() {
  late _MockOrderSwaps swapFacade;
  late _MockLoadSendSourcesUsecase getWallet;
  late _MockGetReceiveAddressUsecase getReceiveAddress;
  late CreateSendSwapUsecase usecase;
  final now = DateTime.utc(2026, 8, 5, 12);

  setUp(() {
    swapFacade = _MockOrderSwaps();
    getWallet = _MockLoadSendSourcesUsecase();
    getReceiveAddress = _MockGetReceiveAddressUsecase();
    usecase = CreateSendSwapUsecase(
      swapFacade,
      getWalletUsecase: getWallet,
      getReceiveAddressUsecase: getReceiveAddress,
      now: () => now,
    );
  });

  for (final network in [BitcoinNetwork.regtest, LiquidNetwork.regtest]) {
    test(
      '$network refuses before receive-address or provider side effects',
      () async {
        when(() => getWallet.read('wallet-1'))
            .thenAnswer((_) async => Ok(_wallet(network)));
        final result = await usecase.execute(
          walletId: 'wallet-1',
          amountSat: 1000,
          invoice: _invoice(amountSat: 1000),
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
    final network = isTestnet ? LiquidNetwork.testnet : LiquidNetwork.mainnet;
    final fallback = isTestnet ? 'tlq1-fallback' : 'lq1-fallback';
    test(
      '$environment creates an output-fixed order with an owned fallback address',
      () async {
        final invoice = _invoice(amountSat: 1000, isTestnet: isTestnet);
        when(() => getWallet.read('wallet-1'))
            .thenAnswer((_) async => Ok(_wallet(network)));
        when(() => getReceiveAddress.receiveAddress(walletId: 'wallet-1'))
            .thenAnswer((_) async => Ok(_address(address: fallback)));
        when(
          () => swapFacade.createOrder(
            amountSat: BigInt.from(1000),
            isInAmountFixed: false,
            inNetwork: OrderSwapNetwork.liquid,
            outNetwork: OrderSwapNetwork.lightning,
            destinationAddress: invoice.invoice,
            fallbackAddress: fallback,
            purpose: OrderSwapPurpose.sendLightning,
            environment: environment,
            sourceWalletId: 'wallet-1',
            note: 'coffee',
          ),
        ).thenAnswer((_) async => Ok(_record(environment: environment)));

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
            destinationAddress: invoice.invoice,
            fallbackAddress: fallback,
            purpose: OrderSwapPurpose.sendLightning,
            environment: environment,
            sourceWalletId: 'wallet-1',
            note: 'coffee',
          ),
        ).called(1);
      },
    );
  }

  test('allows an entered amount for an amountless invoice', () async {
    final invoice = _invoice(amountSat: 0);
    when(() => getWallet.read('wallet-1'))
        .thenAnswer((_) async => Ok(_wallet(BitcoinNetwork.testnet)));
    when(() => getReceiveAddress.receiveAddress(walletId: 'wallet-1'))
        .thenAnswer((_) async => Ok(_address()));
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
      verifyNever(() => getWallet.read(any()));
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
    verifyNever(() => getWallet.read(any()));
  });

  test('rejects a Bitcoin hardware wallet before deriving fallback', () async {
    when(() => getWallet.read('wallet-1')).thenAnswer(
      (_) async => Ok(_wallet(BitcoinNetwork.testnet, remote: true)),
    );

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
      () => getReceiveAddress.receiveAddress(walletId: any(named: 'walletId')),
    );
    verifyZeroInteractions(swapFacade);
  });
}

Bolt11PaymentRequest _invoice({
  required int amountSat,
  int? expiresAt,
  bool isTestnet = true,
}) => PaymentRequest.bolt11(
  invoice: isTestnet ? 'lntb-invoice' : 'lnbc-invoice',
  amountSat: amountSat,
  paymentHash: 'hash',
  expiresAt: expiresAt ?? 2000000000,
  isTestnet: isTestnet,
) as Bolt11PaymentRequest;

SendSource _wallet(Network network, {bool remote = false}) => SendSource(
  walletRegistrationForTesting(
    id: 'wallet-1',
    network: network,
    signer: remote ? WalletSigner.remote : WalletSigner.local,
  ),
  BigInt.from(100000),
  remote ? SignerDevice.jade : null,
);

WalletAddress _address({String address = 'tlq1-fallback'}) => WalletAddress(
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
  purpose: OrderSwapPurpose.sendLightning,
  environment: environment,
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
