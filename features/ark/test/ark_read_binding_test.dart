import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/usecases/read_ark_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_operations_test.dart' show account, snapshot;
import 'fake_ark_client.dart';

ArkAccountId other() => ArkAccountId(
  parent: Fingerprint('22334455'),
  network: account().network,
  serverIdentity: account().serverIdentity,
);

void main() {
  test(
    'read refuses another account projection without changing the request',
    () async {
      final client = FakeArkClient()..snapshot = Ok(snapshot(other()));
      final result = await ReadArkUsecase(ArkRepositoryImpl(client))
          .execute(account());
      expect(
        result,
        isA<Err<ArkSnapshot, ArkFailure>>().having(
          (r) => r.failure,
          'account binding',
          isA<ArkUnexpectedFailure>(),
        ),
      );
      expect(client.calls, ['read']);
      expect(client.arguments, [account()]);
    },
  );

  test(
    'watch refuses a foreign projection and continues with the correct account',
    () async {
      final correct = snapshot(account());
      final client = FakeArkClient()
        ..changes = Stream.fromIterable([Ok(snapshot(other())), Ok(correct)]);
      final observed = await ReadArkUsecase(ArkRepositoryImpl(client))
          .watch(account())
          .toList();
      expect(observed, hasLength(2));
      expect(
        observed.first,
        isA<Err<ArkSnapshot, ArkFailure>>().having(
          (r) => r.failure,
          'account binding',
          isA<ArkUnexpectedFailure>(),
        ),
      );
      expect(
        observed.last,
        isA<Ok<ArkSnapshot, ArkFailure>>().having(
          (r) => r.value,
          'same trusted projection',
          same(correct),
        ),
      );
      expect(client.calls, isEmpty);
      expect(client.arguments, [account()]);
    },
  );

  test(
    'synchronize refuses a foreign pass without publishing its projection',
    () async {
      final client = FakeArkClient()
        ..pass = Ok(ArkPassOutcome(snapshot: snapshot(other())));
      final result = await SynchronizeArkUsecase(ArkRepositoryImpl(client))
          .execute(account(), renew: true);
      expect(
        result,
        isA<Err<ArkPassOutcome, ArkFailure>>().having(
          (r) => r.failure,
          'account binding',
          isA<ArkUnexpectedFailure>(),
        ),
      );
      expect(client.calls, ['renew']);
      expect(client.arguments, [(account(), true)]);
    },
  );

  test('matching read retains actual freshness metadata and admits no synchronization', () async {
    final correct = snapshot(account());
    final client = FakeArkClient()..snapshot = Ok(correct);
    final result = await ReadArkUsecase(ArkRepositoryImpl(client))
        .execute(account());
    expect(
      result,
      isA<Ok<ArkSnapshot, ArkFailure>>().having(
        (r) => r.value,
        'unmodified projection',
        same(correct),
      ),
    );
    expect(client.calls, ['read']);
  });

  test(
    'typed unavailable read remains unavailable without a fallback or refresh',
    () async {
      final client = FakeArkClient()..snapshot = const Err(ArkStorageFailure());
      final result = await ReadArkUsecase(ArkRepositoryImpl(client))
          .execute(account());
      expect(
        result,
        isA<Err<ArkSnapshot, ArkFailure>>().having(
          (r) => r.failure,
          'storage failure',
          isA<ArkFeatureStorageFailure>(),
        ),
      );
      expect(client.calls, ['read']);
    },
  );
}
