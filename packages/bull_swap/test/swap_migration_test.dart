import 'package:bull_swap/bull_swap.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

class _FakeLegacySource implements SwapLegacyDataPort {
  final List<SwapsCompanion> swaps;
  final List<AutoSwapCompanion> autoSwaps;
  final List<OrderSwapsCompanion> orderSwaps;
  int readSwapsCalls = 0;

  _FakeLegacySource({
    this.swaps = const [],
    this.autoSwaps = const [],
    this.orderSwaps = const [],
  });

  @override
  Future<List<SwapsCompanion>> readSwaps() async {
    readSwapsCalls++;
    return swaps;
  }

  @override
  Future<List<AutoSwapCompanion>> readAutoSwaps() async => autoSwaps;

  @override
  Future<List<OrderSwapsCompanion>> readOrderSwaps() async => orderSwaps;
}

void main() {
  late SwapDatabase db;

  setUp(() => db = SwapDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  OrderSwapsCompanion order(String localId) => OrderSwapsCompanion.insert(
    localId: localId,
    purpose: 'transfer',
    environment: 'mainnet',
    inNetwork: 'bitcoin',
    outNetwork: 'liquid',
    isInAmountFixed: true,
    requestedAmountSat: 1000,
    destination: 'lq1dest',
    fallback: 'bc1fallback',
    createdAt: DateTime.utc(2026),
    localStatus: 'creating',
    providerId: const Value('bull'),
  );

  SwapsCompanion boltz(String id) => SwapsCompanion.insert(
    id: id,
    type: 'lightningToBitcoin',
    direction: SwapDirection.receive,
    status: 'pending',
    isTestnet: false,
    keyIndex: 1,
    creationTime: 0,
    providerId: const Value('boltz'),
  );

  test('imports legacy swaps and order swaps once', () async {
    final source = _FakeLegacySource(
      swaps: [boltz('boltzswap001')],
      orderSwaps: [order('local-1')],
      autoSwaps: [
        AutoSwapCompanion.insert(
          balanceThresholdSats: 100000,
          triggerBalanceSats: 200000,
          feeThresholdPercent: 0.5,
        ),
      ],
    );

    await importLegacySwapData(db, source, now: () => 1);

    expect((await db.select(db.orderSwaps).get()).single.localId, 'local-1');
    expect((await db.select(db.swaps).get()).single.providerId, 'boltz');
    expect((await db.select(db.orderSwaps).get()).single.providerId, 'bull');
    expect((await db.select(db.autoSwap).get()).length, 1);
  });

  test('is idempotent — a second run does not re-read or duplicate', () async {
    final source = _FakeLegacySource(orderSwaps: [order('local-1')]);

    await importLegacySwapData(db, source, now: () => 1);
    await importLegacySwapData(db, source, now: () => 2);

    expect((await db.select(db.orderSwaps).get()).length, 1);
    expect(source.readSwapsCalls, 1);
  });
}
