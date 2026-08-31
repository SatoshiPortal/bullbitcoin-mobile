import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart' as core;
import 'package:bb_mobile/features/swap/providers/swap_pending_probe.dart';
import 'package:bull_swap/bull_swap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockOrders extends Mock implements OrderSwapRepository {}

class _MockBoltz extends Mock implements BoltzSwapRepository {}

OrderSwapRecord _record() => OrderSwapRecord(
  localId: 'local-1',
  purpose: OrderSwapPurpose.transfer,
  environment: OrderSwapEnvironment.mainnet,
  inNetwork: OrderSwapNetwork.bitcoin,
  outNetwork: OrderSwapNetwork.liquid,
  isInAmountFixed: false,
  requestedAmountSat: BigInt.from(1000),
  destination: 'dest',
  fallback: 'fallback',
  createdAt: DateTime.utc(2026),
  localStatus: OrderSwapLocalStatus.creating,
);

core.Swap _ongoingSwap() => core.Swap.lnSend(
  id: 'swap-1',
  keyIndex: 0,
  type: core.SwapType.bitcoinToLightning,
  status: core.SwapStatus.pending,
  environment: Environment.mainnet,
  creationTime: DateTime.utc(2026),
  sendWalletId: 'wallet-1',
  invoice: 'invoice',
  paymentAddress: 'bc1payin',
  paymentAmount: 1000,
);

void main() {
  late _MockOrders orders;
  late _MockBoltz boltz;
  late SwapPendingProbe probe;

  setUp(() {
    orders = _MockOrders();
    boltz = _MockBoltz();
    probe = SwapPendingProbe(orders, boltz);
  });

  test('reports active when an order swap is pending', () async {
    when(
      () => orders.getPendingOrders(),
    ).thenAnswer((_) async => Ok([_record()]));

    expect(await probe.hasActiveSwaps(), isTrue);
    verifyNever(() => boltz.getOngoingSwaps());
  });

  test(
    'falls back to Boltz ongoing swaps when no orders are pending',
    () async {
      when(
        () => orders.getPendingOrders(),
      ).thenAnswer((_) async => const Ok([]));
      when(
        () => boltz.getOngoingSwaps(),
      ).thenAnswer((_) async => [_ongoingSwap()]);

      expect(await probe.hasActiveSwaps(), isTrue);
    },
  );

  test('reports inactive when neither source has swaps', () async {
    when(() => orders.getPendingOrders()).thenAnswer((_) async => const Ok([]));
    when(() => boltz.getOngoingSwaps()).thenAnswer((_) async => []);

    expect(await probe.hasActiveSwaps(), isFalse);
  });

  test(
    'treats an orders failure as no pending orders and checks Boltz',
    () async {
      when(
        () => orders.getPendingOrders(),
      ).thenAnswer((_) async => const Err(SwapStorageFailure('boom')));
      when(() => boltz.getOngoingSwaps()).thenAnswer((_) async => []);

      expect(await probe.hasActiveSwaps(), isFalse);
      verify(() => boltz.getOngoingSwaps()).called(1);
    },
  );
}
