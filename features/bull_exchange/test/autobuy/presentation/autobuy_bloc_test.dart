import 'dart:async';

import 'package:bull_exchange/src/autobuy/domain/autobuy_state.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_event.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_switch_state.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_switch_event.dart';
import 'package:bull_exchange/src/autobuy/presentation/autobuy_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../account/account_usecase_fakes.dart';
import '../autobuy_fixtures.dart';
import '../autobuy_usecase_fakes.dart';

import 'package:primitives/primitives.dart';

/// The AutoBuy use cases as fakes; every call is logged with the session
/// it got.
final class _Calls {
  final log = <String>[];
  final sessions = <ExchangeSession>{};
  bool activeAfterWrite = true;

  void _called(ExchangeSession session, String call) {
    sessions.add(session);
    log.add(call);
  }

  FakeSaveAutoBuyPreferenceUsecase get save =>
      FakeSaveAutoBuyPreferenceUsecase((session, effect) async {
        _called(session, 'write ${effect.target.enabled} ${effect.attempt}');
        return ConfirmAnswered(
          effect.attempt,
          const GateAdmitted(
            Err(ExchangeWriteOutcomeUnknownFailure('verify after write')),
          ),
        );
      });

  FakeGetUserSummaryUsecase get summary =>
      FakeGetUserSummaryUsecase((session) async {
        _called(session, 'summary');
        return Ok(autoBuySummary(active: activeAfterWrite));
      });

  AutoBuyFlowBloc flow({ExchangeSession? session = autoBuySession}) =>
      AutoBuyFlowBloc(
        session: session,
        accessChanges: const Stream.empty(),
        loadContext: FakeLoadAutoBuyContextUsecase((session) async {
          _called(session, 'load');
          return Ok(autoBuyContext());
        }),
        saveAutoBuy: save,
        getUserSummary: summary,
      );

  AutoBuySwitchBloc switchBloc({
    required ExchangeSession? session,
    required Future<void> Function() onAccountChanged,
  }) => AutoBuySwitchBloc(
    session: session,
    saveAutoBuy: save,
    getUserSummary: summary,
    active: true,
    restricted: false,
    onAccountChanged: onAccountChanged,
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('the flow activates once and verifies by re-reading', () async {
    final calls = _Calls();
    final bloc = calls.flow();
    addTearDown(bloc.close);
    await _settle();
    bloc
      ..add(const AutoBuyGetStartedPressed())
      ..add(const AutoBuyWalletsContinued(autoBuyWallets))
      ..add(const AutoBuyActivatePressed())
      ..add(const AutoBuyActivatePressed());
    await _settle();
    expect(calls.log, ['load', 'write true 1', 'summary']);
    expect(calls.sessions, {autoBuySession});
    expect(bloc.state, isA<AutoBuyDone>());
  });

  test('without a session the flow runs nothing', () async {
    final calls = _Calls();
    final bloc = calls.flow(session: null);
    addTearDown(bloc.close);
    await _settle();
    expect(calls.log, isEmpty);
  });

  test('the switch deactivates, verifies and refreshes the account', () async {
    final calls = _Calls()..activeAfterWrite = false;
    var refreshed = 0;
    final bloc = calls.switchBloc(
      session: autoBuySession,
      onAccountChanged: () async => refreshed++,
    );
    addTearDown(bloc.close);
    bloc.add(const SwitchDeactivatePressed());
    await _settle();
    expect(calls.log, ['write false 1', 'summary']);
    expect(calls.sessions, {autoBuySession});
    expect(bloc.state, const SwitchShown(active: false, restricted: false));
    expect(refreshed, 1);
  });

  test('without a session the switch writes nothing', () async {
    final calls = _Calls();
    final bloc = calls.switchBloc(session: null, onAccountChanged: () async {});
    addTearDown(bloc.close);
    bloc.add(const SwitchDeactivatePressed());
    await _settle();
    expect(bloc.state, const SwitchShown(active: true, restricted: false));
    expect(calls.log, isEmpty);
  });
}
