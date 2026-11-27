import 'dart:async';

import 'package:bull_exchange/src/funding/domain/fund_flow.dart';
import 'package:bull_exchange/src/funding/presentation/fund_flow_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:flutter_test/flutter_test.dart';

import '../funding_usecase_fakes.dart';

import 'package:primitives/primitives.dart';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 0,
  sessionId: 'a',
);

const _rows = FundingInstructionRows([
  InstructionRow(InstructionField.beneficiaryName, 'Bull Bitcoin'),
]);

/// The funding use cases as fakes; the consent and institution calls are
/// not expected (the account already consented, no COP rail is picked).
final class _Calls {
  final requests = <FundingRequest>[];
  final sessions = <ExchangeSession>[];

  FundFlowBloc bloc({
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
  }) => FundFlowBloc(
    session: session,
    accessChanges: accessChanges,
    getAccount: FakeGetFundingAccountUsecase((session) async {
      sessions.add(session);
      return Ok(
        FundingAccount(
          userNumber: 7,
          firstName: 'Ada',
          lastName: 'Lovelace',
          currency: ExchangeCatalog.parse('CAD'),
          restricted: false,
          consented: true,
          confidentialSepa: ConfidentialSepaAvailability.unavailable,
        ),
      );
    }),
    saveConsent: FakeSaveFundingConsentUsecase(
      (_) => throw StateError('consent is already on the account'),
    ),
    getConsent: FakeGetFundingConsentUsecase(
      (_) => throw StateError('unexpected consent re-read'),
    ),
    getInstitutions: FakeGetCopFundingInstitutionsUsecase(
      (_) => throw StateError('unexpected institutions'),
    ),
    getInstructions: FakeGetFundingInstructionsUsecase((
      session,
      request,
    ) async {
      sessions.add(session);
      requests.add(request);
      return const Ok(FundingInstructionsGot(_rows));
    }),
  );
}

void main() {
  test('runs each state effect with the flow session', () async {
    final funding = _Calls();
    final access = StreamController<ExchangeAccess>.broadcast();
    final bloc = funding.bloc(session: _session, accessChanges: access.stream);
    addTearDown(() async {
      await bloc.close();
      await access.close();
    });

    await expectLater(bloc.stream, emits(isA<FundPicking>()));
    bloc.add(const FundRailPicked(EmailETransferFundingRail()));
    await expectLater(
      bloc.stream,
      emitsInOrder([isA<FundFetching>(), isA<FundShowing>()]),
    );
    expect(funding.sessions, [_session, _session]);
    expect(funding.requests.single.rail, const EmailETransferFundingRail());
  });

  test('another session ends the flow', () async {
    final access = StreamController<ExchangeAccess>.broadcast();
    final bloc = _Calls().bloc(session: _session, accessChanges: access.stream);
    addTearDown(() async {
      await bloc.close();
      await access.close();
    });
    await expectLater(bloc.stream, emits(isA<FundPicking>()));

    access.add(
      const ExchangeAccessSignedIn(
        ExchangeSession(
          environment: ExchangeEnvironment.testnet,
          epoch: 1,
          sessionId: 'b',
        ),
      ),
    );

    await expectLater(bloc.stream, emits(const FundSessionEnded()));
  });

  test('without a session nothing is read', () async {
    final calls = _Calls();
    final bloc = calls.bloc(session: null, accessChanges: const Stream.empty());
    addTearDown(bloc.close);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, const FundSessionEnded());
    expect(calls.sessions, isEmpty);
  });
}
