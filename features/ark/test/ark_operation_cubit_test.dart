import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/repositories/ark_preferences_repository.dart';
import 'package:bull_ark/src/domain/usecases/confirm_ark_operation_usecase.dart';
import 'package:bull_ark/src/domain/usecases/quote_ark_operation_usecase.dart';
import 'package:bull_ark/src/presentation/ark_operation_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_operations_test.dart' show account, Preferences, quote;
import 'fake_ark_client.dart';

class DelayedOperationClient extends FakeArkClient {
  final reply = Completer<Result<ArkOperation, ArkWalletFailure>>();

  @override
  Future<Result<ArkOperation, ArkWalletFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  ) {
    calls.add('submit');
    arguments.add((account, submission));
    return reply.future;
  }
}

class DelayedQuoteClient extends FakeArkClient {
  final reply = Completer<Result<ArkQuote, ArkWalletFailure>>();

  @override
  Future<Result<ArkQuote, ArkWalletFailure>> quote(
    ArkAccountId account,
    ArkQuoteRequest request,
  ) {
    calls.add('quote');
    return reply.future;
  }
}

class EffectThenFailureClient extends FakeArkClient {
  final ArkWalletFailure failure;
  final Map<String, ArkOperation> journal = {};

  EffectThenFailureClient(this.failure);

  @override
  Future<Result<ArkOperation, ArkWalletFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  ) async {
    calls.add('submit');
    arguments.add((account, submission));
    if (submission case ArkConfirmQuote(:final operationId)) {
      journal[operationId] = ArkOperation(
        id: operationId,
        kind: ArkOperationKind.payment,
        status: ArkOperationStatus.pending,
        chainSource: Uri.parse('https://example.com'),
        configGeneration: 1,
      );
    }
    return Err(failure);
  }

  /// Like the real client, its record of an attempt is readable.
  @override
  Future<Result<ArkSnapshot, ArkWalletFailure>> read(
    ArkAccountId account,
  ) async => Ok(
    ArkSnapshot(
      account: account,
      revision: 1,
      observedAt: DateTime.utc(2026),
      operations: journal.values.toList(),
    ),
  );
}

class FailingPreferences implements ArkPreferencesRepository {
  bool fail = false;

  @override
  Future<Result<bool, ArkFailure>> isEnabled(ArkAccountId account) async =>
      fail ? const Err(ArkFeatureStorageFailure()) : const Ok(true);

  @override
  Future<Result<void, ArkFailure>> setEnabled(
    ArkAccountId account,
    bool enabled,
  ) async => const Ok(null);
}

ArkOperationCubit controller(
  FakeArkClient client, {
  ArkPreferencesRepository? preferences,
  String Function()? operationId,
}) {
  final repository = ArkRepositoryImpl(client);
  final settings = preferences ?? Preferences();
  return ArkOperationCubit(
    QuoteArkOperationUsecase(repository, settings),
    ConfirmArkOperationUsecase(
      repository,
      settings,
      now: () => DateTime.utc(2026),
      wait: (_) async {},
    ),
    operationId ?? () => 'operation-1',
    account: account(),
    request: ArkQuoteRequest.payment(
      destination: ArkPaymentDestination(
        kind: ArkDestinationKind.bolt11,
        value: 'lnbcrt1publicfixture',
      ),
      amount: Sats.fromInt(1000),
    ),
  );
}

ArkOperation submitted() => ArkOperation(
  id: 'operation-1',
  kind: ArkOperationKind.payment,
  status: ArkOperationStatus.pending,
  chainSource: Uri.parse('https://example.com'),
  configGeneration: 1,
);

