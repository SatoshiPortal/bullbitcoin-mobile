import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/bump_fee_usecase.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/replace_by_fee_failure.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/manipulated_transaction_exception.dart';
import 'package:bb_mobile/core/wallet/domain/transaction_signature_status.dart';
import 'package:bb_mobile/core/wallet/domain/unverifiable_transaction_exception.dart';
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

  group('validateOriginalFee', () {
    test('unknown fee returns the typed localized failure', () {
      final result = usecase.validateOriginalFee(null);
      expect(result, isA<Err<int, ReplaceByFeeFailure>>());
      if (result case Err(:final failure)) {
        expect(failure, isA<ReplaceByFeeUnknownOriginalFeeFailure>());
      }
      verifyZeroInteractions(walletRepository);
      verifyZeroInteractions(broadcastUsecase);
      verifyZeroInteractions(getNetworkFeesUsecase);
    });

    for (final fee in [0, 200]) {
      test('known original fee $fee remains eligible', () {
        final result = usecase.validateOriginalFee(fee);
        expect(result, isA<Ok<int, ReplaceByFeeFailure>>());
        if (result case Ok(:final value)) {
          expect(value, fee);
        }
      });
    }
  });

  group('execute', () {
    test(
      'unknown original fee refuses replacement before any side effects',
      () async {
        final result = await usecase.execute(
          walletId: 'w1',
          txid: 'old-txid',
          newFeeRate: const RelativeFee(1250),
          originalFeeSat: null,
        );
        expect(result, isA<Err<String, ReplaceByFeeFailure>>());
        if (result case Err(:final failure)) {
          expect(failure, isA<ReplaceByFeeUnknownOriginalFeeFailure>());
        }
        verifyZeroInteractions(walletRepository);
        verifyZeroInteractions(broadcastUsecase);
        verifyZeroInteractions(getNetworkFeesUsecase);
      },
    );

    test('known zero original fee retains replacement and broadcast', () async {
      when(
        () => walletRepository.bumpFee(
          walletId: 'w1',
          txid: 'old-txid',
          newFeeRate: const RelativeFee(1250),
        ),
      ).thenAnswer((_) async => 'signed-psbt');
      when(
        () => broadcastUsecase.execute(
          'signed-psbt',
          isPsbt: true,
          walletId: 'w1',
        ),
      ).thenAnswer((_) async => 'new-txid');
      final result = await usecase.execute(
        walletId: 'w1',
        txid: 'old-txid',
        newFeeRate: const RelativeFee(1250),
        originalFeeSat: 0,
      );
      expect(result, isA<Ok<String, ReplaceByFeeFailure>>());
      if (result case Ok(:final value)) {
        expect(value, 'new-txid');
      }
      verify(
        () => walletRepository.bumpFee(
          walletId: 'w1',
          txid: 'old-txid',
          newFeeRate: const RelativeFee(1250),
        ),
      ).called(1);
      verify(
        () => broadcastUsecase.execute(
          'signed-psbt',
          isPsbt: true,
          walletId: 'w1',
        ),
      ).called(1);
    });

    test('returns Ok with txid on success', () async {
      when(
        () => walletRepository.bumpFee(
          walletId: any(named: 'walletId'),
          txid: any(named: 'txid'),
          newFeeRate: any(named: 'newFeeRate'),
        ),
      ).thenAnswer((_) async => 'signed-psbt');
      when(
        () => broadcastUsecase.execute(
          'signed-psbt',
          isPsbt: true,
          walletId: 'w1',
        ),
      ).thenAnswer((_) async => 'new-txid');

      final result = await usecase.execute(
        walletId: 'w1',
        txid: 'old-txid',
        originalFeeSat: 200,
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
          originalFeeSat: 200,
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
          originalFeeSat: 200,
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

    test(
      'returns Err(ReplaceByFeeManipulatedTransactionFailure) on ManipulatedTransactionException',
      () async {
        when(
          () => walletRepository.bumpFee(
            walletId: any(named: 'walletId'),
            txid: any(named: 'txid'),
            newFeeRate: any(named: 'newFeeRate'),
          ),
        ).thenThrow(ManipulatedTransactionException('forged tx'));

        final result = await usecase.execute(
          walletId: 'w1',
          txid: 'old-txid',
          originalFeeSat: 200,
          newFeeRate: const RelativeFee(1250),
        );

        expect(result, isA<Err<String, ReplaceByFeeFailure>>());
        expect(
          (result as Err).failure,
          isA<ReplaceByFeeManipulatedTransactionFailure>(),
        );
      },
    );

    test(
      'returns Err(ReplaceByFeeUnverifiableTransactionFailure) on UnverifiableTransactionException',
      () async {
        when(
          () => walletRepository.bumpFee(
            walletId: any(named: 'walletId'),
            txid: any(named: 'txid'),
            newFeeRate: any(named: 'newFeeRate'),
          ),
        ).thenThrow(UnverifiableTransactionException('prevouts missing'));

        final result = await usecase.execute(
          walletId: 'w1',
          txid: 'old-txid',
          originalFeeSat: 200,
          newFeeRate: const RelativeFee(1250),
        );

        expect(result, isA<Err<String, ReplaceByFeeFailure>>());
        expect(
          (result as Err).failure,
          isA<ReplaceByFeeUnverifiableTransactionFailure>(),
        );
      },
    );
  });

  group('verifyOriginalTransaction', () {
    test('returns Ok when the stored transaction signatures verify', () async {
      when(
        () => walletRepository.getTransactionSignatureStatus(
          walletId: any(named: 'walletId'),
          txid: any(named: 'txid'),
        ),
      ).thenAnswer((_) async => TransactionSignatureStatus.valid);

      final result = await usecase.verifyOriginalTransaction(
        walletId: 'w1',
        txid: 'old-txid',
      );

      expect(result, isA<Ok<void, ReplaceByFeeFailure>>());
    });

    test(
      'returns Err(ReplaceByFeeManipulatedTransactionFailure) when verification fails',
      () async {
        when(
          () => walletRepository.getTransactionSignatureStatus(
            walletId: any(named: 'walletId'),
            txid: any(named: 'txid'),
          ),
        ).thenAnswer((_) async => TransactionSignatureStatus.invalid);

        final result = await usecase.verifyOriginalTransaction(
          walletId: 'w1',
          txid: 'old-txid',
        );

        expect(result, isA<Err<void, ReplaceByFeeFailure>>());
        expect(
          (result as Err).failure,
          isA<ReplaceByFeeManipulatedTransactionFailure>(),
        );
      },
    );

    test(
      'returns Err(ReplaceByFeeUnverifiableTransactionFailure) when verification cannot run',
      () async {
        when(
          () => walletRepository.getTransactionSignatureStatus(
            walletId: any(named: 'walletId'),
            txid: any(named: 'txid'),
          ),
        ).thenAnswer((_) async => TransactionSignatureStatus.unverifiable);

        final result = await usecase.verifyOriginalTransaction(
          walletId: 'w1',
          txid: 'old-txid',
        );

        expect(result, isA<Err<void, ReplaceByFeeFailure>>());
        expect(
          (result as Err).failure,
          isA<ReplaceByFeeUnverifiableTransactionFailure>(),
        );
      },
    );

    test(
      'returns Err(ReplaceByFeeUnexpectedFailure) when verification throws — raw message in logMessage only',
      () async {
        when(
          () => walletRepository.getTransactionSignatureStatus(
            walletId: any(named: 'walletId'),
            txid: any(named: 'txid'),
          ),
        ).thenThrow(Exception('wallet metadata not found'));

        final result = await usecase.verifyOriginalTransaction(
          walletId: 'w1',
          txid: 'old-txid',
        );

        expect(result, isA<Err<void, ReplaceByFeeFailure>>());
        final failure = (result as Err).failure;
        expect(failure, isA<ReplaceByFeeUnexpectedFailure>());
        expect(
          (failure as ReplaceByFeeUnexpectedFailure).logMessage,
          contains('wallet metadata not found'),
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
