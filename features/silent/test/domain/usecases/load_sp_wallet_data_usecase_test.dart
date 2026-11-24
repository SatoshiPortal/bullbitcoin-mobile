import 'package:silent/src/domain/entities/sp_coin.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_payment.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:silent/src/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_fakes.dart';

import 'package:silent/src/domain/entities/sp_wallet_data.dart';

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
          confirmedSat: Sats.zero,
          totalUnifiedSat: Sats.fromInt(700),
        );
        final history = [
          SpPayment(
            txid: 'a',
            direction: SpPaymentDirection.receive,
            status: SpPaymentStatus.unconfirmed,
            amountSat: Sats.fromInt(5),
          ),
        ];
        const coins = <SpCoin>[];
        when(() => ensureSpSessionUsecase.execute())
            .thenAnswer((_) async => Ok(wallet));
        when(
          () => repository.history(),
        ).thenAnswer((_) async => Ok<List<SpPayment>, SilentFailure>(history));
        when(
          () => repository.coins(),
        ).thenAnswer((_) async => const Ok<List<SpCoin>, SilentFailure>(coins));
        when(() => repository.network()).thenReturn(Ok(BitcoinNetwork.mainnet));
        when(() => repository.chainTip()).thenReturn(101);
        when(() => repository.minBirthdayHeight()).thenReturn(const Ok(42));

        final result = await usecase.execute();

        expect(result, isA<Ok<SpWalletData, SilentFailure>>());
        final data = (result as Ok).value as SpWalletData;
        expect(data.wallet, same(wallet));
        // The repository already flagged each payment, so it passes through.
        expect(data.history.single.txid, history.single.txid);
        expect(data.history.single.network, BitcoinNetwork.mainnet);
        expect(data.coins, same(coins));
        expect(data.network, BitcoinNetwork.mainnet);
        expect(data.chainTip, 101);
        expect(data.minBirthdayHeight, 42);
        verify(() => repository.notifyBalanceChanged(Sats.fromInt(700)))
            .called(1);
      },
    );

    test('returns SilentNotSetUp when the session is unavailable', () async {
      when(() => ensureSpSessionUsecase.execute())
          .thenAnswer((_) async => const Ok(null));

      final result = await usecase.execute();

      expect((result as Err).failure, isA<SilentNotSetUp>());
      verifyNever(() => repository.history());
      verifyNever(() => repository.coins());
    });

    test('short-circuits with the history failure unchanged', () async {
      const failure = SilentBackendUnreachable('blindbit down');
      when(() => ensureSpSessionUsecase.execute())
          .thenAnswer((_) async => Ok(spWallet()));
      when(() => repository.history()).thenAnswer(
        (_) async => const Err<List<SpPayment>, SilentFailure>(failure),
      );
      when(() => repository.coins())
          .thenAnswer((_) async => const Ok<List<SpCoin>, SilentFailure>([]));
      when(() => repository.network()).thenReturn(const Ok(null));
      when(() => repository.minBirthdayHeight()).thenReturn(const Ok(0));

      final result = await usecase.execute();

      expect((result as Err).failure, same(failure));
    });

    test('short-circuits with the coins failure unchanged', () async {
      const failure = SilentConfigInvalid('corrupt coin store');
      when(() => ensureSpSessionUsecase.execute())
          .thenAnswer((_) async => Ok(spWallet()));
      when(
        () => repository.history(),
      ).thenAnswer((_) async => const Ok<List<SpPayment>, SilentFailure>([]));
      when(() => repository.coins()).thenAnswer(
        (_) async => const Err<List<SpCoin>, SilentFailure>(failure),
      );
      when(() => repository.network()).thenReturn(const Ok(null));
      when(() => repository.minBirthdayHeight()).thenReturn(const Ok(0));

      final result = await usecase.execute();

      expect((result as Err).failure, same(failure));
    });

    test('short-circuits with the min birthday failure unchanged', () async {
      const failure = SilentNotSetUp('no live session');
      when(() => ensureSpSessionUsecase.execute())
          .thenAnswer((_) async => Ok(spWallet()));
      when(
        () => repository.history(),
      ).thenAnswer((_) async => const Ok<List<SpPayment>, SilentFailure>([]));
      when(() => repository.coins())
          .thenAnswer((_) async => const Ok<List<SpCoin>, SilentFailure>([]));
      when(() => repository.network()).thenReturn(const Ok(null));
      when(() => repository.minBirthdayHeight())
          .thenReturn(const Err<int, SilentFailure>(failure));

      final result = await usecase.execute();

      expect((result as Err).failure, same(failure));
    });

    test('maps an unexpected throw to SilentUnexpected', () async {
      when(() => ensureSpSessionUsecase.execute())
          .thenThrow(Exception('session boom'));

      final result = await usecase.execute();

      final failure = (result as Err).failure;
      expect(failure, isA<SilentUnexpected>());
      expect(failure.logMessage, contains('SP wallet data load failed'));
    });
  });
}
