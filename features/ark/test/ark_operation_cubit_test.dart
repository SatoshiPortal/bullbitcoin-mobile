import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
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

ArkOperationCubit controller(FakeArkClient client) {
  final repository = ArkRepositoryImpl(client);
  final preferences = Preferences();
  return ArkOperationCubit(
    QuoteArkOperationUsecase(repository, preferences),
    ConfirmArkOperationUsecase(
      repository,
      preferences,
      now: () => DateTime.utc(2026),
    ),
    () => 'operation-1',
    account: account(),
    request: ArkQuoteRequest.renewal(ids: ['vtxo-1']),
  );
}

ArkOperation submitted() => ArkOperation(
  id: 'operation-1',
  kind: ArkOperationKind.renewal,
  status: ArkOperationStatus.pending,
  chainSource: Uri.parse('https://example.com'),
  configGeneration: 1,
);

void main() {
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
