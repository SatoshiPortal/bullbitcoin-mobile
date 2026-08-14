import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/bump_fee_usecase.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/replace_by_fee_failure.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBitcoinWalletRepository extends Mock
    implements BitcoinWalletRepository {}

class MockBroadcastBitcoinTransactionUsecase extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class MockGetNetworkFeesUsecase extends Mock implements GetNetworkFeesUsecase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const RelativeFee(250));
  });

  late MockBitcoinWalletRepository walletRepository;
  late MockBroadcastBitcoinTransactionUsecase broadcastUsecase;
  late MockGetNetworkFeesUsecase getNetworkFeesUsecase;
  late BumpFeeUsecase usecase;

  setUp(() {
    walletRepository = MockBitcoinWalletRepository();
    broadcastUsecase = MockBroadcastBitcoinTransactionUsecase();
    getNetworkFeesUsecase = MockGetNetworkFeesUsecase();
    usecase = BumpFeeUsecase(
      bitcoinWalletRepository: walletRepository,
      broadcastBitcoinTransactionUsecase: broadcastUsecase,
      getNetworkFeesUsecase: getNetworkFeesUsecase,
    );
  });

  group('execute', () {
    test('returns Ok with txid on success', () async {
      when(
        () => walletRepository.bumpFee(
          walletId: any(named: 'walletId'),
          txid: any(named: 'txid'),
          newFeeRate: any(named: 'newFeeRate'),
        ),
      ).thenAnswer((_) async => 'signed-psbt');
      when(
        () => broadcastUsecase.execute('signed-psbt', isPsbt: true),
      ).thenAnswer((_) async => 'new-txid');

      final result = await usecase.execute(
        walletId: 'w1',
        txid: 'old-txid',
        newFeeRate: const RelativeFee(1250),
      );

      expect(result, isA<Ok<String, ReplaceByFeeFailure>>());
      expect((result as Ok).value, 'new-txid');
    });

    test(
      'returns Err(ReplaceByFeeFeeRateTooLowFailure) on FeeRateTooLowCreateTxException — no raw leak',
      () async {
        when(
          () => walletRepository.bumpFee(
            walletId: any(named: 'walletId'),
            txid: any(named: 'txid'),
            newFeeRate: any(named: 'newFeeRate'),
          ),
        ).thenThrow(bdk.FeeRateTooLowCreateTxException('fee too low'));

        final result = await usecase.execute(
          walletId: 'w1',
          txid: 'old-txid',
          newFeeRate: const RelativeFee(250),
        );

        expect(result, isA<Err<String, ReplaceByFeeFailure>>());
        expect(
          (result as Err).failure,
          isA<ReplaceByFeeFeeRateTooLowFailure>(),
        );
      },
    );

    test(
      'returns Err(ReplaceByFeeUnexpectedFailure) on unexpected exception — raw message in logMessage only',
      () async {
        when(
          () => walletRepository.bumpFee(
            walletId: any(named: 'walletId'),
            txid: any(named: 'txid'),
            newFeeRate: any(named: 'newFeeRate'),
          ),
        ).thenThrow(Exception('internal bdk error'));

        final result = await usecase.execute(
          walletId: 'w1',
          txid: 'old-txid',
          newFeeRate: const RelativeFee(1250),
        );

        expect(result, isA<Err<String, ReplaceByFeeFailure>>());
        final failure = (result as Err).failure;
        expect(failure, isA<ReplaceByFeeUnexpectedFailure>());
        // Raw reason is in logMessage (logs only), not surfaced as a typed variant
        expect(
          (failure as ReplaceByFeeUnexpectedFailure).logMessage,
          contains('internal bdk error'),
        );
      },
    );
  });

  group('getNetworkFees', () {
    test('returns Ok with FeeOptions on success', () async {
      const feeOptions = FeeOptions(
        fastest: NetworkFee.relativeSatPerKwu(10),
        economic: NetworkFee.relativeSatPerKwu(5),
        slow: NetworkFee.relativeSatPerKwu(1),
        minRelay: RelativeFee(25),
      );
      when(
        () => getNetworkFeesUsecase.execute(isLiquid: false),
      ).thenAnswer((_) async => feeOptions);

      final result = await usecase.getNetworkFees();

      expect(result, isA<Ok<FeeOptions, ReplaceByFeeFailure>>());
    });

    test(
      'returns Err(ReplaceByFeeNetworkFeesFailure) on exception — no raw leak',
      () async {
        when(
          () => getNetworkFeesUsecase.execute(isLiquid: false),
        ).thenThrow(Exception('network unavailable'));

        final result = await usecase.getNetworkFees();

        expect(result, isA<Err<FeeOptions, ReplaceByFeeFailure>>());
        expect((result as Err).failure, isA<ReplaceByFeeNetworkFeesFailure>());
      },
    );
  });
}
