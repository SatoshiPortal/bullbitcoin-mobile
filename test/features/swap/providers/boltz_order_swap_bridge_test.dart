import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart' as core;
import 'package:bb_mobile/features/swap/providers/boltz_order_swap_bridge.dart';
import 'package:bull_swap/bull_swap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockResolver extends Mock implements SwapProviderResolver {}

class _MockProvider extends Mock implements SwapProvider {}

class _MockBoltzRepo extends Mock implements BoltzSwapRepository {}

const _boltzConfig = SwapProviderConfig(
  id: 'boltz',
  kind: SwapProviderKind.boltz,
  name: 'Boltz',
  baseUrl: 'api.boltz.exchange/v2',
);

const _bullConfig = SwapProviderConfig(
  id: 'bull',
  kind: SwapProviderKind.bull,
  name: 'Bull',
  isBuiltIn: true,
);

final _now = DateTime.utc(2026, 8, 5, 12);

OrderSwap _sendOrder() => OrderSwap(
  orderId: 'swap-1',
  orderNumber: 0,
  inNetwork: OrderSwapNetwork.bitcoin,
  outNetwork: OrderSwapNetwork.lightning,
  payinAmountSat: BigInt.from(1000),
  payoutAmountSat: BigInt.from(1000),
  payinCurrency: 'BTC',
  payoutCurrency: 'LN-BTC',
  payinMethod: 'onchain',
  payoutMethod: 'lightning',
  orderType: 'swap',
  orderStatus: 'pending',
  payinStatus: 'pending',
  payoutStatus: 'pending',
  messageCode: 'OK',
  bitcoinAddress: 'bc1payin',
  lightningInvoice: 'invoice',
  createdAt: _now,
  confirmationDeadline: _now.add(const Duration(hours: 1)),
);

OrderSwapRecord _sendRecord({OrderSwap? order}) => OrderSwapRecord(
  localId: 'local-1',
  purpose: OrderSwapPurpose.sendLightning,
  environment: OrderSwapEnvironment.mainnet,
  inNetwork: OrderSwapNetwork.bitcoin,
  outNetwork: OrderSwapNetwork.lightning,
  isInAmountFixed: false,
  requestedAmountSat: BigInt.from(1000),
  destination: 'invoice',
  fallback: 'fallback',
  createdAt: _now,
  localStatus: order == null
      ? OrderSwapLocalStatus.creating
      : OrderSwapLocalStatus.payoutInProgress,
  sourceWalletId: 'wallet-1',
  order: order,
);

core.LnSendSwap _lnSend(core.SwapStatus status) =>
    core.Swap.lnSend(
          id: 'swap-1',
          keyIndex: 0,
          type: core.SwapType.bitcoinToLightning,
          status: status,
          environment: Environment.mainnet,
          creationTime: _now,
          sendWalletId: 'wallet-1',
          invoice: 'invoice',
          paymentAddress: 'bc1payin',
          paymentAmount: 1000,
        )
        as core.LnSendSwap;

