import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/bump_fee_usecase.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/fee_entity.dart';
import 'package:bb_mobile/features/replace_by_fee/errors.dart';
import 'package:bb_mobile/features/replace_by_fee/presentation/cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBumpFee extends Mock implements BumpFeeUsecase {}

class _MockBroadcast extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class _MockGetFees extends Mock implements GetNetworkFeesUsecase {}

WalletTransaction _tx() => const WalletTransaction(
  walletId: 'w1',
  network: Network.bitcoinMainnet,
  direction: WalletTransactionDirection.outgoing,
  status: WalletTransactionStatus.pending,
  txId: 'abc',
  amountSat: 100000,
  feeSat: 200,
  vsize: 140,
  inputs: [],
  outputs: [],
  isRbf: true,
);

FeeOptions _fees() => const FeeOptions(
  fastest: RelativeFee(2000), // 8 sat/vB
  economic: RelativeFee(500),
  slow: RelativeFee(250),
  minRelay: RelativeFee(25), // 0.1 sat/vB
);

void main() {
  setUpAll(() {
    registerFallbackValue(const RelativeFee(250));
  });

  late _MockBumpFee bumpFee;
  late _MockBroadcast broadcast;
  late _MockGetFees getFees;

  Future<ReplaceByFeeCubit> buildCubit() async {
    when(
      () => getFees.execute(isLiquid: false),
    ).thenAnswer((_) async => _fees());
    final cubit = ReplaceByFeeCubit(
      originalTransaction: _tx(),
      bumpFeeUsecase: bumpFee,
      broadcastBitcoinTransactionUsecase: broadcast,
      getNetworkFeesUsecase: getFees,
    );
    // init() is async in the constructor — let it settle.
    await Future<void>.delayed(Duration.zero);
    return cubit;
  }

  setUp(() {
    bumpFee = _MockBumpFee();
    broadcast = _MockBroadcast();
    getFees = _MockGetFees();
  });

  group('ReplaceByFeeCubit — below-floor selection gate', () {
    test('broadcast refuses while the custom field is below floor', () async {
      final cubit = await buildCubit();
      // newFeeRate is seeded above floor by init(); the user then types a
      // sub-floor rate, which the widget reports via markCustomFeeBelowFloor.
      cubit.markCustomFeeBelowFloor();

      await cubit.broadcast();

      expect(cubit.state.error, isA<FeeRateTooLowError>());
      verifyNever(
        () => bumpFee.execute(
          walletId: any(named: 'walletId'),
          txid: any(named: 'txid'),
          newFeeRate: any(named: 'newFeeRate'),
        ),
      );
    });

    test('a valid selection clears the flag and broadcast proceeds', () async {
      final cubit = await buildCubit();
      cubit.markCustomFeeBelowFloor();
      // Re-typing a valid above-floor rate (or tapping Fastest) re-commits.
      cubit.onChangeFee(
        const FeeEntity(type: FeeType.custom, feeRate: RelativeFee(500)),
      );
      expect(cubit.state.customFeeBelowFloor, isFalse);

      when(
        () => bumpFee.execute(
          walletId: any(named: 'walletId'),
          txid: any(named: 'txid'),
          newFeeRate: any(named: 'newFeeRate'),
        ),
      ).thenAnswer((_) async => 'psbt');
      when(
        () => broadcast.execute(any(), isPsbt: any(named: 'isPsbt')),
      ).thenAnswer((_) async => 'txid-1');

      await cubit.broadcast();

      expect(cubit.state.txid, 'txid-1');
      expect(cubit.state.error, isNull);
    });
  });
}
