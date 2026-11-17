import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/usecases/confirm_ark_operation_usecase.dart';
import 'package:bull_ark/src/domain/usecases/parse_ark_destination_usecase.dart';
import 'package:bull_ark/src/domain/usecases/quote_ark_operation_usecase.dart';
import 'package:bull_ark/src/domain/usecases/review_ark_payment_usecase.dart';
import 'package:bull_ark/src/presentation/ark_payment_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_operations_test.dart' show account, Preferences;
import 'fake_ark_client.dart';

const destination = 'lnbcrt1publicfixture'; // Syntax only; no real invoice.
ArkQuote paymentQuote(ArkAccountId owner, {int amount = 1000}) => ArkQuote(
  id: 'same-payment-quote',
  account: owner,
  generation: 2,
  chainSource: Uri.parse('http://localhost:3000'),
  configGeneration: 1,
  kind: ArkOperationKind.payment,
  amount: Sats.fromInt(amount),
  fee: Sats.fromInt(100),
  net: Sats.fromInt(amount - 100),
  destination: destination,
  observedTip: 100,
  validUntil: DateTime.utc(2030),
);

class PaymentClient extends FakeArkClient {
  final replies = <Completer<Result<ArkQuote, ArkWalletFailure>>>[];
  Completer<Result<ArkOperation, ArkWalletFailure>>? submission;
  final journal = <String, ArkOperation>{};
  PaymentClient() {
    quoted = const Err(ArkUnavailableFailure());
    submitted = const Err(ArkStorageFailure());
  }
  @override
  Future<Result<ArkQuote, ArkWalletFailure>> quote(
    ArkAccountId account,
    ArkQuoteRequest request,
  ) {
    if (replies.isEmpty) return super.quote(account, request);
    calls.add('quote');
    arguments.add((account, request));
    return replies.removeAt(0).future;
  }

  @override
  Future<Result<ArkOperation, ArkWalletFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  ) {
    if (submission case ArkConfirmQuote(:final operationId)) {
      journal[operationId] = ArkOperation(
        id: operationId,
        kind: ArkOperationKind.payment,
        status: ArkOperationStatus.pending,
        chainSource: Uri.parse('http://localhost:3000'),
        configGeneration: 1,
      );
    }
    final pending = this.submission;
    if (pending == null) return super.submit(account, submission);
    calls.add('submit');
    arguments.add((account, submission));
    return pending.future;
  }
}

class PaymentRig {
  final client = PaymentClient();
  final preferences = Preferences();
  late final ArkPaymentCubit cubit;
  int ids = 0;
  PaymentRig({ArkAccountId? owner}) {
    final repository = ArkRepositoryImpl(client);
    cubit = ArkPaymentCubit(
      ReviewArkPaymentUsecase(
        const ParseArkDestinationUsecase(),
        QuoteArkOperationUsecase(repository, preferences),
      ),
      ConfirmArkOperationUsecase(repository, preferences),
      () => 'payment-${++ids}',
      account: owner ?? account(),
    );
    addTearDown(() async {
      if (!cubit.isClosed) await cubit.close();
    });
  }
  Future<void> ready({int amount = 1000}) async {
    client.quoted = Ok(paymentQuote(cubit.account, amount: amount));
    await cubit.review(destination: destination, amount: '$amount');
  }
}

