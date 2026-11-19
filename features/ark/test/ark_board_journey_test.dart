import 'package:ark/ark.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:bull_ark/bull_ark.dart' show ArkBoardReview;
import 'package:bull_ark/src/domain/usecases/prepare_ark_board_usecase.dart';
import 'package:bull_ark/src/domain/usecases/read_ark_board_usecase.dart';
import 'package:bull_ark/src/domain/usecases/confirm_ark_board_usecase.dart';
import 'package:bull_ark/src/presentation/ark_board_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show config;
import 'ark_operations_test.dart' show account, Preferences, Provisioner;
import 'fake_ark_board_funding.dart';
import 'fake_ark_client.dart';

ArkBoardPreparation prepared({
  ArkAccountId? owner,
  String binding = 'original-review',
}) => ArkBoardPreparation(
  operationId: 'original-operation',
  reviewBinding: binding,
  account: owner ?? account(),
  sourceWalletId: 'source-wallet',
  sourceParent: account().parent,
  sourceGeneration: 7,
  fundingAmount: Sats.fromInt(1000),
  minerFee: Sats.fromInt(100),
  arkFee: Sats.fromInt(10),
  net: Sats.fromInt(990),
  feeRate: FeeRate(2),
  unsignedTxid: '1' * 64,
  expiryHeight: 500,
  validUntil: DateTime.utc(2030),
  chainSource: config().primaryEsploraUrl,
  configGeneration: 2,
);

