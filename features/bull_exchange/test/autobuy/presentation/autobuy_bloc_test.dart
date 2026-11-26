import 'dart:async';

import 'package:bull_exchange/src/autobuy/presentation/autobuy_bloc.dart';
import 'package:bull_exchange/src/autobuy/presentation/autobuy_flow.dart';
import 'package:bull_exchange/src/autobuy/presentation/autobuy_switch.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../autobuy_fixtures.dart';

final class _Calls {
  final log = <String>[];
  bool activeAfterWrite = true;

  AutoBuyCalls of(ExchangeSession session) => (
    loadContext: () async {
      log.add('load');
      return ReadGot(autoBuyContext());
    },
    write: (effect) async {
      log.add('write ${effect.target.enabled} ${effect.attempt}');
      return ConfirmAnswered(
        effect.attempt,
        const GateAdmitted(WriteOutcomeUnknown('verify after write')),
      );
    },
    verify: (target) async {
      log.add('verify ${target.enabled}');
      return autoBuyCheck(
        target,
        ReadGot(autoBuySummary(active: activeAfterWrite)),
      );
    },
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
    final bloc = AutoBuyFlowBloc(
      calls: calls.of,
      session: autoBuySession,
      accessChanges: const Stream.empty(),
    );
    addTearDown(bloc.close);
    await _settle();
    bloc
      ..add(const AutoBuyGetStartedPressed())
      ..add(const AutoBuyWalletsContinued(autoBuyWallets))
      ..add(const AutoBuyActivatePressed())
      ..add(const AutoBuyActivatePressed());
    await _settle();
    expect(calls.log, ['load', 'write true 1', 'verify true']);
    expect(bloc.state, isA<AutoBuyDone>());
  });

  test('the switch deactivates, verifies and refreshes the account', () async {
    final calls = _Calls()..activeAfterWrite = false;
    var refreshed = 0;
    final bloc = AutoBuySwitchBloc(
      calls: calls.of(autoBuySession),
      active: true,
      restricted: false,
      onAccountChanged: () async => refreshed++,
    );
    addTearDown(bloc.close);
    bloc.add(const SwitchDeactivatePressed());
    await _settle();
    expect(calls.log, ['write false 1', 'verify false']);
    expect(bloc.state, const SwitchShown(active: false, restricted: false));
    expect(refreshed, 1);
  });

  test('without a session the switch writes nothing', () async {
    final bloc = AutoBuySwitchBloc(
      calls: null,
      active: true,
      restricted: false,
      onAccountChanged: () async {},
    );
    addTearDown(bloc.close);
    bloc.add(const SwitchDeactivatePressed());
    await _settle();
    expect(bloc.state, const SwitchShown(active: true, restricted: false));
  });
}
