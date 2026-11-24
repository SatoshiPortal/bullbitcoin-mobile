import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/usecases/confirm_ark_operation_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_operations_test.dart' show account, Preferences;
import 'fake_ark_client.dart';

/// Answers busy [busyFor] times, then [submitted].
class BusyClient extends FakeArkClient {
  int busyFor;
  int submits = 0;
  BusyClient(this.busyFor) {
    submitted = Ok(
      ArkOperation(
        id: 'attempt',
        kind: ArkOperationKind.emergencyExit,
        status: ArkOperationStatus.pending,
        chainSource: Uri.parse('http://localhost:3000'),
        configGeneration: 1,
      ),
    );
  }

  @override
  Future<Result<ArkOperation, ArkWalletFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  ) async {
    submits++;
    if (busyFor > 0) {
      busyFor--;
      return const Err(ArkWriterBusyFailure());
    }
    return submitted;
  }
}

ArkQuote quote() => ArkQuote(
  id: 'quote',
  account: account(),
  generation: 1,
  chainSource: Uri.parse('http://localhost:3000'),
  configGeneration: 1,
  kind: ArkOperationKind.emergencyExit,
  amount: Sats.fromInt(1000),
  fee: Sats.fromInt(10),
  net: Sats.fromInt(990),
  observedTip: 100,
  validUntil: DateTime.utc(2100),
);

void main() {
  ConfirmArkOperationUsecase usecase(BusyClient client, List<Duration> waits) =>
      ConfirmArkOperationUsecase(
        ArkRepositoryImpl(client),
        Preferences(),
        wait: (delay) async => waits.add(delay),
      );

  test('a briefly busy Ark is waited out, then the operation starts', () async {
    final client = BusyClient(2);
    final waits = <Duration>[];
    final result = await usecase(
      client,
      waits,
    ).execute(account(), quote(), 'attempt');
    expect(result, isA<Ok<ArkOperation, ArkFailure>>());
    expect(client.submits, 3);
    expect(waits, hasLength(2));
  });

  ArkSnapshot recorded(List<String> attempts) => ArkSnapshot(
    account: account(),
    revision: 1,
    observedAt: DateTime.utc(2026),
    operations: [
      for (final id in attempts)
        ArkOperation(
          id: id,
          kind: ArkOperationKind.emergencyExit,
          status: ArkOperationStatus.admitted,
          chainSource: Uri.parse('http://localhost:3000'),
          configGeneration: 1,
        ),
    ],
  );

  test('busy that persists with no attempt recorded says busy', () async {
    final client = BusyClient(100)..snapshot = Ok(recorded([]));
    final result = await usecase(
      client,
      [],
    ).execute(account(), quote(), 'attempt');
    expect(
      result,
      isA<Err<ArkOperation, ArkFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ArkOperationBusyFailure>(),
      ),
    );
    expect(client.submits, ConfirmArkOperationUsecase.busyRetries + 1);
  });

  test(
    'a refusal whose attempt was recorded stays an unknown outcome',
    () async {
      final client = BusyClient(100)..snapshot = Ok(recorded(['attempt']));
      final result = await usecase(
        client,
        [],
      ).execute(account(), quote(), 'attempt');
      expect(
        result,
        isA<Err<ArkOperation, ArkFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ArkSubmissionUncertainFailure>(),
        ),
      );
    },
  );

  test('an unreadable record keeps a refusal an unknown outcome', () async {
    final client = BusyClient(100)..snapshot = const Err(ArkStorageFailure());
    final result = await usecase(
      client,
      [],
    ).execute(account(), quote(), 'attempt');
    expect(
      result,
      isA<Err<ArkOperation, ArkFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ArkSubmissionUncertainFailure>(),
      ),
    );
  });

  test('any other failure after dispatch stays an unknown outcome', () async {
    final client = BusyClient(0)..submitted = const Err(ArkStorageFailure());
    final result = await usecase(
      client,
      [],
    ).execute(account(), quote(), 'attempt');
    expect(
      result,
      isA<Err<ArkOperation, ArkFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ArkSubmissionUncertainFailure>(),
      ),
    );
    expect(client.submits, 1);
  });
}
