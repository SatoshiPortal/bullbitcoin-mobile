import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart' show ArkUnlimitedStageBudget;
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/ark_exit_funding.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/ark_reserve_top_up_port.dart';
import 'package:bull_ark/src/domain/usecases/fund_ark_exit_fees_usecase.dart';
import 'package:bull_ark/src/domain/usecases/fund_ark_exit_start_usecase.dart';
import 'package:bull_ark/src/domain/usecases/run_ark_exits_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'ark_operations_test.dart' show account;
import 'fake_ark_client.dart';

const reserve = 'bcrt1qpublicreservefixture';

final class _TopUp implements ArkReserveTopUpPort {
  final sent = <(String, Sats)>[];
  Result<String, ArkFailure> result = const Ok('top-up-txid');

  @override
  Future<Result<String, ArkFailure>> topUp(
    ArkAccountId account, {
    required String address,
    required Sats amount,
  }) async {
    sent.add((address, amount));
    return result;
  }
}

ArkExitAwaitingFeesFailure short(int missing, [int incoming = 0]) =>
    ArkExitAwaitingFeesFailure(
      missing: Sats.fromInt(missing),
      incoming: Sats.fromInt(incoming),
    );

void main() {
  late _TopUp port;
  late ArkExitFunding funding;
  var now = DateTime.utc(2026, 11, 23, 12);
  FundArkExitFeesUsecase usecase() =>
      FundArkExitFeesUsecase(port, funding, now: () => now);

  setUp(() {
    port = _TopUp();
    funding = ArkExitFunding();
    now = DateTime.utc(2026, 11, 23, 12);
  });

  group('funding a waiting exit from Secure Bitcoin', () {
    test(
      'sends what the reserve lacks, never below a spendable coin',
      () async {
        expect(
          await usecase().execute(
            account(),
            reserveAddress: reserve,
            short: short(4000),
          ),
          isA<Ok<void, ArkFailure>>(),
        );
        expect(port.sent, [(reserve, Sats.fromInt(4000))]);
        expect(funding.needed, isNull);

        now = now.add(FundArkExitFeesUsecase.settling);
        await usecase().execute(
          account(),
          reserveAddress: reserve,
          short: short(10),
        );
        expect(port.sent.last, (reserve, Sats.fromInt(1000)));
      },
    );

    test('counts what is already on its way', () async {
      await usecase().execute(
        account(),
        reserveAddress: reserve,
        short: short(4000, 4000),
      );
      expect(port.sent, isEmpty);
      await usecase().execute(
        account(),
        reserveAddress: reserve,
        short: short(4000, 1500),
      );
      expect(port.sent, [(reserve, Sats.fromInt(2500))]);
    });

    test('never sends twice while a top-up may still be showing up', () async {
      await usecase().execute(
        account(),
        reserveAddress: reserve,
        short: short(4000),
      );
      now = now.add(const Duration(minutes: 1));
      await usecase().execute(
        account(),
        reserveAddress: reserve,
        short: short(4000),
      );
      expect(port.sent, hasLength(1));
    });

    test('an uncertain send also blocks a second one', () async {
      port.result = const Err(ArkSubmissionUncertainFailure('reserve-top-up'));
      expect(
        await usecase().execute(
          account(),
          reserveAddress: reserve,
          short: short(4000),
        ),
        isA<Err<void, ArkFailure>>(),
      );
      await usecase().execute(
        account(),
        reserveAddress: reserve,
        short: short(4000),
      );
      expect(port.sent, hasLength(1));
    });

    test(
      'an empty Secure Bitcoin makes the exit wait, saying how much',
      () async {
        port.result = const Err(ArkPaymentInsufficientFundsFailure());
        final changes = <void>[];
        funding.changes.listen(changes.add);
        expect(
          await usecase().execute(
            account(),
            reserveAddress: reserve,
            short: short(4000),
          ),
          isA<Ok<void, ArkFailure>>(),
        );
        expect(funding.needed, Sats.fromInt(4000));
        // Not marked as sent: the next pass tries again.
        await usecase().execute(
          account(),
          reserveAddress: reserve,
          short: short(4000),
        );
        expect(port.sent, hasLength(2));
        await pumpEventQueue();
        expect(changes, hasLength(1));
      },
    );

    test('without the reserve address nothing is sent', () async {
      expect(
        await usecase().execute(
          account(),
          reserveAddress: null,
          short: short(4000),
        ),
        isA<Err<void, ArkFailure>>(),
      );
      expect(port.sent, isEmpty);
    });
  });

  group('moving exits forward', () {
    late FakeArkClient client;
    ProgressArkExitsUsecase progress() => ProgressArkExitsUsecase(
      ArkRepositoryImpl(client),
      const ArkUnlimitedStageBudget(),
      topUp: port,
      funding: funding,
    );

    setUp(() {
      client = FakeArkClient()
        ..snapshot = Ok(
          ArkSnapshot(
            account: account(),
            revision: 1,
            observedAt: DateTime.utc(2026),
            reserveAddress: reserve,
          ),
        );
    });

    test('a short reserve is funded and the exit waits, not fails', () async {
      client.progressed = Err(
        ArkExitFeesShortFailure(
          missing: Sats.fromInt(3000),
          incoming: Sats.zero,
        ),
      );
      expect(
        await progress().execute(account()),
        const Ok<ArkOperation?, ArkFailure>(null),
      );
      expect(port.sent, [(reserve, Sats.fromInt(3000))]);
    });

    test('progress clears what the screens show as missing', () async {
      funding.waitFor(Sats.fromInt(3000));
      client.progressed = const Ok(null);
      await progress().execute(account());
      expect(funding.needed, isNull);
    });

    test('another failure is reported and funds nothing', () async {
      client.progressed = const Err(ArkStorageFailure());
      expect(
        await progress().execute(account()),
        isA<Err<ArkOperation?, ArkFailure>>(),
      );
      expect(port.sent, isEmpty);
    });
  });

  group('funding an exit before it starts', () {
    ArkQuote quote({required int fee, int? reserve}) => ArkQuote(
      id: 'quote',
      account: account(),
      generation: 1,
      chainSource: Uri.parse('http://localhost:3000'),
      configGeneration: 1,
      kind: ArkOperationKind.emergencyExit,
      amount: Sats.fromInt(50000),
      fee: Sats.fromInt(fee),
      net: Sats.fromInt(49900),
      observedTip: 100,
      validUntil: DateTime.utc(2100),
      confirmedReserveExposure: reserve == null ? null : Sats.fromInt(reserve),
    );
    FundArkExitStartUsecase start() =>
        FundArkExitStartUsecase(port, funding, now: () => now);

    test('a reserve that covers the fees sends nothing', () async {
      expect(
        await start().execute(
          account(),
          quote: quote(fee: 500, reserve: 900),
          reserveAddress: reserve,
        ),
        isA<Ok<void, ArkFailure>>(),
      );
      expect(port.sent, isEmpty);
    });

    test('a short reserve is topped up, and only once', () async {
      await start().execute(
        account(),
        quote: quote(fee: 500, reserve: 100),
        reserveAddress: reserve,
      );
      expect(port.sent, [(reserve, Sats.fromInt(1000))]);
      // The background check sees it was just sent.
      await usecase().execute(
        account(),
        reserveAddress: reserve,
        short: short(400),
      );
      expect(port.sent, hasLength(1));
    });

    test(
      'without the funds in Secure Bitcoin the exit does not start',
      () async {
        port.result = const Err(ArkPaymentInsufficientFundsFailure());
        expect(
          await start().execute(
            account(),
            quote: quote(fee: 5000),
            reserveAddress: reserve,
          ),
          isA<Err<void, ArkFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<ArkExitFeesUnfundedFailure>().having(
              (f) => f.amount,
              'amount',
              Sats.fromInt(5000),
            ),
          ),
        );
      },
    );
  });
}