void main() {
  late _MockResolver resolver;
  late _MockProvider provider;
  late _MockBoltzRepo boltz;
  late BoltzOrderSwapBridge bridge;

  setUp(() {
    resolver = _MockResolver();
    provider = _MockProvider();
    boltz = _MockBoltzRepo();
    bridge = BoltzOrderSwapBridge(resolver, boltz, now: () => _now);
    when(() => resolver.resolveActive()).thenAnswer((_) async => provider);
  });

  group('createIfActive', () {
    test('returns null when the active provider is not Boltz', () async {
      when(() => provider.config).thenReturn(_bullConfig);

      final result = await bridge.createIfActive(
        record: _sendRecord(),
        amountSat: BigInt.from(1000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.lightning,
        destinationAddress: 'invoice',
        fallbackAddress: 'fallback',
      );

      expect(result, isNull);
    });

    test(
      'surfaces the typed SwapFailure instead of a stringly Exception',
      () async {
        when(() => provider.config).thenReturn(_boltzConfig);
        when(
          () => provider.createLnSend(
            fromNetwork: SwapNetwork.bitcoin,
            invoice: 'invoice',
            refundAddress: 'fallback',
            sourceWalletId: 'wallet-1',
            environment: SwapEnvironment.mainnet,
          ),
        ).thenAnswer((_) async => const Err(SwapNetworkFailure('boltz down')));

        expect(
          () => bridge.createIfActive(
            record: _sendRecord(),
            amountSat: BigInt.from(1000),
            isInAmountFixed: false,
            inNetwork: OrderSwapNetwork.bitcoin,
            outNetwork: OrderSwapNetwork.lightning,
            destinationAddress: 'invoice',
            fallbackAddress: 'fallback',
          ),
          throwsA(isA<SwapNetworkFailure>()),
        );
      },
    );
  });

  group('quoteIfActive', () {
    test('maps a provider SwapQuote to an OrderSwapQuote', () async {
      when(() => provider.config).thenReturn(_boltzConfig);
      when(
        () => provider.quote(
          inNetwork: SwapNetwork.bitcoin,
          outNetwork: SwapNetwork.lightning,
          amountSat: BigInt.from(100000),
          isInAmountFixed: true,
          environment: SwapEnvironment.mainnet,
        ),
      ).thenAnswer(
        (_) async => Ok(
          SwapQuote(
            providerId: 'boltz',
            inNetwork: SwapNetwork.bitcoin,
            outNetwork: SwapNetwork.lightning,
            payinAmountSat: BigInt.from(100000),
            payoutAmountSat: BigInt.from(99000),
            feesSat: BigInt.from(1000),
          ),
        ),
      );

      final quote = await bridge.quoteIfActive(
        environment: OrderSwapEnvironment.mainnet,
        amountSat: BigInt.from(100000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.lightning,
      );

      expect(quote, isNotNull);
      expect(quote!.inAmountSat, BigInt.from(100000));
      expect(quote.outAmountSat, BigInt.from(99000));
      expect(quote.inCurrency, 'BTC');
      expect(quote.outCurrency, 'LN-BTC');
      // 1000 / 100000 = 1% = 100 basis points.
      expect(quote.feeBasisPoints, 100);
    });

    test('returns null when the active provider is not Boltz', () async {
      when(() => provider.config).thenReturn(_bullConfig);

      final quote = await bridge.quoteIfActive(
        environment: OrderSwapEnvironment.mainnet,
        amountSat: BigInt.from(100000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.lightning,
      );

      expect(quote, isNull);
    });

    test('surfaces a typed failure from the provider quote', () async {
      when(() => provider.config).thenReturn(_boltzConfig);
      when(
        () => provider.quote(
          inNetwork: SwapNetwork.bitcoin,
          outNetwork: SwapNetwork.lightning,
          amountSat: BigInt.from(100000),
          isInAmountFixed: true,
          environment: SwapEnvironment.mainnet,
        ),
      ).thenAnswer((_) async => const Err(SwapNetworkFailure('down')));

      expect(
        () => bridge.quoteIfActive(
          environment: OrderSwapEnvironment.mainnet,
          amountSat: BigInt.from(100000),
          isInAmountFixed: true,
          inNetwork: OrderSwapNetwork.bitcoin,
          outNetwork: OrderSwapNetwork.lightning,
        ),
        throwsA(isA<SwapNetworkFailure>()),
      );
    });
  });

  group('refreshIfBoltz', () {
    test('persists the send preimage before cooperatively closing', () async {
      final swap = _lnSend(core.SwapStatus.canCoop);
      when(() => boltz.getSwap(swapId: 'swap-1')).thenAnswer((_) async => swap);
      when(
        () => boltz.getSendSwapPreimage(swapId: 'swap-1'),
      ).thenAnswer((_) async => 'the-preimage');
      when(
        () => boltz.updateSwapFields('swap-1', preimage: 'the-preimage'),
      ).thenAnswer((_) async => swap);
      when(
        () => boltz.coopSignBitcoinToLightningSwap(swapId: 'swap-1'),
      ).thenAnswer((_) async {});

      await bridge.refreshIfBoltz(_sendRecord(order: _sendOrder()));

      verify(
        () => boltz.updateSwapFields('swap-1', preimage: 'the-preimage'),
      ).called(1);
      verify(
        () => boltz.coopSignBitcoinToLightningSwap(swapId: 'swap-1'),
      ).called(1);
    });

    test('maps a completed boltz swap to a completed order', () async {
      final swap = _lnSend(core.SwapStatus.completed);
      when(() => boltz.getSwap(swapId: 'swap-1')).thenAnswer((_) async => swap);

      final order = await bridge.refreshIfBoltz(
        _sendRecord(order: _sendOrder()),
      );

      expect(order, isNotNull);
      expect(order!.orderStatus, 'completed');
      expect(order.payoutStatus, 'completed');
    });
  });
}