void main() {
  for (final failure in <ArkWalletFailure>[
    const ArkStorageFailure(),
    const ArkNativeFailure(),
    const ArkUnavailableFailure(),
    const ArkWriterBusyFailure(),
    const ArkValidationFailure(),
    const ArkStaleQuoteFailure(),
    const ArkRecoveryRequiredFailure(),
    const ArkInsufficientFundsFailure(),
    const ArkOutcomeUnknownFailure('untrusted-other-id'),
  ]) {
    test(
      'post-submit ${failure.runtimeType} retains the original attempt',
      () async {
        final client = EffectThenFailureClient(failure)
          ..quoted = Ok(quote(account()));
        var nextId = 0;
        final cubit = controller(
          client,
          operationId: () => 'operation-${++nextId}',
        );
        addTearDown(cubit.close);
        await cubit.load();
        await cubit.confirm();
        await cubit.load();
        await cubit.confirm();
        expect(client.journal.keys, ['operation-1']);
        // Busy is waited out under the same id before it counts as unknown.
        expect(client.calls, [
          'quote',
          ...List.filled(
            failure is ArkWriterBusyFailure
                ? ConfirmArkOperationUsecase.busyRetries + 1
                : 1,
            'submit',
          ),
        ]);
        expect(nextId, 1);
        expect(
          cubit.state,
          isA<ArkOperationUncertain>().having(
            (state) => state.operationId,
            'original operation',
            'operation-1',
          ),
        );
      },
    );
  }

  test(
    'a refusal that left no attempt says why, not an unknown outcome',
    () async {
      final client = FakeArkClient()
        ..quoted = Ok(quote(account()))
        ..submitted = const Err(ArkStaleQuoteFailure())
        ..snapshot = Ok(
          ArkSnapshot(
            account: account(),
            revision: 1,
            observedAt: DateTime.utc(2026),
          ),
        );
      final cubit = controller(client);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.confirm();
      expect(
        cubit.state,
        isA<ArkOperationFailed>().having(
          (state) => state.failure,
          'failure',
          isA<ArkReviewExpiredFailure>(),
        ),
      );
    },
  );

  test(
    'a preferences storage failure before submit permits a fresh review',
    () async {
      final client = FakeArkClient()
        ..quoted = Ok(quote(account()))
        ..submitted = Ok(submitted());
      final preferences = FailingPreferences();
      final cubit = controller(client, preferences: preferences);
      addTearDown(cubit.close);
      await cubit.load();
      preferences.fail = true;
      await cubit.confirm();
      expect(
        cubit.state,
        isA<ArkOperationFailed>().having(
          (state) => state.failure,
          'pre-submit storage failure',
          isA<ArkFeatureStorageFailure>(),
        ),
      );
      expect(client.calls, ['quote']);
      preferences.fail = false;
      await cubit.load();
      await cubit.confirm();
      expect(cubit.state, isA<ArkOperationSubmitted>());
      expect(client.calls, ['quote', 'quote', 'submit']);
    },
  );

  test('overlapping reloads share the pending review request', () async {
    final client = DelayedQuoteClient();
    final cubit = controller(client);
    addTearDown(cubit.close);
    final pending = cubit.load();
    await cubit.load();
    await cubit.confirm();
    expect(cubit.state, isA<ArkOperationLoading>());
    expect(client.calls, ['quote']);
    client.reply.complete(Ok(quote(account())));
    await pending;
    expect(cubit.state, isA<ArkOperationReview>());
  });

  test('a late quote cannot emit after the controller is closed', () async {
    final client = DelayedQuoteClient();
    final cubit = controller(client);
    final pending = cubit.load();
    await cubit.close();
    client.reply.complete(Ok(quote(account())));
    await pending;
    expect(cubit.isClosed, true);
    expect(client.calls, ['quote']);
  });

  test('reloading during submission cannot rearm confirmation', () async {
    final client = DelayedOperationClient()..quoted = Ok(quote(account()));
    final cubit = controller(client);
    addTearDown(cubit.close);
    await cubit.load();
    final pending = cubit.confirm();
    expect(cubit.state, isA<ArkOperationSubmitting>());
    await cubit.load();
    expect(cubit.state, isA<ArkOperationSubmitting>());
    await cubit.confirm();
    expect(client.calls, ['quote', 'submit']);
    client.reply.complete(Ok(submitted()));
    await pending;
    expect(cubit.state, isA<ArkOperationSubmitted>());
  });

  test(
    'uncertain original operation requires reconciliation, not requote',
    () async {
      final client = DelayedOperationClient()..quoted = Ok(quote(account()));
      final cubit = controller(client);
      addTearDown(cubit.close);
      await cubit.load();
      final pending = cubit.confirm();
      client.reply.completeError(Exception('transport reply lost'));
      await pending;
      expect(
        cubit.state,
        isA<ArkOperationUncertain>().having(
          (state) => state.operationId,
          'original operation',
          'operation-1',
        ),
      );
      await cubit.load();
      await cubit.confirm();
      expect(cubit.state, isA<ArkOperationUncertain>());
      expect(client.calls, ['quote', 'submit']);
    },
  );

  test('submitted operation cannot be rearmed by reload', () async {
    final client = FakeArkClient()
      ..quoted = Ok(quote(account()))
      ..submitted = Ok(submitted());
    final cubit = controller(client);
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.confirm();
    await cubit.load();
    await cubit.confirm();
    expect(cubit.state, isA<ArkOperationSubmitted>());
    expect(client.calls, ['quote', 'submit']);
  });
}
