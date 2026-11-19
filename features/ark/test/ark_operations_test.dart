import 'fake_ark_board_funding.dart';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/create_ark_facade.dart';
import 'package:bull_ark/src/domain/ark_provisioning_port.dart';
import 'package:bull_ark/bull_ark.dart'
    show ArkFailure, ArkSubmissionUncertainFailure, ArkReviewExpiredFailure;
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/usecases/confirm_ark_operation_usecase.dart';
import 'package:bull_ark/src/domain/usecases/set_ark_enabled_usecase.dart';
import 'package:test/test.dart';
import 'package:primitives/primitives.dart';

import 'fake_ark_client.dart';

final class Provisioner implements ArkProvisioningPort {
  @override
  Future<Result<ArkSnapshot, ArkFailure>> run(
    ArkAccountConfig config,
    Future<Result<ArkSnapshot, ArkFailure>> Function() create,
  ) => create();
}

final class Preferences implements ArkPreferencesRepository {
  bool enabled = true;
  @override
  Future<Result<bool, ArkFailure>> isEnabled(ArkAccountId account) async =>
      Ok(enabled);
  @override
  Future<Result<void, ArkFailure>> setEnabled(
    ArkAccountId account,
    bool enabled,
  ) async {
    this.enabled = enabled;
    return const Ok(null);
  }
}

final class ThrowingClient extends FakeArkClient {
  @override
  Future<Result<ArkOperation, ArkWalletFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  ) async {
    throw Exception('private transport detail');
  }
}

ArkAccountId account() => ArkAccountId(
  parent: Fingerprint('00112233'),
  network: BitcoinNetwork.regtest,
  serverIdentity: 'https://ark.second.tech',
);
ArkSnapshot snapshot(ArkAccountId account) => ArkSnapshot(
  account: account,
  revision: 2,
  observedAt: DateTime.utc(2026),
  stale: false,
  spendable: Sats.fromInt(5000),
  recovery: ArkRecoveryStatus.complete,
  obligations: ArkObligationStatus.present,
);
ArkQuote quote(ArkAccountId account) => ArkQuote(
  id: 'quote-1',
  account: account,
  generation: 2,
  kind: ArkOperationKind.payment,
  amount: Sats.fromInt(1000),
  fee: Sats.fromInt(2),
  net: Sats.fromInt(1000),
  observedTip: 100,
  validUntil: DateTime.utc(2027),
  chainSource: Uri.parse('https://example.com'),
  configGeneration: 1,
);

void main() {
  test(
    'turning off a funded account preserves native custody and recovery reads',
    () async {
      final id = account();
      final client = FakeArkClient()..snapshot = Ok(snapshot(id));
      final preferences = Preferences();
      final repository = ArkRepositoryImpl(client);
      expect(
        await SetArkEnabledUsecase(repository, preferences).execute(id, false),
        isA<Ok>(),
      );
      expect(preferences.enabled, false);
      expect(client.calls, isEmpty);
      expect(await repository.read(id), isA<Ok>());
      expect(client.calls, ['read']);
    },
  );
  test(
    'unknown admitted submit remains uncertain with original operation id',
    () async {
      final result = await ArkRepositoryImpl(ThrowingClient()).submit(
        account(),
        ArkSubmission.confirmQuote(quoteId: 'q', operationId: 'operation-7'),
      );
      expect(
        result,
        isA<Err<ArkOperation, ArkFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ArkSubmissionUncertainFailure>().having(
            (f) => f.operationId,
            'operationId',
            'operation-7',
          ),
        ),
      );
    },
  );
  test('expired review cannot reach native submit', () async {
    final id = account();
    final client = FakeArkClient();
    final result = await ConfirmArkOperationUsecase(
      ArkRepositoryImpl(client),
      Preferences(),
      now: () => DateTime.utc(2027),
    ).execute(id, quote(id), 'operation');
    expect(
      result,
      isA<Err<ArkOperation, ArkFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ArkReviewExpiredFailure>(),
      ),
    );
    expect(client.calls, isEmpty);
  });
  test(
    'protective renewal stays available off and retains account and renew flag',
    () async {
      final id = account();
      final client = FakeArkClient()
        ..pass = Ok(
          ArkPassOutcome(snapshot: snapshot(id), submittedRounds: ['round-1']),
        );
      final preferences = Preferences()..enabled = false;
      final facade = createArkFacade(
        boardFunding: FakeArkBoardFunding(),
        client: client,
        preferences: preferences,
        provisioning: Provisioner(),
      );
      final result = await facade.synchronize(id, renew: true);
      expect(result, isA<Ok>());
      expect(client.arguments, [(id, true)]);
      expect(client.calls, ['renew']);
    },
  );
}
