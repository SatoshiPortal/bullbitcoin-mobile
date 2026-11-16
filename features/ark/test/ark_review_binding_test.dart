import 'package:ark/ark.dart';
import 'package:bull_ark/bull_ark.dart' show ArkFailure, ArkDisabledFailure;
import 'package:bull_ark/src/data/create_ark_facade.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'ark_operations_test.dart' show account, quote, Preferences, Provisioner;
import 'fake_ark_client.dart';

/// Models the actual package boundary: submission executes the native quote
/// persisted by quoteId, irrespective of caller-supplied display metadata.
class JournalClient extends FakeArkClient {
  final Map<String, ArkQuote> saved = {};
  final List<ArkOperationKind> executed = [];
  @override
  Future<Result<ArkQuote, ArkWalletFailure>> quote(
    ArkAccountId account,
    ArkQuoteRequest request,
  ) async {
    final value = quoted;
    if (value case Ok(:final value)) {
      saved[value.id] = value;
    }
    return value;
  }

  @override
  Future<Result<ArkOperation, ArkWalletFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  ) async {
    if (submission is! ArkConfirmQuote) {
      return const Err(ArkValidationFailure());
    }
    final stored = saved[submission.quoteId];
    if (stored == null) return const Err(ArkValidationFailure());
    executed.add(stored.kind);
    return Ok(
      ArkOperation(
        id: submission.operationId,
        kind: stored.kind,
        status: ArkOperationStatus.succeeded,
        chainSource: stored.chainSource,
        configGeneration: stored.configGeneration,
      ),
    );
  }
}

void main() {
  test(
    'caller-forged kind cannot execute saved payment quote while Ark is off',
    () async {
      final id = account();
      final trusted = quote(id);
      final client = JournalClient()..quoted = Ok(trusted);
      final preferences = Preferences();
      final facade = createArkFacade(
        client: client,
        preferences: preferences,
        provisioning: Provisioner(),
      );
      final issued = await facade.quote(
        id,
        ArkQuoteRequest.payment(
          destination: ArkPaymentDestination(
            kind: ArkDestinationKind.bolt11,
            value: 'lnbcrt1publicfixture',
          ),
          amount: Sats.fromInt(1000),
        ),
      );
      expect(issued, isA<Ok>());
      expect(client.saved[trusted.id]?.kind, ArkOperationKind.payment);
      final forged = ArkQuote(
        id: trusted.id,
        account: id,
        generation: trusted.generation,
        kind: ArkOperationKind.claim,
        amount: trusted.amount,
        fee: trusted.fee,
        net: trusted.net,
        observedTip: trusted.observedTip,
        validUntil: trusted.validUntil,
        chainSource: trusted.chainSource,
        configGeneration: trusted.configGeneration,
      );
      preferences.enabled = false;
      await expectLater(
        () async =>
            facade.confirm(id, forged as dynamic, operationId: 'attack'),
        throwsA(isA<TypeError>()),
        reason: 'Package execution uses the saved payment identity, not forged display kind',
      );
      expect(client.executed, isEmpty);
    },
  );
  test(
    'legitimate feature-issued saved review rechecks current disabled policy',
    () async {
      final id = account();
      final client = JournalClient()..quoted = Ok(quote(id));
      final preferences = Preferences();
      final facade = createArkFacade(
        client: client,
        preferences: preferences,
        provisioning: Provisioner(),
      );
      final result = await facade.quote(
        id,
        ArkQuoteRequest.payment(
          destination: ArkPaymentDestination(
            kind: ArkDestinationKind.bolt11,
            value: 'lnbcrt1publicfixture',
          ),
          amount: Sats.fromInt(1000),
        ),
      );
      switch (result) {
        case Err():
          fail('Expected issued review');
        case Ok(:final value):
          preferences.enabled = false;
          final confirmed = await facade.confirm(
            id,
            value,
            operationId: 'saved',
          );
          expect(
            confirmed,
            isA<Err<ArkOperation, ArkFailure>>().having(
              (r) => r.failure,
              'failure',
              isA<ArkDisabledFailure>(),
            ),
          );
      }
      expect(client.executed, isEmpty);
    },
  );
}
