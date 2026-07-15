import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_fakes.dart';

class _MockEnsureSpSessionUsecase extends Mock
    implements EnsureSpSessionUsecase {}

void main() {
  late MockSpAccountRepository repository;
  late _MockEnsureSpSessionUsecase ensureSpSessionUsecase;
  late LoadSpWalletDataUsecase usecase;

  setUp(() {
    repository = MockSpAccountRepository();
    ensureSpSessionUsecase = _MockEnsureSpSessionUsecase();
    usecase = LoadSpWalletDataUsecase(
      repository: repository,
      ensureSpSessionUsecase: ensureSpSessionUsecase,
    );
  });

  group('LoadSpWalletDataUsecase', () {
    test(
      'assembles the wallet data when the session and reads succeed',
      () async {
        final wallet = spWallet(
          confirmedSat: BigInt.zero,
          totalUnifiedSat: BigInt.from(700),
        );
        final history = [
          SpPayment(
            txid: 'a',
            direction: SpPaymentDirection.receive,
            status: SpPaymentStatus.unconfirmed,
            amountSat: BigInt.from(5),
          ),
        ];
        const coins = <SpCoin>[];
        when(
          () => ensureSpSessionUsecase.execute(),
        ).thenAnswer((_) async => wallet);
        when(
          () => repository.history(),
        ).thenAnswer((_) async => Ok<List<SpPayment>, SpFailure>(history));
        when(
          () => repository.coins(),
        ).thenAnswer((_) async => const Ok<List<SpCoin>, SpFailure>(coins));
        when(() => repository.network()).thenReturn(SpNetwork.regtest);
        when(() => repository.backendOnline()).thenReturn(true);
        when(() => repository.chainTip()).thenReturn(101);
        when(() => repository.minBirthdayHeight()).thenReturn(42);

        final result = await usecase.execute();

        expect(result, isA<Ok<SpWalletData, SpFailure>>());
        final data = (result as Ok).value as SpWalletData;
        expect(data.wallet, same(wallet));
        expect(data.history, same(history));
        expect(data.coins, same(coins));
        expect(data.network, SpNetwork.regtest);
        expect(data.backendOnline, isTrue);
        expect(data.chainTip, 101);
        expect(data.minBirthdayHeight, 42);
        verify(
          () => repository.notifyBalanceChanged(BigInt.from(700)),
        ).called(1);
      },
    );

    test('returns SpNotSetUp when the session is unavailable', () async {
      when(
        () => ensureSpSessionUsecase.execute(),
      ).thenAnswer((_) async => null);

      final result = await usecase.execute();

      expect((result as Err).failure, isA<SpNotSetUp>());
      verifyNever(() => repository.history());
      verifyNever(() => repository.coins());
    });

    test('short-circuits with the history failure unchanged', () async {
      const failure = SpBackendUnreachable('blindbit down');
      when(
        () => ensureSpSessionUsecase.execute(),
      ).thenAnswer((_) async => spWallet());
      when(
        () => repository.history(),
      ).thenAnswer((_) async => const Err<List<SpPayment>, SpFailure>(failure));
      when(
        () => repository.coins(),
      ).thenAnswer((_) async => const Ok<List<SpCoin>, SpFailure>([]));

      final result = await usecase.execute();

      expect((result as Err).failure, same(failure));
    });

    test('short-circuits with the coins failure unchanged', () async {
      const failure = SpConfigInvalid('corrupt coin store');
      when(
        () => ensureSpSessionUsecase.execute(),
      ).thenAnswer((_) async => spWallet());
      when(
        () => repository.history(),
      ).thenAnswer((_) async => const Ok<List<SpPayment>, SpFailure>([]));
      when(
        () => repository.coins(),
      ).thenAnswer((_) async => const Err<List<SpCoin>, SpFailure>(failure));

      final result = await usecase.execute();

      expect((result as Err).failure, same(failure));
    });

    test('maps an unexpected throw to SpUnexpected', () async {
      when(
        () => ensureSpSessionUsecase.execute(),
      ).thenThrow(Exception('session boom'));

      final result = await usecase.execute();

      final failure = (result as Err).failure;
      expect(failure, isA<SpUnexpected>());
      expect(failure.logMessage, contains('SP wallet data load failed'));
    });
  });
}