void main() {
  test('facade issues Board review only through journal read and captures original identity', () async {
    final funding = FakeArkBoardFunding()..observed = Ok(prepared());
    final preferences = Preferences();
    final facade = createArkFacade(
      client: FakeArkClient(),
      preferences: preferences,
      provisioning: Provisioner(),
      boardFunding: funding,
    );
    final result = await facade.reviewBoard(account(), 'original-operation');
    expect(result, isA<Ok<ArkBoardReview, ArkFailure>>());
    if (result case Ok(:final value)) {
      expect(value.details.sourceDebit, Sats.fromInt(1100));
      funding.observed = Ok(prepared(binding: 'replacement-review'));
      final confirmed = await facade.confirmBoard(account(), value);
      expect(
        confirmed,
        isA<Err<ArkOperation, ArkFailure>>().having(
          (v) => v.failure,
          'potential post-dispatch failure',
          isA<ArkSubmissionUncertainFailure>().having(
            (f) => f.operationId,
            'original operation',
            'original-operation',
          ),
        ),
      );
      expect(funding.arguments.last, (
        account(),
        'original-operation',
        'original-review',
      ));
      expect(funding.calls, ['read', 'confirm']);
    }
  });

  test(
    'funded-off read is protective but prepare and confirm refuse before host',
    () async {
      final funding = FakeArkBoardFunding()..observed = Ok(prepared());
      final preferences = Preferences()..enabled = false;
      final facade = createArkFacade(
        client: FakeArkClient(),
        preferences: preferences,
        provisioning: Provisioner(),
        boardFunding: funding,
      );
      expect(
        await facade.prepareBoard(config(), Sats.fromInt(1000)),
        isA<Err>(),
      );
      final review = await facade.reviewBoard(account(), 'original-operation');
      expect(review, isA<Ok>());
      if (review case Ok(:final value)) {
        expect(await facade.confirmBoard(account(), value), isA<Err>());
      }
      expect(funding.calls, ['read']);
    },
  );

  test(
    'wrong account or operation from journal cannot issue a Board review',
    () async {
      final funding = FakeArkBoardFunding()..observed = Ok(prepared());
      final reader = ReadArkBoardUsecase(funding);
      expect(
        await reader.execute(account(), 'different-operation'),
        isA<Err>(),
      );
      final other = ArkAccountId(
        parent: Fingerprint('aabbccdd'),
        network: account().network,
        serverIdentity: account().serverIdentity,
      );
      expect(await reader.execute(other, 'original-operation'), isA<Err>());
      expect(funding.calls, ['read', 'read']);
    },
  );

  test('prepare then trusted read reviews the original operation with no sign/confirm on creation', () async {
    final funding = FakeArkBoardFunding()
      ..prepared = Ok(prepared())
      ..observed = Ok(prepared());
    final preferences = Preferences();
    final cubit = ArkBoardCubit(
      PrepareArkBoardUsecase(funding, preferences),
      ReadArkBoardUsecase(funding),
      ConfirmArkBoardUsecase(funding, preferences),
      config: config(),
    );
    addTearDown(cubit.close);
    expect(funding.calls, isEmpty);
    await cubit.prepare(Sats.fromInt(1000));
    expect(cubit.state, isA<ArkBoardReviewed>());
    expect(funding.calls, ['prepare', 'read']);
    await cubit.prepare(Sats.fromInt(2000));
    expect(funding.calls, ['prepare', 'read']);
    await cubit.confirm();
    expect(cubit.state, isA<ArkBoardPending>());
    await cubit.prepare(Sats.fromInt(1000));
    await cubit.confirm();
    expect(funding.calls, ['prepare', 'read', 'confirm']);
  });

  test('uncertain preparation keeps its original ID and never silently prepares again', () async {
    final funding = FakeArkBoardFunding()
      ..prepared = const Err(
        ArkSubmissionUncertainFailure('original-operation'),
      );
    final preferences = Preferences();
    final cubit = ArkBoardCubit(
      PrepareArkBoardUsecase(funding, preferences),
      ReadArkBoardUsecase(funding),
      ConfirmArkBoardUsecase(funding, preferences),
      config: config(),
    );
    addTearDown(cubit.close);
    await cubit.prepare(Sats.fromInt(1000));
    await cubit.prepare(Sats.fromInt(1000));
    expect(
      cubit.state,
      isA<ArkBoardPending>().having(
        (v) => v.operationId,
        'durable original operation',
        'original-operation',
      ),
    );
    expect(funding.calls, ['prepare']);
    await cubit.reconcile();
    expect(funding.calls, ['prepare', 'read']);
    expect(funding.arguments.last, (account(), 'original-operation'));
  });
  test(
    'uncertain sealed funding cannot regain a review through reconcile',
    () async {
      final funding = FakeArkBoardFunding()
        ..prepared = Ok(prepared())
        ..observed = Ok(prepared());
      final preferences = Preferences();
      final cubit = ArkBoardCubit(
        PrepareArkBoardUsecase(funding, preferences),
        ReadArkBoardUsecase(funding),
        ConfirmArkBoardUsecase(funding, preferences),
        config: config(),
      );
      addTearDown(cubit.close);
      await cubit.prepare(Sats.fromInt(1000));
      await cubit.confirm();
      funding.observed = const Err(
        ArkSubmissionUncertainFailure('original-operation'),
      );
      await cubit.reconcile();
      expect(
        cubit.state,
        isA<ArkBoardPending>()
            .having(
              (s) => s.operationId,
              'original journal',
              'original-operation',
            )
            .having(
              (s) => s.failure,
              'sealed read refused',
              isA<ArkSubmissionUncertainFailure>(),
            ),
      );
      await cubit.confirm();
      await cubit.prepare(Sats.fromInt(2000));
      expect(funding.calls, ['prepare', 'read', 'confirm', 'read']);
      expect(funding.arguments.last, (account(), 'original-operation'));
    },
  );

  test(
    'a feature-issued Board review cannot confirm for another account',
    () async {
      final funding = FakeArkBoardFunding()..observed = Ok(prepared());
      final facade = createArkFacade(
        client: FakeArkClient(),
        preferences: Preferences(),
        provisioning: Provisioner(),
        boardFunding: funding,
      );
      final review = await facade.reviewBoard(account(), 'original-operation');
      expect(review, isA<Ok<ArkBoardReview, ArkFailure>>());
      if (review case Ok(:final value)) {
        final other = ArkAccountId(
          parent: Fingerprint('aabbccdd'),
          network: account().network,
          serverIdentity: account().serverIdentity,
        );
        expect(
          await facade.confirmBoard(other, value),
          isA<Err<ArkOperation, ArkFailure>>().having(
            (r) => r.failure,
            'account mismatch before host admission',
            isA<ArkInvalidRequestFailure>(),
          ),
        );
      }
      expect(funding.calls, ['read']);
    },
  );

  test(
    'Board confirmation never substitutes another operation or operation kind',
    () async {
      final funding = FakeArkBoardFunding();
      final confirm = ConfirmArkBoardUsecase(funding, Preferences());
      for (final (id, kind) in [
        ('different-operation', ArkOperationKind.board),
        ('original-operation', ArkOperationKind.payment),
      ]) {
        funding.confirmed = Ok(
          ArkOperation(
            id: id,
            kind: kind,
            status: ArkOperationStatus.pending,
            chainSource: prepared().chainSource,
            configGeneration: 2,
          ),
        );
        expect(
          await confirm.execute(account(), prepared()),
          isA<Err<ArkOperation, ArkFailure>>().having(
            (r) => r.failure,
            'keep original admission uncertain',
            isA<ArkSubmissionUncertainFailure>().having(
              (f) => f.operationId,
              'original identity',
              'original-operation',
            ),
          ),
        );
      }
      expect(funding.calls, ['confirm', 'confirm']);
    },
  );
}