void main() {
  test(
    'explicit review alone captures payment request; editing never quotes',
    () async {
      final r = PaymentRig();
      r.cubit.edit();
      r.cubit.edit();
      expect(r.client.calls, isEmpty);
      await r.ready();
      expect(r.client.calls, ['quote']);
      final argument = r.client.arguments.single;
      expect(argument, isA<(ArkAccountId, ArkQuoteRequest)>());
      final (owner, quoteRequest) = argument as (ArkAccountId, ArkQuoteRequest);
      expect(owner, r.cubit.account);
      expect(quoteRequest, isA<ArkPaymentQuoteRequest>());
      final request = quoteRequest as ArkPaymentQuoteRequest;
      expect(request.amount, Sats.fromInt(1000));
      expect(request.destination.value, destination);
      expect(r.cubit.state, isA<ArkPaymentReview>());
      expect(r.ids, 0);
    },
  );
  test(
    'pending review deduplicates; edited epoch rejects late q1 after q2',
    () async {
      final r = PaymentRig();
      final first = Completer<Result<ArkQuote, ArkWalletFailure>>();
      final second = Completer<Result<ArkQuote, ArkWalletFailure>>();
      r.client.replies.addAll([first, second]);
      final q1 = r.cubit.review(destination: destination, amount: '1000');
      await r.cubit.review(destination: destination, amount: '9999');
      expect(r.client.calls, ['quote']);
      r.cubit.edit();
      final q2 = r.cubit.review(destination: destination, amount: '2000');
      second.complete(Ok(paymentQuote(r.cubit.account, amount: 2000)));
      await q2;
      first.complete(Ok(paymentQuote(r.cubit.account)));
      await q1;
      expect(
        (r.cubit.state as ArkPaymentReview).quote.amount,
        Sats.fromInt(2000),
      );
      expect(r.client.calls, ['quote', 'quote']);
      expect(r.ids, 0);
    },
  );
  test(
    'invalid amount is pre-dispatch and needs a fresh explicit Review',
    () async {
      final r = PaymentRig();
      await r.cubit.review(destination: destination, amount: '1.5');
      expect(
        r.cubit.state,
        isA<ArkPaymentEditing>().having(
          (s) => s.failure,
          'typed failure',
          isA<ArkInvalidRequestFailure>(),
        ),
      );
      expect(r.client.calls, isEmpty);
      await r.ready();
      expect(r.client.calls, ['quote']);
    },
  );
  test('disabled precheck has zero submit; post-dispatch storage retains original ID', () async {
    final r = PaymentRig();
    await r.ready();
    r.preferences.enabled = false;
    await r.cubit.confirm();
    expect(
      r.cubit.state,
      isA<ArkPaymentEditing>().having(
        (s) => s.failure,
        'disabled',
        isA<ArkDisabledFailure>(),
      ),
    );
    expect(r.client.calls, ['quote']);
    expect(r.ids, 1);
    r.preferences.enabled = true;
    await r.ready();
    final pending = Completer<Result<ArkOperation, ArkWalletFailure>>();
    r.client.submission = pending;
    final confirm = r.cubit.confirm();
    await Future<void>.delayed(Duration.zero);
    r.cubit.edit();
    await r.cubit.confirm();
    await r.cubit.review(destination: destination, amount: '2000');
    expect(r.cubit.state, isA<ArkPaymentSubmitting>());
    expect(r.ids, 2);
    expect(r.client.journal.keys, ['payment-2']);
    pending.complete(const Err(ArkStorageFailure()));
    await confirm;
    expect(
      r.cubit.state,
      isA<ArkPaymentUncertain>().having(
        (s) => s.operationId,
        'original',
        'payment-2',
      ),
    );
    r.cubit.edit();
    await r.cubit.confirm();
    await r.cubit.review(destination: destination, amount: '3000');
    expect(r.ids, 2);
    expect(r.client.calls, ['quote', 'quote', 'submit']);
  });
  test('closed owner rejects late quote and submission publication without undoing journal', () async {
    final quoting = PaymentRig();
    final reply = Completer<Result<ArkQuote, ArkWalletFailure>>();
    quoting.client.replies.add(reply);
    final quote = quoting.cubit.review(
      destination: destination,
      amount: '1000',
    );
    await quoting.cubit.close();
    reply.complete(Ok(paymentQuote(quoting.cubit.account)));
    await quote;
    expect(quoting.cubit.state, isA<ArkPaymentQuoting>());
    final signing = PaymentRig();
    await signing.ready();
    final submit = Completer<Result<ArkOperation, ArkWalletFailure>>();
    signing.client.submission = submit;
    final confirming = signing.cubit.confirm();
    await Future<void>.delayed(Duration.zero);
    await signing.cubit.close();
    submit.complete(const Err(ArkStorageFailure()));
    await confirming;
    expect(signing.cubit.state, isA<ArkPaymentSubmitting>());
    expect(signing.client.journal.keys, ['payment-1']);
    expect(signing.ids, 1);
  });
}
