import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' as app;
import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/bump_fee_usecase.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/replace_by_fee_failure.dart';
import 'package:sync/sync.dart'
    show
        BitcoinSpendStatus,
        SignatureCheck,
        SyncBusyFailure,
        SyncFailure,
        SyncFeeRateTooLowFailure,
        SyncOriginalSignaturesFailure,
        SyncSpendBlockedFailure,
        UnsignedSpend,
        WalletKey,
        WalletRevision;
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/wallet/data/bitcoin_wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBitcoinWalletRepository extends Mock
    implements BitcoinWalletRepository {}

class MockBroadcastBitcoinTransactionUsecase extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class MockFees extends Mock implements Fees {}

class _MockPreferences extends Mock implements Preferences {}

void main() {
  setUpAll(() {
    registerFallbackValue(const RelativeFee(250));
  });

  late MockBitcoinWalletRepository walletRepository;
  late MockBroadcastBitcoinTransactionUsecase broadcastUsecase;
  late MockFees feeEstimates;
  late BumpFeeUsecase usecase;

  setUp(() {
    walletRepository = MockBitcoinWalletRepository();
    broadcastUsecase = MockBroadcastBitcoinTransactionUsecase();
    feeEstimates = MockFees();
    final preferences = _MockPreferences();
    when(preferences.fetch).thenAnswer(
      (_) async => const Ok(
        SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    usecase = BumpFeeUsecase(
      bitcoinWalletRepository: walletRepository,
      broadcastBitcoinTransactionUsecase: broadcastUsecase,
      fees: feeEstimates,
      preferences: preferences,
    );
  });

  group('execute', () {
    final unsigned = UnsignedSpend(
      revision: WalletRevision(
        key: WalletKey(id: 'w1', network: BitcoinNetwork.mainnet),
        generation: 1,
        revision: 3,
      ),
      encoded: 'unsigned-psbt',
      inputs: const [],
      replacing: 'old-txid',
    );

    void bumpAnswers(Result<UnsignedSpend, SyncFailure> built) => when(
      () => walletRepository.bumpFee(
        walletId: any(named: 'walletId'),
        txid: any(named: 'txid'),
        newFeeRate: any(named: 'newFeeRate'),
      ),
    ).thenAnswer((_) async => built);

    Future<Result<String, ReplaceByFeeFailure>> bump() => usecase.execute(
      walletId: 'w1',
      txid: 'old-txid',
      newFeeRate: const RelativeFee(1250),
      network: app.Network.bitcoinMainnet,
    );

    test('builds in sync, signs, then broadcasts what was built', () async {
      bumpAnswers(Ok(unsigned));
      when(() => walletRepository.signPsbt('unsigned-psbt', walletId: 'w1'))
          .thenAnswer((_) async => 'signed-psbt');
      when(
        () => broadcastUsecase.execute(
          'signed-psbt',
          isPsbt: true,
          network: app.Network.bitcoinMainnet,
          walletId: 'w1',
          built: unsigned,
        ),
      ).thenAnswer((_) async => 'new-txid');

      final result = await bump();

      expect((result as Ok<String, ReplaceByFeeFailure>).value, 'new-txid');
    });

    for (final (failure, matcher) in <(SyncFailure, Matcher)>[
      (
        const SyncFeeRateTooLowFailure(),
        isA<ReplaceByFeeFeeRateTooLowFailure>(),
      ),
      (
        const SyncOriginalSignaturesFailure(SignatureCheck.invalid),
        isA<ReplaceByFeeManipulatedTransactionFailure>(),
      ),
      (
        const SyncOriginalSignaturesFailure(SignatureCheck.unverifiable),
        isA<ReplaceByFeeUnverifiableTransactionFailure>(),
      ),
      (
        const SyncSpendBlockedFailure(BitcoinSpendStatus.replacementPending),
        isA<ReplaceByFeeSpendBlockedFailure>().having(
          (failure) => failure.replacementPending,
          'replacementPending',
          isTrue,
        ),
      ),
      (
        const SyncBusyFailure(),
        isA<ReplaceByFeeSpendBlockedFailure>().having(
          (failure) => failure.busy,
          'busy',
          isTrue,
        ),
      ),
    ]) {
      test('maps ${failure.logCode} and signs nothing', () async {
        bumpAnswers(Err(failure));

        expect((await bump() as Err).failure, matcher);
        verifyNever(
          () => walletRepository.signPsbt(
            any(),
            walletId: any(named: 'walletId'),
          ),
        );
      });
    }

    test('returns Err(ReplaceByFeeUnexpectedFailure) on unexpected exception — raw message in logMessage only', () async {
      when(
        () => walletRepository.bumpFee(
          walletId: any(named: 'walletId'),
          txid: any(named: 'txid'),
          newFeeRate: any(named: 'newFeeRate'),
        ),
      ).thenThrow(Exception('internal sync error'));

      final failure = (await bump() as Err).failure;
      expect(failure, isA<ReplaceByFeeUnexpectedFailure>());
      expect(
        (failure as ReplaceByFeeUnexpectedFailure).logMessage,
        contains('internal sync error'),
      );
    });
  });

  group('verifyOriginalTransaction', () {
    test('returns Ok when the stored transaction signatures verify', () async {
      when(
        () => walletRepository.getTransactionSignatureStatus(
          walletId: any(named: 'walletId'),
          txid: any(named: 'txid'),
        ),
      ).thenAnswer((_) async => SignatureCheck.valid);

      final result = await usecase.verifyOriginalTransaction(
        walletId: 'w1',
        txid: 'old-txid',
      );

      expect(result, isA<Ok<void, ReplaceByFeeFailure>>());
    });

    test('returns Err(ReplaceByFeeManipulatedTransactionFailure) when verification fails', () async {
      when(
        () => walletRepository.getTransactionSignatureStatus(
          walletId: any(named: 'walletId'),
          txid: any(named: 'txid'),
        ),
      ).thenAnswer((_) async => SignatureCheck.invalid);

      final result = await usecase.verifyOriginalTransaction(
        walletId: 'w1',
        txid: 'old-txid',
      );

      expect(result, isA<Err<void, ReplaceByFeeFailure>>());
      expect(
        (result as Err).failure,
        isA<ReplaceByFeeManipulatedTransactionFailure>(),
      );
    });

    test('returns Err(ReplaceByFeeUnverifiableTransactionFailure) when verification cannot run', () async {
      when(
        () => walletRepository.getTransactionSignatureStatus(
          walletId: any(named: 'walletId'),
          txid: any(named: 'txid'),
        ),
      ).thenAnswer((_) async => SignatureCheck.unverifiable);

      final result = await usecase.verifyOriginalTransaction(
        walletId: 'w1',
        txid: 'old-txid',
      );

      expect(result, isA<Err<void, ReplaceByFeeFailure>>());
      expect(
        (result as Err).failure,
        isA<ReplaceByFeeUnverifiableTransactionFailure>(),
      );
    });

    test('returns Err(ReplaceByFeeUnexpectedFailure) when verification throws — raw message in logMessage only', () async {
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
    });
  });

  group('getNetworkFees', () {
    test('returns Ok with FeeOptions on success', () async {
      const feeOptions = FeeOptions(
        fastest: NetworkFee.relativeSatPerKwu(10),
        economic: NetworkFee.relativeSatPerKwu(5),
        slow: NetworkFee.relativeSatPerKwu(1),
        minRelay: RelativeFee(25),
      );
      when(() => feeEstimates.estimate(BitcoinNetwork.testnet))
          .thenAnswer((_) async => const Ok(feeOptions));

      final result = await usecase.getNetworkFees();

      expect(result, isA<Ok<FeeOptions, ReplaceByFeeFailure>>());
    });

    test('returns Err(ReplaceByFeeNetworkFeesFailure) when the estimate is unavailable', () async {
      when(() => feeEstimates.estimate(BitcoinNetwork.testnet))
          .thenAnswer((_) async => const Err(FeeEstimateUnavailableFailure()));

      final result = await usecase.getNetworkFees();

      expect(result, isA<Err<FeeOptions, ReplaceByFeeFailure>>());
      expect((result as Err).failure, isA<ReplaceByFeeNetworkFeesFailure>());
    });
  });
}
