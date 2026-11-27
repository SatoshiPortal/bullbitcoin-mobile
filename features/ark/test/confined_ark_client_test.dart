import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/confined_ark_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_claim_recovery_test.dart' show journal, saved, txid;
import 'ark_operations_test.dart' show account;
import 'fake_ark_client.dart';

void main() {
  late FakeArkClient inner;
  late ArkClient confined;

  setUp(() {
    inner = FakeArkClient()
      ..snapshot = Ok(journal())
      ..submitted = Ok(saved(status: ArkOperationStatus.pending))
      ..pass = Ok(
        ArkPassOutcome(snapshot: journal(), completedStages: {ArkStage.vtxos}),
      );
    confined = confineArkClient(inner);
  });

  test('the saved-claim lane and the refresh pass through', () async {
    expect(await confined.read(account()), isA<Ok>());
    expect(
      await confined.submit(
        account(),
        ArkSubmission.rebroadcastClaim(
          operationId: 'saved',
          expectedTxid: txid,
        ),
      ),
      isA<Ok>(),
    );
    expect(await confined.synchronize(account(), renew: true), isA<Ok>());
    expect(inner.calls, ['read', 'submit', 'renew']);
  });

  test('a synchronization without renewal is refused', () async {
    final result = await confined.synchronize(account(), renew: false);
    expect(
      (result as Err<ArkPassOutcome, ArkWalletFailure>).failure,
      isA<ArkRenewalNotPermittedFailure>(),
    );
    expect(inner.calls, isEmpty);
  });

  test('any other submission is refused before the inner client', () async {
    final result = await confined.submit(
      account(),
      ArkSubmission.confirmQuote(quoteId: 'q', operationId: 'o'),
    );
    expect(
      (result as Err<ArkOperation, ArkWalletFailure>).failure,
      isA<ArkRenewalNotPermittedFailure>(),
    );
    expect(inner.calls, isEmpty);
  });

  test(
    'exits, receiving, quoting, creating and the next round are refused',
    () async {
      expect(await confined.progressStartedExits(account()), isA<Err>());
      expect(await confined.claimAuthorized(account()), isA<Err>());
      expect(await confined.nextRound(account()), isA<Err>());
      expect(await confined.watch(account()).isEmpty, isTrue);
      expect(inner.calls, isEmpty, reason: 'nothing reached the inner client');
    },
  );
}
