import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_receive_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapFacade extends Mock implements SwapFacade {}

class _MockGetReceiveAddressUsecase extends Mock
    implements GetReceiveAddressUsecase {}

void main() {
  late _MockSwapFacade swapFacade;
  late _MockGetReceiveAddressUsecase getReceiveAddress;
  late CreateReceiveOrderSwapUsecase usecase;

  setUp(() {
    swapFacade = _MockSwapFacade();
    getReceiveAddress = _MockGetReceiveAddressUsecase();
    usecase = CreateReceiveOrderSwapUsecase(
      swapFacade,
      getReceiveAddress,
      now: () => DateTime.utc(2026),
      parsePaymentRequest: (_) async => _invoice(),
    );
  });

  test(
    'creates an input-fixed Lightning to Liquid order without fallback',
    () async {
      when(
        () => swapFacade.getQuote(
          environment: OrderSwapEnvironment.testnet,
          amountSat: BigInt.from(100000),
          isInAmountFixed: true,
          inNetwork: OrderSwapNetwork.lightning,
          outNetwork: OrderSwapNetwork.liquid,
        ),
      ).thenAnswer((_) async => Ok(_quote()));
      when(
        () =>
            getReceiveAddress.execute(walletId: 'wallet-1', generateNew: false),
      ).thenAnswer((_) async => _address());
      when(
        () => swapFacade.createOrder(
          amountSat: BigInt.from(100000),
          isInAmountFixed: true,
          inNetwork: OrderSwapNetwork.lightning,
          outNetwork: OrderSwapNetwork.liquid,
          destinationAddress: 'tlq1-destination',
          fallbackAddress: null,
          purpose: OrderSwapPurpose.receiveLightning,
          environment: OrderSwapEnvironment.testnet,
           sourceWalletId: null,
           destinationWalletId: 'wallet-1',
           quotedCounterpartAmountSat: BigInt.from(99000),
           note: 'invoice note',
        ),
      ).thenAnswer((_) async => Ok(_record()));

      final result = await usecase.execute(
        wallet: _wallet(Network.liquidTestnet),
        amountSat: 100000,
        note: 'invoice note',
      );

      expect(result, isA<Ok<OrderSwapRecord, ReceiveFailure>>());
      verify(
        () => swapFacade.createOrder(
          amountSat: BigInt.from(100000),
          isInAmountFixed: true,
          inNetwork: OrderSwapNetwork.lightning,
          outNetwork: OrderSwapNetwork.liquid,
          destinationAddress: 'tlq1-destination',
          fallbackAddress: null,
          purpose: OrderSwapPurpose.receiveLightning,
          environment: OrderSwapEnvironment.testnet,
           sourceWalletId: null,
           destinationWalletId: 'wallet-1',
           quotedCounterpartAmountSat: BigInt.from(99000),
           note: 'invoice note',
        ),
      ).called(1);
    },
  );

  test('maps the measured minimum rejection to a receive failure', () async {
    when(
      () => swapFacade.getQuote(
        environment: OrderSwapEnvironment.testnet,
        amountSat: BigInt.from(50000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.lightning,
        outNetwork: OrderSwapNetwork.liquid,
      ),
    ).thenAnswer(
      (_) async => Err(
        SwapAmountOutOfBoundsFailure(
          limitAmountSat: BigInt.from(100000),
          isMinimum: true,
        ),
      ),
    );

    final result = await usecase.execute(
      wallet: _wallet(Network.liquidTestnet),
      amountSat: 50000,
    );

    final failure = (result as Err<OrderSwapRecord, ReceiveFailure>).failure;
    expect(failure, isA<ReceiveAmountOutOfBoundsFailure>());
    expect(
      (failure as ReceiveAmountOutOfBoundsFailure).limitAmountSat,
      BigInt.from(100000),
    );
    verifyNever(
      () => getReceiveAddress.execute(
        walletId: any(named: 'walletId'),
        generateNew: any(named: 'generateNew'),
      ),
    );
  });

  test('preserves the provider retry delay for rate limits', () async {
    when(
      () => swapFacade.getQuote(
        environment: OrderSwapEnvironment.testnet,
        amountSat: BigInt.from(50000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.lightning,
        outNetwork: OrderSwapNetwork.liquid,
      ),
    ).thenAnswer(
      (_) async =>
          const Err(SwapRateLimitedFailure(retryAfter: Duration(seconds: 45))),
    );

    final result = await usecase.execute(
      wallet: _wallet(Network.liquidTestnet),
      amountSat: 50000,
    );

    final failure = (result as Err<OrderSwapRecord, ReceiveFailure>).failure;
    expect(failure, isA<ReceiveRateLimitedFailure>());
    expect(
      (failure as ReceiveRateLimitedFailure).retryAfter,
      const Duration(seconds: 45),
    );
  });

  test(
    'rejects an invoice whose amount differs from the fixed amount',
    () async {
      usecase = CreateReceiveOrderSwapUsecase(
        swapFacade,
        getReceiveAddress,
        now: () => DateTime.utc(2026),
        parsePaymentRequest: (_) async => _invoice(amountSat: 99999),
      );
      _stubSuccessfulCreation(swapFacade, getReceiveAddress);

      final result = await usecase.execute(
        wallet: _wallet(Network.liquidTestnet),
        amountSat: 100000,
      );

      expect(
        (result as Err<OrderSwapRecord, ReceiveFailure>).failure,
        isA<ReceiveInvalidInvoiceFailure>(),
      );
    },
  );

  test('rejects an invoice that expires before the order deadline', () async {
    usecase = CreateReceiveOrderSwapUsecase(
      swapFacade,
      getReceiveAddress,
      now: () => DateTime.utc(2026),
      parsePaymentRequest: (_) async => _invoice(
        expiresAt:
            DateTime.utc(2026, 1, 1, 0, 4).millisecondsSinceEpoch ~/ 1000,
      ),
    );
    _stubSuccessfulCreation(swapFacade, getReceiveAddress);

    final result = await usecase.execute(
      wallet: _wallet(Network.liquidTestnet),
      amountSat: 100000,
    );

    expect(
      (result as Err<OrderSwapRecord, ReceiveFailure>).failure,
      isA<ReceiveInvalidInvoiceFailure>(),
    );
  });

  test(
    'accepts an invoice expiring in the same second as the deadline',
    () async {
      final deadline = DateTime.utc(2026, 1, 1, 0, 5, 0, 290);
      usecase = CreateReceiveOrderSwapUsecase(
        swapFacade,
        getReceiveAddress,
        now: () => DateTime.utc(2026),
        parsePaymentRequest: (_) async => _invoice(
          expiresAt:
              DateTime.utc(2026, 1, 1, 0, 5).millisecondsSinceEpoch ~/ 1000,
        ),
      );
      _stubSuccessfulCreation(
        swapFacade,
        getReceiveAddress,
        record: _record(confirmationDeadline: deadline),
      );

      final result = await usecase.execute(
        wallet: _wallet(Network.liquidTestnet),
        amountSat: 100000,
      );

      expect(result, isA<Ok<OrderSwapRecord, ReceiveFailure>>());
    },
  );

  test('routes mainnet through the Exchange facade', () async {
    when(
      () => swapFacade.getQuote(
        environment: OrderSwapEnvironment.mainnet,
        amountSat: BigInt.from(100000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.lightning,
        outNetwork: OrderSwapNetwork.liquid,
      ),
    ).thenAnswer(
      (_) async => const Err(SwapNetworkFailure('Mainnet unavailable')),
    );

    final result = await usecase.execute(
      wallet: _wallet(Network.liquidMainnet),
      amountSat: 100000,
    );

    expect(
      (result as Err<OrderSwapRecord, ReceiveFailure>).failure,
      isA<ReceiveNetworkFailure>(),
    );
    verify(
      () => swapFacade.getQuote(
        environment: OrderSwapEnvironment.mainnet,
        amountSat: BigInt.from(100000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.lightning,
        outNetwork: OrderSwapNetwork.liquid,
      ),
    ).called(1);
    verifyZeroInteractions(getReceiveAddress);
  });
}

void _stubSuccessfulCreation(
  _MockSwapFacade swapFacade,
  _MockGetReceiveAddressUsecase getReceiveAddress, {
  OrderSwapRecord? record,
}) {
  when(
    () => swapFacade.getQuote(
      environment: OrderSwapEnvironment.testnet,
      amountSat: BigInt.from(100000),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.lightning,
      outNetwork: OrderSwapNetwork.liquid,
    ),
  ).thenAnswer((_) async => Ok(_quote()));
  when(
    () => getReceiveAddress.execute(walletId: 'wallet-1', generateNew: false),
  ).thenAnswer((_) async => _address());
  when(
    () => swapFacade.createOrder(
      amountSat: BigInt.from(100000),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.lightning,
      outNetwork: OrderSwapNetwork.liquid,
      destinationAddress: 'tlq1-destination',
      fallbackAddress: null,
      purpose: OrderSwapPurpose.receiveLightning,
      environment: OrderSwapEnvironment.testnet,
       sourceWalletId: null,
       destinationWalletId: 'wallet-1',
       quotedCounterpartAmountSat: BigInt.from(99000),
       note: null,
    ),
  ).thenAnswer((_) async => Ok(record ?? _record()));
}

OrderSwapQuote _quote() => OrderSwapQuote(
  inAmountSat: BigInt.from(100000),
  outAmountSat: BigInt.from(99000),
  inNetwork: OrderSwapNetwork.lightning,
  outNetwork: OrderSwapNetwork.liquid,
  inCurrency: 'BTCLN',
  outCurrency: 'LBTC',
  feeBasisPoints: 100,
  warnings: const [],
);

OrderSwapRecord _record({DateTime? confirmationDeadline}) => OrderSwapRecord(
  localId: 'local-1',
  purpose: OrderSwapPurpose.receiveLightning,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.lightning,
  outNetwork: OrderSwapNetwork.liquid,
  isInAmountFixed: true,
  requestedAmountSat: BigInt.from(100000),
  destinationWalletId: 'wallet-1',
  destination: 'tlq1-destination',
  fallback: 'tlq1-destination',
  order: OrderSwap(
    orderId: 'order-1',
    orderNumber: 1,
    inNetwork: OrderSwapNetwork.lightning,
    outNetwork: OrderSwapNetwork.liquid,
    payinAmountSat: BigInt.from(100000),
    payoutAmountSat: BigInt.from(99000),
    payinCurrency: 'BTCLN',
    payoutCurrency: 'LBTC',
    payinMethod: 'Lightning',
    payoutMethod: 'Liquid',
    orderType: 'Swap',
    orderStatus: 'In_pending',
    payinStatus: 'Awaiting payment',
    payoutStatus: 'Not started',
    messageCode: 'PAYMENT_NOT_DETECTED',
    lightningInvoice: 'lntb-invoice',
    liquidAddress: 'tlq1-destination',
    createdAt: DateTime.utc(2026),
    confirmationDeadline:
        confirmationDeadline ?? DateTime.utc(2026, 1, 1, 0, 5),
  ),
  createdAt: DateTime.utc(2026),
  localStatus: OrderSwapLocalStatus.awaitingUserConfirmation,
);

Bolt11PaymentRequest _invoice({int amountSat = 100000, int? expiresAt}) =>
    PaymentRequest.bolt11(
          invoice: 'lntb-invoice',
          amountSat: amountSat,
          paymentHash: 'hash',
          expiresAt: expiresAt ?? 2000000000,
          isTestnet: true,
        )
        as Bolt11PaymentRequest;

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
  balanceSat: BigInt.zero,
);

WalletAddress _address() => WalletAddress(
  walletId: 'wallet-1',
  index: 0,
  address: 'tlq1-destination',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
