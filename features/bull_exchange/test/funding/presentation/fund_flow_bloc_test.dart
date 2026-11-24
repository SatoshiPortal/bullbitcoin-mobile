import 'dart:async';

import 'package:bull_exchange/src/funding/presentation/fund_flow.dart';
import 'package:bull_exchange/src/funding/presentation/fund_flow_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 0,
  sessionId: 'a',
);

const _rows = FundingInstructionRows([
  InstructionRow(InstructionField.beneficiaryName, 'Bull Bitcoin'),
]);

class _Funding implements ExchangeFunding {
  final requests = <FundingRequest>[];
  final List<ExchangeSession> sessions = [];

  @override
  Future<ExchangeRead<FundingAccount>> account(ExchangeSession session) async {
    sessions.add(session);
    return ReadGot(
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
  }

  @override
  Future<ExchangeRead<FundingAnswer>> instructions(
    ExchangeSession session,
    FundingRequest request,
  ) async {
    sessions.add(session);
    requests.add(request);
    return const ReadGot(FundingInstructionsGot(_rows));
  }

  @override
  Future<ExchangeRead<List<FundingInstitution>>> institutions(
    ExchangeSession session,
    Jurisdiction jurisdiction,
  ) => throw StateError('unexpected institutions');

  @override
  Future<ExchangeWrite<void>> consent(ExchangeSession session) =>
      throw StateError('consent is already on the account');

  @override
  Future<ExchangeRead<bool>> consentOnAccount(ExchangeSession session) =>
      throw StateError('unexpected consent re-read');
}

void main() {
  test('runs each state effect with the flow session', () async {
    final funding = _Funding();
    final access = StreamController<ExchangeAccess>.broadcast();
    final bloc = FundFlowBloc(
      funding: funding,
      session: _session,
      accessChanges: access.stream,
    );
    addTearDown(() async {
      await bloc.close();
      await access.close();
    });

    await expectLater(bloc.stream, emits(isA<FundPicking>()));
    bloc.add(const FundRailPicked(EmailETransferRail()));
    await expectLater(
      bloc.stream,
      emitsInOrder([isA<FundFetching>(), isA<FundShowing>()]),
    );
    expect(funding.sessions, everyElement(_session));
    expect(funding.requests.single.rail, const EmailETransferRail());
  });

  test('another session ends the flow', () async {
    final access = StreamController<ExchangeAccess>.broadcast();
    final bloc = FundFlowBloc(
      funding: _Funding(),
      session: _session,
      accessChanges: access.stream,
    );
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
    final bloc = FundFlowBloc(
      funding: _Funding(),
      session: null,
      accessChanges: const Stream.empty(),
    );
    addTearDown(bloc.close);
    expect(bloc.state, const FundSessionEnded());
  });
}
