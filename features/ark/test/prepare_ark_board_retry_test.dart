import 'package:ark/ark.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:bull_ark/src/domain/usecases/prepare_ark_board_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_board_journey_test.dart' show prepared;
import 'ark_information_widget_test.dart' show config;
import 'ark_operations_test.dart' show Preferences;

import 'package:bull_ark/src/domain/ark_board_funding_port.dart';

/// Answers each prepare with the next of [answers], then the last again.
final class _Answers implements ArkBoardFundingPort {
  final List<Result<ArkBoardPreparation, ArkFailure>> answers;
  final calls = <String>[];
  _Answers(this.answers);

  @override
  Future<Result<ArkBoardPreparation, ArkFailure>> prepare(
    ArkAccountConfig config,
    Sats amount,
  ) async {
    calls.add('prepare');
    final index = calls.length - 1;
    return answers[index < answers.length ? index : answers.length - 1];
  }

  @override
  Future<Result<ArkBoardPreparation, ArkFailure>> readPrepared(
    ArkAccountId account,
    String operationId,
  ) async => const Err(ArkServiceUnavailableFailure());

  @override
  Future<Result<ArkOperation, ArkFailure>> confirm(
    ArkAccountId account,
    String operationId,
    String reviewBinding,
  ) async => const Err(ArkServiceUnavailableFailure());
}

void main() {
  Future<Result<ArkBoardPreparation, ArkFailure>> run(
    _Answers funding,
    List<Duration> waits,
  ) => PrepareArkBoardUsecase(
    funding,
    Preferences(),
    wait: (delay) async => waits.add(delay),
  ).execute(config(), Sats.fromInt(1000));

  test('a stale price is prepared again at once', () async {
    final funding = _Answers([
      const Err(ArkReviewExpiredFailure()),
      const Err(ArkReviewExpiredFailure()),
      Ok(prepared()),
    ]);
    final waits = <Duration>[];
    expect(
      await run(funding, waits),
      isA<Ok<ArkBoardPreparation, ArkFailure>>(),
    );
    expect(funding.calls, ['prepare', 'prepare', 'prepare']);
    expect(waits, isEmpty);
  });

  test(
    'a price that keeps going stale is reported after a few tries',
    () async {
      final funding = _Answers([const Err(ArkReviewExpiredFailure())]);
      final result = await run(funding, []);
      expect(
        result,
        isA<Err<ArkBoardPreparation, ArkFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ArkReviewExpiredFailure>(),
        ),
      );
      expect(
        funding.calls.where((c) => c == 'prepare'),
        hasLength(PrepareArkBoardUsecase.busyAttempts),
      );
    },
  );

  test('any other refusal is reported without trying again', () async {
    final funding = _Answers([const Err(ArkPaymentInsufficientFundsFailure())]);
    await run(funding, []);
    expect(funding.calls, ['prepare']);
  });
}
